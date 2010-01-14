#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et:vim
# popuplist.py - a generic listing facility with popup listboxes
#
# Author: Marko Mahnič
# Created: April 2009
# License: GPL (http://www.gnu.org/copyleft/gpl.html)
# This program comes with ABSOLUTELY NO WARRANTY.

import time
import vim
import simplekeymap
import ioutil
import boxposition

# TODO: vimuiex init script when the list is used for the first time: copy vars from vim to python
# import the correct listbox implementation
__listbox = None
def importListboxImpl():
    global __listbox
    if __listbox != None: return __listbox
    if ioutil.PLATFORM == "vim.screen":
        import vimuiex._popuplist_screen as __listbox
        boxposition.setBorder(2, 2)
    elif ioutil.PLATFORM == "curses":
        import vimuiex._popuplist_screen as __listbox
        boxposition.setBorder(12, 4) # Drawing errors in curses when w > &columns-12
    elif ioutil.PLATFORM == "wx":
        import vimuiex._popuplist_wx as __listbox
        boxposition.setBorder(2, 2)
    else:
        raise SystemError("VimUiEx: Invalid platform")

    return __listbox

def log(msg):
    f = open ("testlog.txt", "a")
    f.write(msg + "\n")
    f.close()

def vimScreenSize():
    return (int(vim.eval("&columns")), int(vim.eval("&lines")))

class CListItem(object):
    def __init__(self, text=""):
        self.flags = 0
        self._text = text
        self.quickchar = None
        self.marked = 0

    @property
    def displayText(self):
        return self._text

    @property
    def filterText(self):
        return self._text

# TODO: add incremental search: works like filter, but lines are not hidden;
#       TAB moves to next occurence; needed eg. with VxMan;
# TODO: add default search mode for /: i-search or filter
# TODO: implement multiline list items (eg. up to 3 lines)
class CList(object):
    def __init__(self, title="", optid=""):
        """
        position: (x, y); if None, center the listbox
        align:    alignment string (eg. "TL", "BR", "T", ...); overrides position
        size:     (width, height); if None, half of screen size in each direction
        autosize: autosize string (eg. "V", "H", "C", "VH")
                  V - autosize vertically
                  H - autosize horizontally
                  C - autosize 1st column (tab delimited)
        """
        if title != None: self.title = title
        else: self.title = ""
        self.titleAlign = "<"
        self.position = None
        self.size = None
        self.posManager = boxposition.CBoxPositioner(self)
        if optid == None: optid = ""
        options = vim.eval("vimuiex#vxlist#GetPosOptions('%s')" % optid)
        self.posManager.parseOptions(options)
        self._firstColumnAlign = False
        self._firstColumnWidth = None # property: Width of the first column
        self._resizeOnFilter = False
        self._moveDownOnMark = True
        self.maxColumnWidth = 0.3
        self.allitems = []
        self.strFilter = "" 
        self.filterWordSeparator = ","
        self.__items = None     # Displayed (filtered) items; delayed creation in items()
        self.__listbox = None   # Listbox implementation
        self.sort = True        # sort input list
        self.filtersort = True  # sort filterd data (quickchar, startswith, contains)
        self.keymapNorm = simplekeymap.CSimpleKeymap()
        self.keymapFilter = simplekeymap.CSimpleKeymap()
        self.keymapQuickChar = simplekeymap.CSimpleKeymap()
        self.keymapNumSelect = simplekeymap.CSimpleKeymap()
        self.quickCharAutoSelect = "accept" # An item with a unique quick char will be auto-"accept"-ed; TODO: make it nicer
        self.cmdCancel = "" # 'echo "canceled"'
        self.cmdAccept = "" # 'echo "accepted {{i}}"'
        self.initKeymaps()

    def getTitle(self, maxwidth):
        if len(self.title) < maxwidth: return self.title
        if maxwidth > 12:
            maxwidth -= 3
            dots = "..."
        else: dots = ""
        if self.titleAlign == ">": return dots + self.title[-maxwidth:]
        return self.title[:maxwidth] + dots

    def getExtraPrompt(self, maxwidth=40):
        return ""

    def initKeymaps(self):
        def addCursorMoves(kn):
            kn.setKey(r"\<down>", "next")
            kn.setKey(r"\<up>", "prev")
            kn.setKey(r"\<left>", "lshift")
            kn.setKey(r"\<right>", "rshift")
            kn.setKey(r"\<pagedown>", "nextpage")
            kn.setKey(r"\<pageup>", "prevpage")
            kn.setKey(r"\<home>", "home")
            kn.setKey(r"\<end>", "end")
            # TODO: Experimental
            kn.setKey(r"\<TAB>", "next")
            kn.setKey(r"\<S-TAB>", "prev")
        kn = self.keymapNorm
        addCursorMoves(kn)
        kn.setKey(r"j", "next")
        kn.setKey(r"k", "prev")
        kn.setKey(r"h", "lshift")
        kn.setKey(r"l", "rshift")
        kn.setKey(r" ", "nextpage")
        kn.setKey(r"b", "prevpage")
        kn.setKey(r"n", "nextpage") # MAYBE: remove mapping
        kn.setKey(r"p", "prevpage") # MAYBE: remove mapping
        kn.setKey(r"0", "home") # MAYBE: set offset to 0
        kn.setKey(r"gg", "home")
        kn.setKey(r"$", "end") # MAYBE: set offset to view the end of the longest line
        kn.setKey(r"G", "end")
        kn.setKey(r"f", "filter")
        kn.setKey(r"/", "filter")
        kn.setKey(r"&", "quickchar")
        kn.setKey(r"i", "numselect")
        kn.setKey(r"#", "numselect")
        kn.setKey(r"q", "quit")
        kn.setKey(r"m", "togglemarked")
        kn.setKey(r"\<Esc>", "quit")
        kn.setKey(r"\<CR>", "accept")
        kn.setKey(r"wk", "winpos:align-top")
        kn.setKey(r"wj", "winpos:align-bottom")
        kn.setKey(r"wh", "winpos:align-left")
        kn.setKey(r"wl", "winpos:align-right")
        kn.setKey(r"wc", "winpos:align-hceneter")
        kn.setKey(r"wv", "winpos:align-vceneter")
        kn.setKey(r"wC", "winpos:align-ceneter")
        kn = self.keymapFilter
        addCursorMoves(kn)
        kn.setKey(r"\<CR>", "filter-accept")
        kn.setKey(r"\<ESC>", "filter-cancel")
        kn.setKey(r"\<BS>", "filter-delete")
        kn.setKey(r"\<TAB>", "filter-next")
        kn.setKey(r"\<S-TAB>", "filter-prev")
        kn = self.keymapQuickChar
        addCursorMoves(kn)
        kn.setKey(r"\<CR>", "accept")
        kn.setKey(r"\<ESC>", "quit")
        kn.setKey(r"&", "exit-quickchar")
        kn.setKey(r"/", "filter")
        kn.setKey(r"#", "numselect")
        kn = self.keymapNumSelect
        kn.setKey(r"\<CR>", "accept")
        kn.setKey(r"\<ESC>", "quit")
        kn.setKey(r"\<BS>", "numselect-delete")
        kn.setKey(r"q", "quit")
        kn.setKey(r"&", "quickchar")
        kn.setKey(r"/", "filter")

    # TODO: 3. python: eval a python command
    def doCommand(self, cmd, curindex):
        if cmd.startswith("list:"):
            cmd = self.doListCommand(cmd[5:].strip(), curindex)
        elif cmd.startswith("winpos:"):
            self.doWinposCmd(cmd[7:].strip())
            cmd = ""
        elif cmd.startswith("vim:"):
            cmd = self.doVimCallback(cmd[4:].strip(), curindex)
            vim.command("redraw!")
            self.redraw()
            # cmd = ""
        return cmd

    def doWinposCmd(self, cmd):
        if cmd == "align-left": flag = "l"
        elif cmd == "align-right": flag = "r"
        elif cmd == "align-top": flag = "t"
        elif cmd == "align-bottom": flag = "b"
        elif cmd == "align-hceneter": flag = "h"
        elif cmd == "align-vceneter": flag = "v"
        elif cmd == "align-ceneter": flag = "c"
        else: return
        self.reposition(flag)

    def doListCommand(self, cmd, curindex):
        return cmd

    def doVimCallback(self, cmd, curindex):
        try:
            cmd = self.expandVimCommand(cmd, curindex)
            rv = vim.eval(cmd)
            if rv == "q": return "quit"
        except: pass
        return ""

    def redraw(self):
        if self.__listbox != None: self.__listbox.redraw()

    def refreshDisplay(self):
        self.__items = None
        self._firstColumnWidth = None
        if self.__listbox != None: self.__listbox.refreshDisplay()

    def onFilterChanged(self, old, new):
        pass

    def setFilter(self, strFilter = ""):
        if strFilter == self.strFilter: return
        old = self.strFilter
        self.strFilter = strFilter
        self.onFilterChanged(old, strFilter)
        if self._resizeOnFilter: self.relayout(size=True)
        self.refreshDisplay()

    def setCurIndex(self, index):
        if self.__listbox == None: return
        self.__listbox.setCurIndex(index)
        pass

    @property
    def items(self):
        if self.__items == None: self.__applyFilter()
        return self.__items

    @property
    def itemCount(self):
        if self.__items == None: self.__applyFilter()
        return len(self.__items)

    # returns a list of tuples: (word, negated?)
    def getFilterWords(self):
        if self.filterWordSeparator == "": sep = " "
        else: sep = self.filterWordSeparator
        filt = self.strFilter.lower().split(sep)
        filt = [ f.strip() for f in filt if f.strip() != "" ]
        filt = [ (f.lstrip("-"), f.startswith("-")) for f in filt if f.lstrip("-") != ""]
        return filt

    # @param words a list of tuples: (word, negated?)
    # @returns a tuple (trueIfAllMatched, positiveMatchPosition)
    def matchFilterWords(self, text, words, startat=0):
        good = True; bestpos = -1
        for f in words:
            pos = text.find(f[0], startat)
            if (pos >= 0 and f[1]) or (pos < 0 and not f[1]):
                good = False
                break
            if bestpos < 0 and not f[1] and pos >= 0: bestpos = pos
        return (good, bestpos)

    def __applyFilter(self):
        addAll = False
        if self.strFilter == None or self.strFilter == "":
            addAll = True
        else:
            filt = self.getFilterWords()
            if len(filt) < 1: addAll = True

        if addAll: self.__items = [i for i in self.allitems]
        else:
            startat = 0
            inhead=[]; intail=[]
            for i in self.allitems:
                text = i.filterText.lower()
                good, bestpos = self.matchFilterWords(text, filt, startat)
                if not good: continue
                elif bestpos == startat and self.filtersort: inhead.append(i)
                else: intail.append(i)
            self.__items = inhead + intail
        pass

    def loadBufferItems(self, bufnum, minline = 0, maxline = -1):
        buf = vim.buffers[bufnum-1]
        a, b = 0, len(buf)
        # TODO: minline, maxline
        # TODO: fileencoding/encoding for buf
        self.allitems = [CListItem(line) for line in buf[a:b]]
        self.refreshDisplay()

    def loadVimItems(self, vimvar):
        encoding = vim.eval("&encoding")
        self.allitems = [CListItem(line.decode(encoding)) for line in vim.eval(vimvar)]
        self.refreshDisplay()

    def loadUnicodeItems(self, pylist):
        # TODO: convert to unicode
        self.allitems = [CListItem(line) for line in pylist]
        self.refreshDisplay()
    
    def loadTestItems(self):
        self.allitems = [CListItem(i) for i in [u"one"*14, u"two"*13, u"three"*12, u"four"*11] * 10]
        self.refreshDisplay()

    def getTrueIndex(self, filteredIndex):
        if self.__items != None: nitems = len(self.__items)
        else: nitems = 0
        if filteredIndex < 0 or filteredIndex >= nitems: i = -1
        else: i = self.allitems.index(self.__items[filteredIndex])
        return i

    def expandVimCommand(self, command, curindex):
        i = self.getTrueIndex(curindex)
        cmd = command.replace("{{i}}", "%d" % (i))
        if command.find("{{M}}") > 0:
            marks = ",".join(["%d" % (i) for i,item in enumerate(self.allitems) if item.marked])
            cmd = cmd.replace("{{M}}", "[" + marks + "]")
        return cmd
    
    def calcFirstColumnWidth(self, textwidth, items):
        mwf = self.maxColumnWidth
        if mwf < 0.2: mwf = 0.2
        if mwf > 0.8: mwf = 0.8
        wmax = int(textwidth * mwf)
        wopt = 0
        for i in items:
            if i.displayText.find("\t") < 0: continue
            cols = i.displayText.split("\t", 1)
            w = len(cols[0].rstrip())
            if w > wopt: wopt = w
            if wopt > wmax: wopt = wmax; break
        return wopt

    def getFirstColumnWidth(self, textwidth=None):
        if not self._firstColumnAlign: return None
        if self._firstColumnWidth != None: return self._firstColumnWidth
        if textwidth == None or textwidth < 1:
            if self.posManager.autosize.x: textwidth = self.posManager.maxSize.x - 2
            else: textwidth = self.size.x - 2
        wopt = self.calcFirstColumnWidth(textwidth, self.items)
        if wopt > 0: self._firstColumnWidth = wopt
        return self._firstColumnWidth

    # TODO: optimize size calculation (cache results)
    def getMaxWidth(self):
        if len(self.allitems) < 1: return 0
        return max([len(li.displayText) for li in self.allitems]) + 2

    def getMaxHeight(self):
        return len(self.allitems) + 2

    def relayout(self, position=True, size=True):
        if position and size: self.posManager.relayout()
        elif position: self.posManager.reposition()
        elif size: self.posManager.relayout() # repositioning is required after resize
        if self.__listbox != None:
            self.__listbox.relayout(self.position, self.size)

    def reposition(self, pointDef):
        self.posManager.reposition(pointDef)
        if self.__listbox != None:
            self.__listbox.relayout(self.position, self.size)

    def process(self, curindex = 0, startmode = 1): # TODO: startmode=sth.NORMAL
        lbimpl = importListboxImpl()
        if lbimpl == None: return
        self.relayout()
	self.__listbox = lbimpl.createListboxView(position=self.position, size=self.size)
	self.__listbox.setItemList(self)
	exitcmd = self.__listbox.process(curindex, startmode)
        # WX: will exit immediately; non-modal window
        # Curses: will exit after processing and return the exit command (modal window)
        if exitcmd != None:
            cmd = None
            if exitcmd[0] == "accept": cmd = self.cmdAccept
            elif exitcmd[0] == "quit": cmd = self.cmdCancel
            if cmd != None:
                import inspect
                idx = exitcmd[1]
                if inspect.isfunction(cmd): cmd(self.getTrueIndex(idx))
                elif type(cmd) == type("") and cmd != "":
                    cmd = self.expandVimCommand(cmd, idx)
                    vim.eval(cmd)

