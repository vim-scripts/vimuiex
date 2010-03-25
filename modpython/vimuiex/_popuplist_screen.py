# vim: set fileencoding=utf-8 sw=4 ts=8 et:vim
# _popuplist_screen.py - a popup listbox implementation with vim internal screen routines
# NOTE: requires a vim source patch to export a vim.screen object to python.
#
# Author: Marko Mahnič
# Created: May 2009
# License: GPL (http://www.gnu.org/copyleft/gpl.html)
# This program comes with ABSOLUTELY NO WARRANTY.
#
# (loaded by popuplist.py)

import time
import vim
import simplekeymap
import ioutil
from popuplist import CList

def log(msg):
    f = open ("testlog.txt", "a")
    f.write(msg + "\n")
    f.close()

# Factory
def createListboxView(position, size):
    if ioutil.PLATFORM == "vim.screen":
        return CPopupListboxScreen(position, size)
    if ioutil.PLATFORM == "curses":
        return CPopupListboxCurses(position, size)
    return None

class CNumSelect(object):
    # TODO: use arbitrary characters; multiple character groups (first press, second press)
    # TODO: char 2 digit mapping is customizable (vim setting)
    # TODO: use this code in vxjump
    def __init__(self):
        self.curNumber = ""
        self.maxnumber = 9
        self.width = 1
        self.format = "%1d"

    def setMaxNumber(self, maxnumber):
        self.maxnumber = maxnumber
        if maxnumber > 99: self.width = 3
        elif maxnumber > 9: self.width = 2
        else: maxnumber = 1
        self.format = "%%0%dd" % self.width

    def getCurIndex(self):
        if self.curNumber == "": return -1
        cn = self.curNumber
        while len(cn) < self.width: cn = cn + "0"
        i = int(cn)
        if i > self.maxnumber: i = -1
        return i

    def isComplete(self):
        return len(self.curNumber) >= self.width

    def trySelectItem(self, ch, topitem, lastitem):
        # TODO: setMaxNumber should be set here. Possible conflicts with filter/navigation?
        oldn = self.curNumber
        if ch in "0123456789": self.curNumber += ch
        else:
            pos = "mjkluio".find(ch) # TODO: user setting
            if pos >= 0: self.curNumber += "%c" % (pos+48)
            else: return -1
        offs = self.getCurIndex()
        i = offs + topitem
        if offs < 0 or i < 0 or i > lastitem:
            self.curNumber = oldn
            return -1
        return i

class CPopupListbox(object):
    EXIT = 0
    NORMAL = 1
    FILTER = 2
    QUICK = 3
    NUMSELECT = 4
    def __init__(self, position, size): # TODO: CWinArranger
        self.itemlist = None # CList
        self.left = position.x
        self.top = position.y
        self.width = size.x
        self.height = size.y
        self.window = None
        self.wcontent = None
        self.textwidth = self.width - 2
        self.lastline = self.height - 3
        self.topindex = 0
        self.hoffset = 0
        self.curindex = 0
        self.exitcommand = ""
        self.keyboardMode = CList.MODE_NORMAL
        self.quickChar = None # Currently active quick char
        self.numselect = CNumSelect()
        self.numselect.setMaxNumber(self.lastline)
        self.yPrompt = int(vim.eval("&lines")) - 1
        self.lastclick = (-1, -1) # last mouse click
        self.initPlatform()

    def initPlatform(self):
        pass

    @property
    def itemCount(self):
        if self.itemlist == None or self.itemlist.items == None: return 0
        return len(self.itemlist.items)

    def setItemList(self, clist):
        self.itemlist = clist
        self.itemlist._firstColumnWidth = None # TODO: does it belong here or in popuplist.py?

    def refreshDisplay(self):
        self.refresh()

    def initWindow(self):
        self.textwidth = self.width - 2
        self.lastline = self.height - 3
        self.numselect.setMaxNumber(self.lastline)
        self.topindex = 0
        self.hoffset = 0
        self.window = ioutil.CWindow(self.height, self.width, self.top, self.left)
        self.wcontent = self.window.derwin(self.height-2, self.width-2, 1, 1)

    def show(self, curindex=None):
        if self.window == None: self.initWindow()

        co = self.coNormal
        self.window.attrset(co)
        self.window.border()
        # curses: without a refresh before drawItems, the first line is initially displayed wrong
        self.window.refresh()

        if curindex == None: curindex = self.curindex
        self.setCurIndex(curindex, redraw = False)

        self.wcontent.attrset(co)
        self.wcontent.bkgd(" ", co)
        self.drawTitle()
        self.drawItems()
        self.drawLastLine()
        self.window.redrawwin()

    def refresh(self):
        if self.wcontent != None: self.wcontent.refresh()
        if self.window != None: self.window.refresh()

    def hide(self):
        if self.wcontent != None:
            w = self.wcontent
            self.wcontent = None
            w.clear()
            w.refresh()
            del w
        if self.window != None:
            w = self.window
            self.window = None
            w.clear()
            w.refresh()
            del w
        ioutil.CScreen().refresh()
        vim.command("redraw!")

    def redraw(self):
        self.show()

    def getLineStr(self, text, lineno):
        if text.find("\t") >= 0:
            cw = self.itemlist.getFirstColumnWidth()
            if cw != None:
                pos = text.find("\t")
                if pos >= 0 and pos <= cw:
                    cols = text.split("\t", 1)
                    text = "%*s %s" % (-cw, cols[0].rstrip(), cols[1].lstrip())
            text = text.expandtabs(8)
        w = self.textwidth # - 1
        if self.hoffset > 0:
            w -= 2
            line = u"< %*s" % (-w, text[self.hoffset:self.hoffset+w])
        else:
            if self.keyboardMode == CList.MODE_NUMSELECT:
                w -= (self.numselect.width + 1)
                lnstr = self.numselect.format % lineno
                line = u"%s %*s" % (lnstr, -w, text[self.hoffset:self.hoffset+w])
            else:
                line = u"%*s" % (-w, text[self.hoffset:self.hoffset+w])
        # TODO: text should be preprocessed to remove control characters!
        #nl = u""
        #for ch in line:
        #    if ord(ch) < 32: nl = nl + " "
        #    else: nl = nl + ch
        #line = nl
        return line

    def drawItems(self):
        y = 0
        top = self.topindex
        items = self.itemlist.items
        hasQuick = self.hoffset == 0 and self.keyboardMode == CList.MODE_QUICK
        hasNumSelect = self.keyboardMode == CList.MODE_NUMSELECT
        win = self.wcontent
        win.move(0, 0)
        # win.scrollok(False) # no effect, fails with addstr on last line
        for i in xrange(top, self.itemCount):
            y = i - top
            if y > self.lastline: break
            uline = self.getLineStr(items[i].displayText, y)
            # FIXME: outputEncoding: double-width characters will break the display
            line = uline.encode(self.outputEncoding, "replace") # unknown chars replaced with ?
            marked = items[i].marked
            if i == self.curindex and marked: co = self.coSelMarked
            elif i == self.curindex: co = self.coSelected
            elif marked: co = self.coMarked
            elif items[i].isTitle: co = self.coTitle
            else: co = self.coNormal
            if y < self.lastline: win.addstr(y, 0, line, co)
            else: win.insstr(y, 0, line, co)
            # win.addstr(y, 0, line, co) # combination with scrollok(False) - failed in curses
            if hasQuick and items[i].quickchar != None:
                # pos = items[i].quickCharPos
                pos = uline.lower().find(items[i].quickchar)
                if pos >= 0 and pos < self.textwidth - 1:
                    ch = uline[pos].encode(self.outputEncoding, "replace")
                    win.addstr(y, pos, ch, self.coHilight)
            if hasNumSelect:
                win.addstr(y, 0, self.numselect.format % y, self.coHilight)

        if y < self.lastline: win.clrtobot()
        self.window.redrawwin()

    def _drawPageInfo(self):
        pgsz = self.lastline + 1
        npages = (self.itemCount + pgsz - 1) / pgsz
        if npages < 2: return
        ipage = (self.topindex + 1) / pgsz + 1
        ptxt = "%d/%d" % (ipage, npages)
        x = self.width - len(ptxt) - 4
        co = self.coNormal
        self.window.addstr(self.height - 1, x, ptxt, co)

    def _drawFilter(self):
        if self.itemlist.strFilter != "" or self.keyboardMode == CList.MODE_FILTER:
            mtw = self.width - 6
            if mtw > 10: fieldw = 10
            else: fieldw = mtw
            s = self.itemlist.strFilter
            if len(s) > mtw: s = "/...%s" % s[-(mtw-3):]
            else: s = "/%*s" % (-fieldw+1, s)
            if self.keyboardMode == CList.MODE_NUMSELECT: s = ("#%s " % self.numselect.curNumber) + s
            if self.keyboardMode == CList.MODE_QUICK: s = "&& " + s
            if len(s) > mtw: s = s[-(mtw-3):]
            if self.keyboardMode == CList.MODE_FILTER: co = self.coSelected
            else: co = self.coNormal
            self.window.addstr(self.height - 1, 2, s, co)
        elif self.keyboardMode == CList.MODE_QUICK:
            self.window.addstr(self.height - 1, 2, "&&", self.coSelected)
        elif self.keyboardMode == CList.MODE_NUMSELECT:
            self.window.addstr(self.height - 1, 2, "#%s" % self.numselect.curNumber, self.coSelected)

    def drawLastLine(self): # status
        chline = self.window.linechars[0]
        self.window.hline(self.height - 1, 1, chline, self.width - 3)
        self._drawPageInfo()
        self._drawFilter()
        self.window.redrawln(self.height - 1, 1)

    def drawTitle(self):
        if self.itemlist != None and self.itemlist.title != None:
            chline = self.window.linechars[0]
            co = self.coNormal
            w = self.textwidth - 3
            s = self.itemlist.getTitle(w)
            self.window.addstr(0, 2, s, co)
            self.window.hline(0, 2 + len(s), chline, self.width - 3 - len(s))
            self.window.redrawln(0, 1)

    def setCurIndex(self, index, redraw=True):
        nItems = self.itemCount
        if index < 0 or nItems < 1: index = 0
        elif index >= nItems: index = nItems - 1
        # TODO: minimal redraw if the new line is on the same page
        page = self.lastline + 1
        if index < self.topindex or self.topindex + self.lastline < index:
            self.topindex = (index / page) * page
        if nItems > 0 and self.topindex >= nItems: self.topindex = nItems - 1
        self.curindex = index
        if redraw:
            self.drawItems()
            self.drawLastLine()

    def offsetCurIndex(self, offset):
        self.setCurIndex(self.curindex + offset)

    def getCurrentItem(self):
        if self.curindex < 0 or self.curindex >= len(self.itemlist.items): return None
        return self.itemlist.items[self.curindex]

    def setCurrentItem(self, item):
        try:
            ci = self.itemlist.items.index(item)
            self.setCurIndex(ci)
        except ValueError: pass

    # horizontal offset
    def offsetDisplay(self, offset):
        off = self.width / 2
        if offset == 0 or offset < 0 and self.hoffset == 0: return
        self.hoffset += offset * off
        if self.hoffset < 0: self.hoffset = 0
        self.drawItems()

    def doCommand(self, cmd):
        cmd = self.itemlist.doCommand(cmd, self.curindex)
        if cmd == "" or cmd == None: return
        elif cmd == "next": self.offsetCurIndex(1)
        elif cmd == "prev": self.offsetCurIndex(-1)
        elif cmd == "lshift": self.offsetDisplay(-1)
        elif cmd == "rshift": self.offsetDisplay(1)
        elif cmd == "nextpage": self.offsetCurIndex(self.lastline + 1)
        elif cmd == "prevpage": self.offsetCurIndex(-(self.lastline + 1))
        elif cmd == "home": self.setCurIndex(0)
        elif cmd == "end": self.setCurIndex(self.itemCount - 1)
        elif cmd == "quit":
            self.keyboardMode = CPopupListbox.EXIT
            self.exitcommand = (cmd, self.curindex)
        elif cmd == "accept":
            self.keyboardMode = CPopupListbox.EXIT
            self.exitcommand = (cmd, self.curindex)
        elif cmd == "quickchar":
            self.keyboardMode = CList.MODE_QUICK
        elif cmd == "exit-quickchar":
            self.keyboardMode = CList.MODE_NORMAL
        elif cmd == "filter":
            self.keyboardMode = CList.MODE_FILTER
        elif cmd == "filter-accept":
            self.keyboardMode = CList.MODE_NORMAL
        elif cmd == "filter-next":
            self.offsetCurIndex(1)
            self.keyboardMode = CList.MODE_NORMAL
        elif cmd == "filter-prev":
            self.offsetCurIndex(-1)
            self.keyboardMode = CList.MODE_NORMAL
        elif cmd == "filter-cancel":
            self.keyboardMode = CList.MODE_NORMAL
            self.itemlist.setFilter("")
            self.setCurIndex(self.curindex) # fix the index and redraw items
            self.drawLastLine()
        elif cmd == "filter-delete":
            l = len(self.itemlist.strFilter)
            if l < 1: self.keyboardMode = CList.MODE_NORMAL
            else:
                self.itemlist.setFilter(self.itemlist.strFilter[:l-1])
                self.setCurIndex(self.curindex) # fix the index and redraw items
                self.drawLastLine()
        elif cmd == "filter-restart":
            self.itemlist.setFilter("")
            self.setCurIndex(0)
            self.drawLastLine()
        elif cmd == "numselect":
            self.keyboardMode = CList.MODE_NUMSELECT
            self.numselect.curNumber = ""
            self.drawLastLine()
        elif cmd == "numselect-delete":
            self.numselect.curNumber = ""
            self.drawLastLine()
        elif cmd == "togglemarked":
            items = self.itemlist.items
            if self.curindex >= 0 and self.curindex < len(items):
                items[self.curindex].marked = not items[self.curindex].marked
                if self.itemlist._moveDownOnMark: self.setCurIndex(self.curindex + 1, redraw=True)
                else: self.setCurIndex(self.curindex, redraw=True)
                # TODO: Redraw only current item on togglemarked
        pass

    # If CList.prompt starts with \r, process further, oterwise return unprocessed.
    # Processing:
    #    replace {{mode}} with current lb keyborard mode
    #    replace {{extra}} with itemlist.getExtraPrompt
    def _buildPrompt(self):
        prompt = self.itemlist.prompt
        if prompt == None: prompt = "\rPopup List{{mode}}>>>{{extra}}"
        if not prompt.startswith("\r"): return prompt
        prompt = prompt.lstrip()
        if prompt.find("{{") < 0: return prompt
        mode = self.keyboardMode
        if mode == CList.MODE_NORMAL: p2 = ""
        elif mode == CList.MODE_FILTER: p2 = ".Filter"
        elif mode == CList.MODE_QUICK: p2 = ".QuickChar"
        elif mode == CList.MODE_NUMSELECT: p2 = ".NumSelect"
        else: p2 = ""
        prompt = prompt.replace("{{mode}}", p2)
        mw = int(vim.eval("&columns")) - 2 - len(prompt)
        if prompt.find("{{extra}}") >= 0:
            p3 = self.itemlist.getExtraPrompt(mw)[:mw] if mw > 0 else ""
            prompt = prompt.replace("{{extra}}", p3)
        return prompt

    def _vim_getkey(self):
        ioutil.CScreen().showPrompt(self._buildPrompt())
        key = vim.eval("getchar()")
        try:
            key = int(key)
            if key >= 0 and key < 256: key = chr(key)
            elif key > 255:
                key = u"%c" % key
                key = key.encode("utf-8")
        except: pass
        # TODO: Capture mouse position
        # Useless... v:mouse_lnum contains text line number, not screen line number
        # ( variables added with pathch 7.0.155, eval.c, vim.h )
        # print vim.eval('v:mouse_win . " " . v:mouse_lnum . " " . v:mouse_col')
        # self.lastclick = (screen.mousex - self.left, screen.mousey - self.top)
        # print self.lastclick
        return key

    def relayout(self, position, size):
        self.hide()
        self.left = position.x
        self.top = position.y
        self.width = size.x
        self.height = size.y
        self.window = None
        self.wcontent = None
        self.show()

    def _prepareScreen(self):
        scr = ioutil.CScreen()
        scr.clear()
        scr.showPrompt("")
        scr.refresh()
        vim.command("redraw!")

    def gotoQuickChar(self, ch):
        ch = ch.lower()
        items = self.itemlist.items
        N = len(items)
        if self.quickChar == None: pos = self.curindex
        else: pos = (self.curindex + 1) % N
        cands = []
        for i, it in enumerate(items):
            if it.quickchar == ch: cands.append( i )
        offs = 1 if self.quickChar == ch else 0
        self.quickChar = ch
        next = None
        if len(cands) == 1: next = cands[0]
        elif len(cands) > 1:
            for i in cands:
                if i >= self.curindex + offs:
                    next = i;
                    break
            if next == None: next = cands[0]
        if next != None:
            self.setCurIndex(next)
            if len(cands) == 1 and self.itemlist != None and self.itemlist.quickCharAutoSelect != None:
                self.doCommand(self.itemlist.quickCharAutoSelect)
        pass

    def resetQuickChar(self):
        self.quickChar = None
        
    def process_char(self, km, ch):
        if km == self.itemlist.keymapFilter:
            self.itemlist.setFilter(self.itemlist.strFilter + ch)
            self.drawLastLine()
            self.setCurIndex(0) # fix the index and redraw items
        elif km == self.itemlist.keymapQuickChar:
            self.gotoQuickChar(ch)
        elif km == self.itemlist.keymapNumSelect:
            newi = self.numselect.trySelectItem(ch, self.topindex, len(self.itemlist.items) - 1)
            if newi >= 0:
                self.setCurIndex(newi)
                self.drawLastLine()
            else:
                self.keyboardMode = CList.MODE_NORMAL
            if self.numselect.isComplete():
                self.keyboardMode = CList.MODE_NORMAL
        pass

    def process(self, curindex=0, startmode=CList.MODE_NORMAL):
        self.keyboardMode = startmode
        km = self.itemlist.keymapNorm
        if self.keyboardMode == CList.MODE_FILTER: km = self.itemlist.keymapFilter
        elif self.keyboardMode == CList.MODE_QUICK: km = self.itemlist.keymapQuickChar
        else: km = self.itemlist.keymapNorm
        self._prepareScreen()
        self.show(curindex)
        self.refresh()
        self.exitcommand = None
        keyseq = ""
        while self.keyboardMode != CPopupListbox.EXIT:
            curitem = self.getCurrentItem()
            if self.itemlist.checkPendingItems():
                if curitem != None: self.setCurrentItem(curitem)
            self.refresh()
            oldmode = self.keyboardMode
            ch = self._vim_getkey()

            if ch != None:
                keyseq += ch
                (res, cmd) = km.findKey(keyseq)
                if res == simplekeymap.KM_PREFIX: continue # TODO: display prefix
                elif res == simplekeymap.KM_MATCH: self.doCommand(cmd)
                elif len(ch) == 1 and ord(ch) >= 32 and ord(ch) < 127: self.process_char(km, ch)
            keyseq = ""

            if oldmode != self.keyboardMode:
                if self.keyboardMode == CPopupListbox.EXIT: break
                elif self.keyboardMode == CList.MODE_NORMAL:
                    km = self.itemlist.keymapNorm
                elif self.keyboardMode == CList.MODE_FILTER:
                    km = self.itemlist.keymapFilter
                elif self.keyboardMode == CList.MODE_QUICK:
                    km = self.itemlist.keymapQuickChar
                elif self.keyboardMode == CList.MODE_NUMSELECT:
                    km = self.itemlist.keymapNumSelect
                if oldmode == CList.MODE_QUICK:
                    self.resetQuickChar()
                self.drawTitle()
                self.drawItems()
                self.drawLastLine()

        # End of processing: return the selected exit-command (if any)
	self.hide()
        return self.exitcommand

class CPopupListboxScreen(CPopupListbox):
    colorSchemeChecked = "--"
    def initPlatform(self):
        try: cs = vim.eval("exists('g:colors_name') ? g:colors_name : ('*bg*' . &background)")
        except vim.error: cs="--"
        if cs != CPopupListboxScreen.colorSchemeChecked:
            try: vim.eval("vimuiex#vxlist#CheckHilightItems()")
            except vim.error: pass
            CPopupListboxScreen.colorSchemeChecked = cs

        # TODO: create user setting in vim for outputEncoding
        self.outputEncoding = vim.eval("&encoding")
        try:
            self.coNormal = vim.screen.getHighlightAttr("VxNormal")
            self.coSelected = vim.screen.getHighlightAttr("VxSelected")
            self.coHilight = vim.screen.getHighlightAttr("VxQuickChar")
            self.coMarked = vim.screen.getHighlightAttr("VxMarked")
            self.coSelMarked = vim.screen.getHighlightAttr("VxSelMarked")
            self.coTitle = vim.screen.getHighlightAttr("VxTitle")
            if self.coNormal == self.coSelected: raise
        except:
            self.coNormal = 1
            self.coSelected = 0
            self.coHilight = 3
            self.coMarked = 4
            self.coSelMarked = self.coSelected
            self.coTitle = self.coMarked
    pass

class CPopupListboxCurses(CPopupListbox):
    def initPlatform(self):
        self.outputEncoding = "ascii" # TODO: create user setting in vim
        import curses
        if curses.has_colors():
            curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)
            self.coNormal = curses.color_pair(1)
            curses.init_pair(2, curses.COLOR_WHITE, curses.COLOR_BLUE)
            self.coSelected = curses.color_pair(2)
            curses.init_pair(3, curses.COLOR_RED, curses.COLOR_WHITE)
            self.coHilight = curses.color_pair(3)
            curses.init_pair(4, curses.COLOR_MAGENTA, curses.COLOR_WHITE)
            self.coMarked = curses.color_pair(4)
            curses.init_pair(5, curses.COLOR_MAGENTA, curses.COLOR_BLUE)
            self.coSelMarked = curses.color_pair(5)
            curses.init_pair(6, curses.COLOR_BLUE, curses.COLOR_WHITE)
            self.coTitle = curses.color_pair(6)
        else:
            self.coNormal = curses.A_NORMAL
            self.coSelected = curses.A_UNDERLINE
            self.coHilight = curses.A_UNDERLINE
            self.coMarked = self.coHilight
            self.coSelMarked = self.coSelected
            self.coTitle =  self.coNormal
    pass

