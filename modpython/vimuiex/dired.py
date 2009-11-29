# vim: set fileencoding=utf-8 sw=4 ts=8 et : 
# dired.py - directory browsing service
#
# Author: Marko Mahnič
# Created: June 2009
# License: GPL (http://www.gnu.org/copyleft/gpl.html)
# This program comes with ABSOLUTELY NO WARRANTY.

import time, os, stat
import vim
import simplekeymap
import popuplist
import re

class CFileItem(popuplist.CListItem):
    def __init__(self, owner, fname, attrs=""):
        popuplist.CListItem.__init__(self, fname)
        self.owner = owner
        self._ftype = 'f'
        self.attrs = attrs
    
    @property
    def displayText(self):
        if self.owner.optShowAttrs: return u"%s   %s" % (self.attrs, self._text)
        return u"  %s" % self._text

class CDirectoryItem(popuplist.CListItem):
    def __init__(self, owner, fname, attrs=""):
        popuplist.CListItem.__init__(self, fname)
        self.owner = owner
        self._ftype = 'd'
        self.attrs = attrs
    
    @property
    def displayText(self):
        if self.owner.optShowAttrs: return u"%s + %s" % (self.attrs, self._text)
        return u"+ %s" % self._text

class CFileBrowser(popuplist.CList):
    def __init__(self, *args, **kwds):
        if not kwds.has_key("title"): kwds["title"] = "File browser"
        popuplist.CList.__init__(self, *args, **kwds)
        self.modifyKeymaps()
        self.currentPath = ""
        self.titleAlign = ">"
        self.minSize = (32, 8)
        self.osencoding = "utf-8" # TODO: get file-system encoding
        self.filterHide = "*.pyc,*.o,*.*~,.*.swp"
        self._masks_hide = None
        self.optShowAttrs = True
        self.exprRecentDirList = "g:VXRECENTDIRS"

    @property
    def _hideFilterMasks(self):
        if self._masks_hide == None:
            self._masks_hide = []
            for mask in self.filterHide.split(","):
                mask = mask.replace(".", r"\.").replace("*", ".*").replace("?", ".")
                try:
                    mask = re.compile(mask + "$", re.IGNORECASE)
                    self._masks_hide.append(mask)
                except: pass
        return self._masks_hide

    def _isHidden(self, fname):
        for mask in self._hideFilterMasks:
            mo = mask.match(fname)
            if mo != None: return True
        return False

    def hrsize(self, size):
        grps = ['B', 'K', 'M', 'G', 'T']
        lim = 1.5 * 1024
        size = 1.0 * size
        i = 0
        while i < len(grps):
            if size <= lim:
                if i == 0: return "%4dB" % int(size)
                else:
                    if size < 100: return "%4.1f%s" % (size, grps[i])
                    else: return "%4.0f%s" % (size, grps[i])
            i += 1
            size /= 1024
        return "*****"

    def listdir(self, path):
        dirs = []
        files = []
        for f in os.listdir(path):
            pathname = os.path.join(path, f)
            try:
                fst = os.stat(pathname)
                mode = fst.st_mode
                mtime = time.localtime(fst.st_mtime)
                if os.access(pathname, os.R_OK): modR = "r"
                else: modR="-"
                if os.access(pathname, os.W_OK): modW = "w"
                else: modW="-"
            except: continue
            if self._isHidden(f): continue
            fname = f.decode(self.osencoding, "replace")
            if stat.S_ISDIR(mode):
                attrs = "%s %s %s%s" % ("     ", time.strftime("%Y-%m-%d %H:%M", mtime), modR, modW)
                dirs.append([fname, CDirectoryItem(self, fname, attrs)])
            elif stat.S_ISREG(mode):
                attrs = "%s %s %s%s" % (self.hrsize(fst.st_size), time.strftime("%Y-%m-%d %H:%M", mtime), modR, modW)
                files.append([fname, CFileItem(self, fname, attrs)])
            else: pass
        return dirs, files

    def getExtraPrompt(self, maxwidth=30):
        # TODO: User configurable path replacements, like
        #     "HOME" = "/home/user"; "DOC" = "/home/user/Documents"
        if len(self.currentPath) <= maxwidth: return self.currentPath
        else: return "...%s" % self.currentPath[-(maxwidth-3):]

    def loadDirectory(self, path):
        path = os.path.abspath(path)
        self.currentPath = path
        dirs, files = self.listdir(path)
        dirs.sort()
        files.sort()
        self.allitems = [CDirectoryItem(self, u"..", " " * 25)]
        for fn in dirs: self.allitems.append(fn[1])
        for fn in files: self.allitems.append(fn[1])
        self.title = self.currentPath
        self.refreshDisplay()

    def modifyKeymaps(self):
        # override CList commands; handle them in doListCommand
        for km in [self.keymapNorm]:
            km.setKey("\<CR>", "list:dired-select")
            # km.setKey("\<LeftMouse>", "list:dired-select") # TODO: double click
            km.setKey("\<BS>", "list:dired-goback")
            km.setKey("\<RightMouse>", "list:dired-goback")
            km.setKey("d", "list:dired-recentdir") # TODO: shortcut
            km.setKey("a", "list:dired-attributes")
            # TODO: attribute shortcuts: on/off aa-toggle; sort
            # by name, ext, size, time (an ae as at - toggle direction)
        self.quickCharAutoSelect = ""
        self.keymapFilter.setKey("\<CR>", "list:dired-filter-select")
        # TODO: add + to show one sublevel more, - to show one sublevel less

    def cd(self, relpath):
        (par, curdir) = os.path.split(self.currentPath)
        self.loadDirectory(os.path.join(self.currentPath, relpath))
        self.setFilter("")
        self.relayout()
        if relpath != "..": self.setCurIndex(0)
        else:
            for i, item in enumerate(self.allitems):
                if item._ftype != 'd': continue
                if item._text == curdir:
                    self.setCurIndex(i)
                    break

    def doListCommand(self, cmd, curindex):
        if cmd == "dired-goback": self.cd("..")
        elif cmd == "dired-select" or cmd == "dired-filter-select":
            i = self.getTrueIndex(curindex)
            selitem = self.allitems[i]
            if selitem._ftype == 'd':
                self.cd(selitem._text)
                if cmd == "dired-filter-select": return "filter-restart"
            else:
                fn = os.path.join(self.currentPath, selitem._text)
                fn = fn.replace(" ", "\\ ")
                cmd = u"edit %s" % fn
                cmd = cmd.encode(vim.eval("&encoding"))
                vim.command(cmd)
                return "quit"
        elif cmd == "dired-recentdir": # This will not work with wx
            dirs = vim.eval(self.exprRecentDirList)
            dirs = dirs.strip()
            if dirs != "":
                dirs = (u"%s" % dirs).split("\n")
                def _chdir(i):
                    newdir = dirs[i]
                    if newdir == self.currentPath: return
                    self.loadDirectory(newdir)
                    # self.setFilter("")
                    self.relayout()
                    self.setCurIndex(0)
                List = popuplist.CList(title="Recent directories", autosize="VH", align="B")
                List.loadUnicodeItems(dirs)
                List.cmdAccept = _chdir
                List.process(curindex=0)
                List=None
                self.redraw()
        elif cmd == "dired-attributes":
            self.optShowAttrs = not self.optShowAttrs
            self.relayout()
        else: return popuplist.CList.doListCommand(self, cmd, curindex)

    def process(self, curindex=0):
        self.loadDirectory(os.getcwd())
        popuplist.CList.process(self, curindex, startmode=1) # TODO: startmode=sth.NORMAL

