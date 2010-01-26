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
        if self.owner._attributesVisible: return u"%s   %s" % (self.attrs, self._text)
        return u"  %s" % self._text

class CDirectoryItem(popuplist.CListItem):
    def __init__(self, owner, fname, attrs=""):
        popuplist.CListItem.__init__(self, fname)
        self.owner = owner
        self._ftype = 'd'
        self.attrs = attrs
    
    @property
    def displayText(self):
        if self.owner._attributesVisible: return u"%s + %s" % (self.attrs, self._text)
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
        self.filterHide = "*.pyc,*.o,*.*~,.*.swp" # TODO: user-editable
        self._masks_hide = None
        self.optShowAttrs = True
        self.exprRecentDirList = "g:VXRECENTDIRS"
        self.callbackEditFile = ""
        self.subdirDepth = 0

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

    @property
    def _attributesVisible(self):
        return self.optShowAttrs and self.subdirDepth == 0

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

    def onFilterChanged(self, old, new):
        if self.subdirDepth < 1: return
        # when displaying subdirs, we add only matching items
        self.loadDirectory(self.currentPath)
        self.relayout()

    # TODO: change listtree from DFS to BFS
    # listtree: add only the items that match self.strFilter
    def listtree(self, path, root=None, depth=0, count=0):
        files = []
        if root == None: root = path
        filt = self.getFilterWords()
        for f in os.listdir(path):
            pathname = os.path.join(path, f)
            try:
                fst = os.stat(pathname)
                mode = fst.st_mode
            except: continue
            if self._isHidden(f): continue
            fname = os.path.relpath(pathname, root)
            fname = fname.decode(self.osencoding, "replace")
            if stat.S_ISDIR(mode):
                good, pos = self.matchFilterWords(fname.lower(), filt)
                if good: files.append([fname, CDirectoryItem(self, fname)])
                if depth > 0 and count+len(files) < 1000: # TODO: user configurable limit on # of files
                    files = files + self.listtree(pathname, root, depth-1, count + len(files))
            elif stat.S_ISREG(mode):
                good, pos = self.matchFilterWords(fname.lower(), filt)
                if good: files.append([fname, CFileItem(self, fname)])
            else: pass
        return files

    def getExtraPrompt(self, maxwidth=30):
        # TODO: User configurable path replacements, like
        #     "HOME" = "/home/user"; "DOC" = "/home/user/Documents"
        if len(self.currentPath) <= maxwidth: return self.currentPath
        else: return "...%s" % self.currentPath[-(maxwidth-3):]

    def loadDirectory(self, path):
        path = os.path.abspath(path)
        self.currentPath = path
        self.allitems = [CDirectoryItem(self, u"..", " " * 25)]
        self.title = self.currentPath
        if self.subdirDepth < 1:
            dirs, files = self.listdir(path)
            dirs.sort()
            files.sort()
            for fn in dirs: self.allitems.append(fn[1])
            for fn in files: self.allitems.append(fn[1])
        else:
            files = self.listtree(path, path, self.subdirDepth)
            files.sort()
            for fn in files: self.allitems.append(fn[1])
        self.refreshDisplay()

    def modifyKeymaps(self):
        # override CList commands; handle them in doListCommand
        for km in [self.keymapNorm]:
            km.setKey(r"\<CR>", "list:dired-select")
            # km.setKey("\<LeftMouse>", "list:dired-select") # TODO: double click
            km.setKey(r"\<BS>", "list:dired-goback")
            km.setKey(r"\<RightMouse>", "list:dired-goback")
            km.setKey(r"d", "list:dired-recentdir") # TODO: shortcut
            km.setKey(r"oa", "list:dired-attributes")
            # TODO: attribute shortcuts: sort by name, ext, size, time (on oe os ot; toggle direction)
            km.setKey(r"+", "list:dired-subdirmore")
            km.setKey(r"-", "list:dired-subdirless")
        for km in [self.keymapNorm, self.keymapFilter]:
            km.setKey(r"\<c-l>", "list:dired-subdirmore")
            km.setKey(r"\<c-h>", "list:dired-subdirless")
            km.setKey(r"\<c-k>", "list:dired-subdirnone")
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

    def _diredRecentDir(self):
        dirs = vim.eval(self.exprRecentDirList)
        dirs = dirs.strip()
        if dirs == "": return ""
        dirs = (u"%s" % dirs).split("\n")
        def _chdir(i):
            newdir = dirs[i]
            if newdir == self.currentPath: return
            self.loadDirectory(newdir)
            # self.setFilter("")
            self.relayout()
            self.setCurIndex(0)
        List = popuplist.CList(title="Recent directories") # , autosize="VH", align="B")
        List.loadUnicodeItems(dirs)
        List.cmdAccept = _chdir
        List.process(curindex=0)
        List=None
        self.redraw()
        return ""

    def _diredSelect(self, cmd, parms, curindex):
        i = self.getTrueIndex(curindex)
        selitem = self.allitems[i]
        if selitem._ftype == 'd':
            self.cd(selitem._text)
            if cmd == "dired-filter-select": return "filter-restart"
            return ""
        fn = os.path.join(self.currentPath, selitem._text)
        vimenc = vim.eval("&encoding")
        if self.callbackEditFile == None or self.callbackEditFile == "":
            fn = fn.replace(" ", "\\ ")
            cmd = u"edit %s" % fn
            cmd = cmd.encode(vimenc)
            vim.command(cmd)
            return "quit"
        else:
            vimpar = ",".join(["'%s'" % p for p in parms]) # TODO: escape string
            if vimpar == "": vimpar = "''"
            def expandParam_p(theList, allitems, item): return vimpar
            expr = self.expandVimCommand(self.callbackEditFile, curindex, { "{{p}}": expandParam_p })
            try:
                rv = vim.eval(expr)
                if rv == "q": return "quit"
            except Exception as e:
                vim.command("echom '_diredSelect: %s'" % e)
                pass
        return ""

    def expandVimCommand(self, command, curindex, extraParamHandlers={}):
        extraParamHandlers["{{pwd}}"] = lambda s,a,i: "'%s'" % self.currentPath # TODO: escape string
        return popuplist.CList.expandVimCommand(self, command, curindex, extraParamHandlers)

    # cmd exception: the command can have parameters
    def doListCommand(self, cmd, curindex):
        cmd = cmd.split()
        parms = cmd[1:]
        cmd = cmd[0]
        if cmd == "dired-goback": self.cd("..")
        elif cmd == "dired-select" or cmd == "dired-filter-select":
            return self._diredSelect(cmd, parms, curindex)
        elif cmd == "dired-recentdir": # This will not work with wx
            return self._diredRecentDir()
        elif cmd == "dired-attributes":
            self.optShowAttrs = not self.optShowAttrs
            self.relayout()
        elif cmd == "dired-subdirmore":
            self.subdirDepth += 1
            self.loadDirectory(self.currentPath)
            self.relayout()
        elif cmd == "dired-subdirless":
            self.subdirDepth -= 1
            if self.subdirDepth < 0: self.subdirDepth = 0
            self.loadDirectory(self.currentPath)
            self.relayout()
        elif cmd == "dired-subdirnone":
            self.subdirDepth = 0
            self.loadDirectory(self.currentPath)
            self.relayout()
        else: return popuplist.CList.doListCommand(self, cmd, curindex)
        return ""

    def process(self, curindex=0, cwd=None):
        if cwd == None: cwd = os.getcwd()
        else:
            if not os.path.exists(cwd): cwd = os.getcwd()
            fst = os.stat(cwd)
            if not stat.S_ISDIR(fst.st_mode): cwd = os.getcwd()
        self.loadDirectory(cwd)
        popuplist.CList.process(self, curindex, startmode=1) # TODO: startmode=sth.NORMAL

