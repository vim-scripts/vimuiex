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
        # py2.5(2): sub = "[+] " if self.submenu else "    "
        if self.submenu: sub = submenuIcon
        else: sub = " " * (len(submenuIcon))
        # py2.5(2): cmd = "   [%s]" % self.command if self.command != None else ""
        if self.command != None: cmd = "   [%s]" % self.command
        else: cmd = ""
        txt = sub + self.title.strip().replace("&", "")
        if cmd != "": return txt + "\t" + cmd
        #if firstColumnWidth == None or firstColumnWidth < 22: firstColumnWidth = 22
        #txt = "%*s\t" % (-firstColumnWidth, txt)
        return txt + "\t"

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
        self.menuitems = []
        self.menupath = [] # stack of positions in menuitems
        self.curitems = [] # list of positions of currently displayed items
        self.modifyKeymaps()
        self.submenuIcon = "+ "
        self.autosize += "C"
        self.maxColumnWidth = 0.7

    def selectLevel(self):
        level = len(self.menupath)
        if level == 0: pos = 0
        else: pos = self.menupath[level-1] + 1
        mmax = len(self.menuitems)
        self.curitems = []
        # TODO: get all items with level until the next item with level-1 or EOF
        while pos < mmax:
            m = self.menuitems[pos]
            if m.level == level: self.curitems.append(pos)
            elif m.level < level: break
            pos += 1
        # items = [self.menuitems[i].getDisplayText() for i in self.curitems]
        # self.loadUnicodeItems(items)
        self.allitems = []
        for i in self.curitems:
            item = popuplist.CListItem(self.menuitems[i].getDisplayText(self.submenuIcon))
            item.quickchar = self.menuitems[i].getQuickChar()
            self.allitems.append(item)
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
                vim.command('emenu %s' % path)
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

