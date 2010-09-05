#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et:vim
# popuplist.py - a generic listing facility with popup listboxes
#
# Author: Marko Mahnič
# Created: April 2009
# License: GPL (http://www.gnu.org/copyleft/gpl.html)
# This program comes with ABSOLUTELY NO WARRANTY.

import re, time
import threading
import vim
import simplekeymap
import ioutil
import boxposition
import textfilter

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
    __slots__ = ('isTitle', '_text', 'quickchar', 'marked') # Reduce memory use
    def __init__(self, text=""):
        self.isTitle = False     # True if this item is a title
        self._text = text
        self.quickchar = None
        self.marked = 0

    @property
    def displayText(self):
        return self._text

    @property
    def filterText(self):
        return self._text

    @property
    def callbackText(self):
        return self._text

# TODO: add incremental search: works like filter, but lines are not hidden;
#       TAB moves to next occurence; needed eg. with VxMan;
# TODO: add default search mode for /: i-search or filter
# TODO: implement multiline list items (eg. up to 3 lines)
class CList(object):
    MODE_NORMAL = 1
    MODE_FILTER = 2
    MODE_QUICK = 3
    MODE_NUMSELECT = 4
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
        self._filter = textfilter.CWordFilter()
        self.__items = None     # Displayed (filtered) items; delayed creation in items()
        self.__listbox = None   # Listbox implementation
        self._pendingItemsLock = threading.Lock() # items added incrementally
        self._pendingItems = None
        self.sort = True        # sort input list
        self.filtersort = True  # sort filtered data (quickchar, startswith, contains)
        self.keymapNorm = simplekeymap.CSimpleKeymap("Normal")
        self.keymapFilter = simplekeymap.CSimpleKeymap("Filter")
        self.keymapQuickChar = simplekeymap.CSimpleKeymap("Quick-char selection")
        self.keymapNumSelect = simplekeymap.CSimpleKeymap("Numeric selection")
        self.quickCharAutoSelect = "accept" # An item with a unique quick char will be auto-"accept"-ed; TODO: make it nicer
        self.cmdCancel = "" # 'echo "canceled"'
        self.cmdAccept = "" # 'echo "accepted {{i}}"'
        self.prompt = None # TODO: document special format; see _popuplist_screen..._buildPrompt
        self.hasTitles = False # if true, items marked as titles will be treated specially when filtering
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
            kn.setKey(r"\<F1>", "listbox-help")
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
        kn.setKey(r"\<space>", "nextpage")
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
        #kn.setKey(r"wk", "winpos:align-top")
        #kn.setKey(r"wj", "winpos:align-bottom")
        #kn.setKey(r"wh", "winpos:align-left")
        #kn.setKey(r"wl", "winpos:align-right")
        #kn.setKey(r"wc", "winpos:align-hceneter")
        #kn.setKey(r"wv", "winpos:align-vceneter")
        #kn.setKey(r"wC", "winpos:align-ceneter")
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

    def doHelp(self):
        from showhelp import CHelpDisplay
        hd = CHelpDisplay()
        hd.setKeymaps([self.keymapNorm, self.keymapFilter, self.keymapQuickChar, self.keymapNumSelect])
        hd.process()
        # vim.command("redraw!")
        self.redraw()

    # TODO: 3. python: eval a python command
    def doCommand(self, cmd, curindex):
        if cmd == "listbox-help":
            self.doHelp()
        elif cmd.startswith("list:"):
            cmd = self.doListCommand(cmd[5:].strip(), curindex)
        elif cmd.startswith("winpos:"):
            self.doWinposCmd(cmd[7:].strip())
            cmd = ""
        elif cmd.startswith("vim:"):
            cmd = self.doVimCallback(cmd[4:].strip(), curindex)
            if cmd != "quit":
                vim.command("redraw!")
                self.redraw()
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
        except vim.error:
            vim.command("echom 'doVimCallback: vim.error caught'")
        return ""

    def redraw(self):
        if self.__listbox != None: self.__listbox.redraw()

    def restartFilter(self, full=False):
        if full: self.__previtems = None
        else: self.__previtems = self.__items
        self.__items = None

    def refreshDisplay(self):
        self.restartFilter()
        self._firstColumnWidth = None
        if self.__listbox != None: self.__listbox.refreshDisplay()

    def onFilterChanged(self, old, new):
        pass

    def setFilter(self, strFilter = ""):
        if strFilter == self.strFilter: return
        old = self.strFilter
        self.strFilter = strFilter
        self._filter.setFilter(self.strFilter)
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

    def __applyFilter(self):
        if self._filter.isEmpty():
            self.__previtems = None
            self.__items = [i for i in self.allitems]
            return

        # incremental filtering
        allitems = self.allitems
        if self._filter.filterGrown and self.__previtems != None:
            allitems = self.__previtems
        self.__previtems = None

        startat = 0
        inhead=[]; intail=[]
        for i in allitems:
            if self.hasTitles and i.isTitle:
                intail.append(i)
                continue
            good, bestpos = self._filter.match(i.filterText, startat)
            if good < 1: continue
            elif self.hasTitles: intail.append(i)
            elif bestpos == startat and self.filtersort: inhead.append(i)
            else: intail.append(i)
        self.__items = inhead + intail

        if self.hasTitles:
            ttlempty = []
            prev = None
            for k,i in enumerate(self.__items):
                if prev != None and prev.isTitle and i.isTitle: ttlempty.append(k-1)
                prev = i
            if len(self.__items) > 0 and self.__items[-1].isTitle:
                self.__items.pop(-1)
            ttlempty.reverse()
            for k in ttlempty: self.__items.pop(k)
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
        self.allitems = [
            CListItem(line.decode(encoding, "replace") if line != None else "")
            for line in vim.eval(vimvar)]
        self.refreshDisplay()

    def loadUnicodeItems(self, pylist):
        self.allitems = [CListItem(line) for line in pylist]
        self.refreshDisplay()

    def loadTestItems(self):
        self.allitems = [CListItem(i) for i in [u"one"*14, u"two"*13, u"three"*12, u"four"*11] * 10]
        self.refreshDisplay()

    def setTitleItems(self, reSearch, noinvert=1):
        rx = re.compile(reSearch)
        for i in self.allitems:
            if (rx.search(i._text) != None) == (noinvert != 0): # TODO: shouldn't use _text
                i.isTitle = True ## XXX item modified

    def getTrueIndex(self, filteredIndex):
        if self.__items != None: nitems = len(self.__items)
        else: nitems = 0
        if filteredIndex < 0 or filteredIndex >= nitems: i = -1
        else: i = self.allitems.index(self.__items[filteredIndex])
        return i

    # @param extraParamHandlers can be used to define additional parameters to be expanded.
    #        A dictionary of pairs "{{param}}": handler, where handler is a function defined
    #        as: handler(theList, allItems, curItem) that returns a string (a vim function
    #        parameter or a list of vim function parameters)
    #        Example: @see dired CFileBrowser.expandVimCommand, CFileBrowser._diredSelect
    def expandVimCommand(self, command, curindex, extraParamHandlers={}):
        icur = self.getTrueIndex(curindex)
        rxp = re.compile(r"(\{\{[a-zA-Z0-9]+\}\})")
        parts = rxp.split(command)
        if len(parts) == 1: return command
        newcmd = [parts[0]]
        for p in parts[1:]:
            if not p.startswith("{{"):
                newcmd.append(p)
                continue
            if p == "{{i}}": p = "%d" % (icur)
            elif p == "{{M}}":
                marks = ",".join(["%d" % (i) for i,item in enumerate(self.allitems) if item.marked])
                p = "[" + marks + "]"
            elif p == "{{s}}": p = "'%s'" % self.allitems[icur].callbackText # TODO: escape string!
            elif p == "{{S}}":
                marks = ",".join(
                    ["'%s'" % item.callbackText # TODO: escape string!
                    for item in self.allitems if item.marked])
                p = "[" + marks + "]"
            else:
                for k,fnHandler in extraParamHandlers.iteritems():
                    if k == p:
                        p = fnHandler(self, self.allitems, self.allitems[icur])
                        break
            newcmd.append(p)
        return "".join(newcmd)

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
        # len of longest item + border + 1space
        return max([len(li.displayText) for li in self.allitems]) + 2 + 1

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

    def hasBackgroundTasks(self):
        return False

    # Check if any items were added to the list while the list is being displayed.
    # This function enables adding items to the list incrementally.
    def checkPendingItems(self):
        if self._pendingItems == None: return False
        if len(self._pendingItems) < 1: return False
        merged = False
        try:
            self._pendingItemsLock.acquire()
            if self._pendingItems != None: # re-check
                merged = True
                newitems = self._pendingItems
                self._pendingItems = None
                self.allitems = self.mergeItems(self.allitems, newitems)
                self.restartFilter(full=True) # reapply filter
                self.relayout()
        finally:
            self._pendingItemsLock.release()
        return merged

    # To be overridden if necessary
    def mergeItems(self, current, newlist):
        current += newlist
        return current

    def onExit(self):
        pass

    def process(self, curindex = 0, startmode = MODE_NORMAL): # TODO: startmode=sth.NORMAL
        lbimpl = importListboxImpl()
        if lbimpl == None: return
        self.relayout()
	self.__listbox = lbimpl.createListboxView(position=self.position, size=self.size)
	self.__listbox.setItemList(self)
        try:
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
        finally:
            self.onExit()

