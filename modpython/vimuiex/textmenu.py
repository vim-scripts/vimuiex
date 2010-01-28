# vim: set fileencoding=utf-8 sw=4 ts=8 et : 
# textmenu.py - text menu implementation with a popup listbox
#
# Author: Marko Mahnič
# Created: April 2009
# License: GPL (http://www.gnu.org/copyleft/gpl.html)
# This program comes with ABSOLUTELY NO WARRANTY.

import time
import vim
import simplekeymap
import popuplist
import re

def log(msg):
    f = open ("testlog.txt", "a")
    f.write(msg + "\n")
    f.close()

class CMenuItem:
    def __init__(self, title):
        tnp = title.lstrip().lstrip("0123456789")
        lenpri = len(title) - len(tnp)
        self.priority = title[:lenpri]
        title = title[lenpri + 1:]
        tp = title.split("^I")
        self.title = tp[0]
        if len(tp) > 1: self.command = tp[1] # TODO: rename self.command to self.keycmd
        else: self.command = None
        self.level = -1
        self.submenu = False
        self.separator = False
        t = self.title.strip()
        if t[:4].lower() == "-sep": self.separator = True

    def getDisplayText(self, submenuIcon="[+] "):
        if self.separator: return "-" * 30
        if self.submenu: sub = submenuIcon
        else: sub = " " * (len(submenuIcon))
        if self.command != None: cmd = "   [%s]" % self.command
        else: cmd = ""
        txt = sub + self.title.strip().replace("&", "")
        if cmd != "": return txt + "\t" + cmd
        return txt + "\t"

    def getTitleText(self):
        txt = self.title.strip().replace("&", "")
        txt = txt.replace("\t", " ")
        txt = u"%s" % txt
        return txt.encode("ascii", "replace")

    def getQuickChar(self):
        pos = self.title.find("&")
        if pos >= 0:
            pos += 1
            if pos < len(self.title): return self.title[pos].lower()
        return None

    def getEmenuText(self):
        t = self.title.replace("&", "")
        esc = """\\ '".""" # slash first!
        for ch in esc: t = t.replace(ch, r"\%s" % ch)
        return t

class CTextMenu(popuplist.CList):
    def __init__(self, *args, **kwds):
        if not kwds.has_key("title"): kwds["title"] = "Menu"
        popuplist.CList.__init__(self, *args, **kwds)
        self.topTitle = self.title
        self.menuitems = []
        self.menupath = [] # stack of positions in menuitems
        self.curitems = [] # list of positions of currently displayed items
        self.modifyKeymaps()
        self.submenuIcon = "+ "
        self._firstColumnAlign = True # self.autosize += "C"
        self.maxColumnWidth = 0.7

    # Assign missing quickchars; TODO: move to CList?
    def assignQuickChars(self, items):
        chars = {None: 0}
        def addChar(ch):
            if not chars.has_key(ch): chars[ch] = 0
            chars[ch] += 1
        def isValidChar(ch):
            return (ch >= 'a' and ch <= 'z') or (ch >= '0' and ch <= '9')
        def wordStarts(text):
            pc = " "; ws = []
            for ch in text:
                ch = ch.lower()
                if (pc == " " or pc == "\t") and isValidChar(ch): ws.append(ch)
                pc = ch
            return ws
        for it in items: addChar(it.quickchar)
        if chars[None] < 1: return
        for it in (i for i in items if i.quickchar == None):
            for ch in wordStarts(it._text):
                if not chars.has_key(ch):
                    it.quickchar = ch
                    addChar(ch)
                    chars[None] -= 1
                    break
        for it in (i for i in items if i.quickchar == None):
            for ch in it._text:
                ch = ch.lower()
                if not isValidChar(ch): continue
                if not chars.has_key(ch):
                    it.quickchar = ch
                    addChar(ch)
                    chars[None] -= 1
                    break
        if chars[None] < 1: return
        # TODO: assign a quickchar char with least occurences

    def updateMenuTitle(self):
        level = len(self.menupath)
        if level == 0: self.title = self.topTitle
        else:
            item = self.menuitems[self.menupath[level-1]]
            self.title = item.getTitleText()

    def selectLevel(self):
        level = len(self.menupath)
        if level == 0: pos = 0
        else: pos = self.menupath[level-1] + 1
        mmax = len(self.menuitems)
        self.curitems = []
        # get all items with level until the next item with level-1 or EOF
        while pos < mmax:
            m = self.menuitems[pos]
            if m.level == level: self.curitems.append(pos)
            elif m.level < level: break
            pos += 1
        self.allitems = []
        for i in self.curitems:
            menuitem = self.menuitems[i]
            listitem = popuplist.CListItem(menuitem.getDisplayText(self.submenuIcon))
            listitem.quickchar = menuitem.getQuickChar()
            self.allitems.append(listitem)
        self.assignQuickChars(self.allitems)
        self.updateMenuTitle()
        self.refreshDisplay()

    def loadMenuItems(self, vimvar):
        encoding = vim.eval("&encoding")
        self.menuitems = [CMenuItem(line.decode(encoding)) for line in vim.eval(vimvar)]
        prev = None
        for i in xrange(len(self.menuitems)):
            m = self.menuitems[i]
            # assume 2 spaces per indent
            ns = len(m.priority) - len(m.priority.lstrip())
            m.level = ns / 2
            if prev != None and m.level > prev.level: prev.submenu = True
            prev = m

    def modifyKeymaps(self):
        # override CList commands; handle them in doCommand
        for km in [ self.keymapNorm, self.keymapQuickChar ]:
            km.setKey("\<CR>", "list:menu-select")
            km.setKey("\<LeftMouse>", "list:menu-select")
            km.setKey("\<BS>", "list:menu-goback")
            km.setKey("\<RightMouse>", "list:menu-goback")
        self.quickCharAutoSelect = "list:menu-select"

    def doListCommand(self, cmd, curindex):
        if cmd == "menu-select":
            i = self.getTrueIndex(curindex)
            mnu = self.menuitems[self.curitems[i]]
            if mnu.separator: return("next")
            elif mnu.submenu:
                self.menupath.append(self.curitems[i])
                self.selectLevel()
                self.setFilter("")
                self.relayout()
                return "home"
            else:
                vim.command("redraw!")
                # execute menu (with emenu) and "quit"
                encoding = vim.eval("&encoding")
                path = [self.menuitems[prnt] for prnt in self.menupath]
                path.append(mnu)
                path = [m.getEmenuText() for m in path]
                path = ".".join(path).encode(encoding)
                try:
                    # TODO: implement emenu in a vim function (callback) and use vim.eval.
                    vim.command('emenu %s' % path)
                except vim.error:
                    vim.command("echom 'menu-select: vim.error caught'")
                return "quit" 
        elif cmd == "menu-goback":
            if len(self.menupath) > 0:
                bkmenu = self.menupath[-1]
                self.menupath = self.menupath[:-1]
                self.selectLevel()
                self.setFilter("")
                pos = self.curitems.index(bkmenu)
                self.setCurIndex(pos)
                self.relayout()
                return ""
        else: return popuplist.CList.doListCommand(self, cmd, curindex)

    def process(self, curindex=0):
        self.menupath = []
        self.selectLevel()
        popuplist.CList.process(self, curindex, startmode=3) # TODO: startmode=sth.QUICK

