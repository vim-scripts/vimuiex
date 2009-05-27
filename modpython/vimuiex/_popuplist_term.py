# vim: set fileencoding=utf-8 sw=4 ts=8 et :
# _popuplist_term.py - a popup listbox implementation for terminals (curses)
#
# Author: Marko Mahnič
# Created: April 2009
# License: GPL (http://www.gnu.org/copyleft/gpl.html)
# This program comes with ABSOLUTELY NO WARRANTY.
#
# (loaded by popuplist.py)

import time
import vim
import simplekeymap
import curses
import globals.gcurses
stdscr = globals.gcurses.vimPrepareScreen()

def log(msg):
    f = open ("testlog.txt", "a")
    f.write(msg + "\n")
    f.close()

class CPopupListbox(object):
    EXIT = 0
    NORMAL = 1
    FILTER = 2
    QUICK = 3 #TODO
    def __init__(self, position, size): # TODO: CWinArranger
        self.itemlist = None # CList
        self.left = position[0]
        self.top = position[1]
        self.width = size[0]
        self.height = size[1]
        self.window = None
        self.wcontent = None
        self.textwidth = self.width - 2
        self.lastline = self.height - 3
        self.topindex = 0
        self.hoffset = 0
        self.curindex = 0
        self.exitcommand = ""
        self.keyboardMode = CPopupListbox.NORMAL
        self.quickChar = None # Currently active quick char
        self.yPrompt = int(vim.eval("&lines")) - 1
        self.initColors()

    def initColors(self):
        if curses.has_colors():
            curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)
            self.coNormal = curses.color_pair(1)
            curses.init_pair(2, curses.COLOR_WHITE, curses.COLOR_BLUE)
            self.coSelected = curses.color_pair(2)
            curses.init_pair(3, curses.COLOR_RED, curses.COLOR_WHITE)
            self.coHilight = curses.color_pair(3)
        else:
            self.coNormal = curses.A_NORMAL
            self.coSelected = curses.A_UNDERLINE
            self.coHilight = curses.A_UNDERLINE

    @property
    def itemCount(self):
        if self.itemlist == None or self.itemlist.items == None: return 0
        return len(self.itemlist.items)

    def setItemList(self, clist):
        self.itemlist = clist

    def refreshDisplay(self):
        self.refresh()

    def initWindow(self):
        self.textwidth = self.width - 2
        self.lastline = self.height - 3
        self.topindex = 0
        self.hoffset = 0
        self.window = curses.newwin(self.height, self.width, self.top, self.left)
        self.wcontent = self.window.derwin(self.height-2, self.width-2, 1, 1)

    def show(self, curindex=None):
        if self.window == None: self.initWindow()

        co = self.coNormal
        self.window.attrset(co)
        self.window.border()

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
        stdscr.refresh()
        vim.command("redraw!")

    def getLineStr(self, text):
        w = self.textwidth
        if text.find("\t") >= 0: text = text.expandtabs(8)
        if self.hoffset > 0:
            w -= 1
            line = "<%*s" % (-w, text[self.hoffset:self.hoffset+w])
        else:
            line = "%*s" % (-w, text[self.hoffset:self.hoffset+w])

        # TODO: return line.encode(globals.gcurses.code) # not working with utf-8 (py 2.5, py-curses 2.2)
        return line.encode("ascii", "replace") # unknown chars replaced with ?

    def drawItems(self):
        y = 0
        top = self.topindex
        items = self.itemlist.items
        self.wcontent.move(0, 0)
        for i in xrange(top, self.itemCount):
            y = i - top
            if y > self.lastline: break
            line = self.getLineStr(items[i].text)
            # py2.5(2): co = cosel if i == self.curindex else conor
            if i == self.curindex: co = self.coSelected
            else: co = self.coNormal
            if y < self.lastline:
                self.wcontent.addstr(y, 0, line, co)
            else:
                # w = self.textwidth - 1
                # self.wcontent.addnstr(y, 0, line, w, co)
                # self.wcontent.insch(y, w, line[w], co)
                self.wcontent.insstr(y, 0, line, co) # not perfect...
            if self.keyboardMode == CPopupListbox.QUICK and self.hoffset == 0 and items[i].quickchar != None:
                pos = items[i].text.lower().find(items[i].quickchar)
                if pos >= 0 and pos < self.textwidth - 1:
                    ch = items[i].text[pos]
                    self.wcontent.addstr(y, pos, ch, self.coHilight)

        if y < self.lastline: self.wcontent.clrtobot()
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
        if self.keyboardMode == CPopupListbox.FILTER or self.itemlist.strFilter != "":
            mtw = self.width - 6
            s = self.itemlist.strFilter
            if len(s) > mtw: s = "/...%s" % s[-(mtw-3):]
            else: s = "/%s" % s
            if self.keyboardMode == CPopupListbox.QUICK: s = "&& " + s
            if len(s) > mtw: s = s[-(mtw-3):]
            if self.keyboardMode == CPopupListbox.FILTER: co = self.coSelected
            else: co = self.coNormal
            self.window.addstr(self.height - 1, 2, s, co)
        elif self.keyboardMode == CPopupListbox.QUICK:
            self.window.addstr(self.height - 1, 2, "&&", self.coSelected)

    def drawLastLine(self): # status
        self.window.hline(self.height - 1, 1, curses.ACS_HLINE, self.width - 3)
        self._drawPageInfo()
        self._drawFilter()
        self.window.redrawln(self.height - 1, 1)

    def drawTitle(self):
        if self.itemlist != None and self.itemlist.title != None:
            chline = curses.ACS_HLINE
            co = self.coNormal
            w = self.textwidth
            s = self.itemlist.title[:w]
            self.window.addstr(0, 2, s, co)
            self.window.hline(chline, self.width - 3 - len(s))
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

    # horizontal offset
    def offsetDisplay(self, offset):
        if offset == 0 or offset < 0 and self.hoffset == 0: return
        self.hoffset += offset * 10
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
            self.exitcommand = self.itemlist.expandVimCommand(self.itemlist.cmdCancel, self.curindex)
        elif cmd == "accept":
            self.keyboardMode = CPopupListbox.EXIT
            self.exitcommand = self.itemlist.expandVimCommand(self.itemlist.cmdAccept, self.curindex)
        elif cmd == "quickchar":
            self.keyboardMode = CPopupListbox.QUICK
        elif cmd == "exit-quickchar":
            self.keyboardMode = CPopupListbox.NORMAL
        elif cmd == "filter":
            self.keyboardMode = CPopupListbox.FILTER
        elif cmd == "filter-accept":
            self.keyboardMode = CPopupListbox.NORMAL
        elif cmd == "filter-cancel":
            self.keyboardMode = CPopupListbox.NORMAL
            self.itemlist.setFilter("")
            self.setCurIndex(self.curindex) # fix the index and redraw items
            self.drawLastLine()
        elif cmd == "filter-delete":
            l = len(self.itemlist.strFilter)
            if l < 1: self.keyboardMode = CPopupListbox.NORMAL
            else:
                self.itemlist.setFilter(self.itemlist.strFilter[:l-1])
                self.setCurIndex(self.curindex) # fix the index and redraw items
                self.drawLastLine()
        pass

    def _processMouse(self):
        # Buttons activated on click
        key = None
        try:
            id, x, y, z, bstate = curses.getmouse()
            if not self.window.enclose(y, x):
                return None
            key = None; mod = ""
            if bstate & curses.BUTTON1_CLICKED != 0: key = "LeftMouse"
            elif bstate & curses.BUTTON2_CLICKED != 0: key = "MiddleMouse"
            elif bstate & curses.BUTTON3_CLICKED != 0: key = "RightMouse"
            if key == None:
                return None
            x -= self.left
            y -= self.top
            idxclick = self.topindex + y - 1
            if idxclick > self.itemCount - 1:
                return None
            self.setCurIndex(idxclick)
            if bstate & curses.BUTTON_SHIFT: mod += "S-"
            if bstate & curses.BUTTON_CTRL: mod += "C-"
            if bstate & curses.BUTTON_ALT: mod += "A-"
            key = simplekeymap.KEYCODE[mod + key]
        except:
            # print "getmouse failed"
            for i in xrange(3): c = stdscr.getch()
            return None
        return key

    def _vim_getkey(self): # ref: globals.gvim
        # when Esc is pressed it is echoed to current line
        # curses.setsyx(self.yPrompt, 0) # doesn't work as expected
        stdscr.addch(self.yPrompt, 0, '>')
        stdscr.refresh()
        key = vim.eval("getchar()")
        try:
            key = int(key)
            if key >= 0 and key < 256: key = chr(key)
            elif key > 255:
                key = u"%c" % key
                key = key.encode("utf-8")
        except: pass
        return key

    def _curses_getkey(self):
        c = stdscr.getch()
        # log("%d (mouse=%d)" % (c, curses.KEY_MOUSE))

        # TODO: not reliable. Fails if curses fails to process an escape seq.
        #   eg. ubuntu+konsole+xterm-colors: home/end not recogised by curses -> don't work
        ch = None
        if c == 8 or c == 330 or c == curses.KEY_BACKSPACE: # unreliable...
            ch = simplekeymap.KEYCODE["BS"]
        elif c == 10 or c == curses.KEY_ENTER: ch = simplekeymap.KEYCODE["CR"]
        elif c == 27: ch = simplekeymap.KEYCODE["ESC"]
        elif c < 256: ch = chr(c)
        elif c == curses.KEY_UP: ch = simplekeymap.KEYCODE["up"]
        elif c == curses.KEY_DOWN: ch = simplekeymap.KEYCODE["down"]
        elif c == curses.KEY_LEFT: ch = simplekeymap.KEYCODE["left"]
        elif c == curses.KEY_RIGHT: ch = simplekeymap.KEYCODE["right"]
        elif c == curses.KEY_PREVIOUS: ch = simplekeymap.KEYCODE["pageup"]
        elif c == curses.KEY_NEXT: ch = simplekeymap.KEYCODE["pagedown"]
        elif c == curses.KEY_HOME: ch = simplekeymap.KEYCODE["home"]
        elif c == curses.KEY_END: ch = simplekeymap.KEYCODE["end"]
        elif c == curses.KEY_MOUSE: ch = self._processMouse()
        else: ch = None
        return ch

    def relayout(self, position, size):
        self.hide()
        self.left = position[0]
        self.top = position[1]
        self.width = size[0]
        self.height = size[1]
        self.window = None
        self.wcontent = None
        self.show()

    def _prepareScreen(self):
        stdscr.clear()
        stdscr.addch(self.yPrompt, 0, '>')
        stdscr.refresh()
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

    def process(self, curindex=0, startmode=1): # TODO: startmode=sth.NORMAL
        self.keyboardMode = startmode
        km = self.itemlist.keymapNorm
        if self.keyboardMode == CPopupListbox.FILTER: km = self.itemlist.keymapFilter
        elif self.keyboardMode == CPopupListbox.QUICK: km = self.itemlist.keymapQuickChar
        else: km = self.itemlist.keymapNorm
        self._prepareScreen()
        self.show(curindex)
        self.refresh()
        self.exitcommand = ""
        keyseq = ""
        while self.keyboardMode != CPopupListbox.EXIT:
            self.refresh()
            oldmode = self.keyboardMode
            # ch = self._curses_getkey()
            ch = self._vim_getkey()

            if ch == None: keyseq = ""
            else:
                keyseq += ch
                (res, cmd) = km.findKey(keyseq)
                if res == simplekeymap.KM_PREFIX: continue # TODO: display prefix
                elif res == simplekeymap.KM_MATCH: self.doCommand(cmd)
                elif len(ch) == 1 and ord(ch) >= 32 and ord(ch) < 127:
                    if km == self.itemlist.keymapFilter:
                        self.itemlist.setFilter(self.itemlist.strFilter + ch)
                        self.drawLastLine()
                        self.setCurIndex(self.curindex) # fix the index and redraw items
                    elif km == self.itemlist.keymapQuickChar:
                        self.gotoQuickChar(ch)
                keyseq = ""

            if oldmode != self.keyboardMode:
                if self.keyboardMode == CPopupListbox.EXIT: break
                elif self.keyboardMode == CPopupListbox.NORMAL:
                    km = self.itemlist.keymapNorm
                elif self.keyboardMode == CPopupListbox.FILTER:
                    km = self.itemlist.keymapFilter
                elif self.keyboardMode == CPopupListbox.QUICK:
                    km = self.itemlist.keymapQuickChar
                if oldmode == CPopupListbox.QUICK:
                    self.resetQuickChar()
                self.drawTitle()
                self.drawItems()
                self.drawLastLine()

        # End of processing: execute the selected command
	self.hide()
	vim.command("redraw!")
	if len(self.exitcommand) > 0: vim.command(self.exitcommand)

def testpopuplb():
    import lister
    List = lister.CList()
    List.loadTestItems()
    # List.normoperation = {...}
    # List.findoperation = {...}
    LB = CPopupListbox((6, 5), (20, 40))
    LB.setItemList(List)
    LB.show()
    LB.process()
    LB.hide()
    vim.command("redraw!")
    if len(LB.exitcommand) > 0:
        vim.command(LB.exitcommand)

