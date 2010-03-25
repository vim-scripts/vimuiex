# vim: set fileencoding=utf-8 sw=4 ts=8 et : 
# dired.py - directory browsing service
#
# Author: Marko Mahnič
# Created: June 2009
# License: GPL (http://www.gnu.org/copyleft/gpl.html)
# This program comes with ABSOLUTELY NO WARRANTY.

import time, os, stat
import re
import threading
import vim
import simplekeymap
from popuplist import CList, CListItem

class CFileFilter:
    def __init__(self):
        self._skipDirs = []
        self._skipFiles = []

    def clear(self):
        self._skipDirs = []
        self._skipFiles = []

    def skipFiles(self, strMasks, delimiter=','):
        for mask in strMasks.split(delimiter):
            mask = mask.replace(".", r"\.").replace("*", ".*").replace("?", ".")
            try:
                mask = re.compile("^" + mask + "$", re.IGNORECASE)
                self._skipFiles.append(mask)
            except: pass

    def skipDirs(self, strMasks, delimiter=','):
        for mask in strMasks.split(delimiter):
            mask = mask.replace(".", r"\.").replace("*", ".*").replace("?", ".")
            try:
                mask = re.compile("^" + mask + "$", re.IGNORECASE)
                self._skipDirs.append(mask)
            except: pass

    def fileAccepted(self, fname):
        for mask in self._skipFiles:
            mo = mask.match(fname)
            if mo != None: return False
        return True

    def dirAccepted(self, fname):
        for mask in self._skipDirs:
            mo = mask.match(fname)
            if mo != None: return False
        return True

class CTreeListerThread(threading.Thread):
    def __init__(self, sink, path, root=None, depth=5, fileFilter=None, listDirs=False, batchSize=300):
        threading.Thread.__init__(self, name="TreeListerThread")
        self.sink = sink # The object that will recieve files through addFiles()
        self.path = path
        self.root = root
        self.depth = depth
        self.listDirs = listDirs
        self.batch = batchSize
        self.isRunning = False
        self.fileFilter = fileFilter

    def listtree_bfs(self):
        files = []
        dirs = []
        sink = self.sink
        root = self.root
        if root == None: root = self.path
        tocheck = [(self.depth, self.path)]
        fileFilter = self.fileFilter
        if fileFilter == None: fileFilter = CFileFilter()
        while self.isRunning and len(tocheck) > 0:
            depth, path = tocheck[0]
            tocheck = tocheck[1:]
            rpath = os.path.relpath(path, root)
            try: lst = os.listdir(path)
            except: lst = []
            for f in lst:
                if not self.isRunning: break
                pathname = os.path.join(path, f)
                try:
                    fst = os.stat(pathname)
                    mode = fst.st_mode
                except: continue
                if stat.S_ISDIR(mode):
                    if not fileFilter.dirAccepted(f): continue
                    if self.listDirs: dirs.append( (rpath, f) )
                    if depth > 0: tocheck.append( (depth-1, pathname) )
                elif stat.S_ISREG(mode):
                    if not fileFilter.fileAccepted(f): continue
                    files.append( (rpath, f) )
                else: continue
                if len(files) + len(dirs) > self.batch:
                    self.isRunning = sink.addFiles(files, dirs)
                    files = []
                    dirs = []

        if self.isRunning and (len(files) > 0 or len(dirs) > 0):
            sink.addFiles(files, dirs)
        self.isRunning = False

    def run(self):
        self.isRunning = True
        self.listtree_bfs()

    def stop(self):
        self.isRunning = False


class CFileItem(CListItem):
    def __init__(self, owner, path, fname, attrs=""):
        CListItem.__init__(self, fname)
        self.owner = owner
        self.path = path
        self._ftype = 'f'
        self.attrs = attrs
    
    @property
    def displayText(self):
        if self.owner._attributesVisible: return u"%s   %s" % (self.attrs, os.path.join(self.path, self._text))
        return u"  %s" % os.path.join(self.path, self._text)

    @property
    def filterText(self):
        return u"%s" % os.path.join(self.path, self._text)

    @property
    def callbackText(self):
        return u"%s" % os.path.join(self.path, self._text)


class CDirectoryItem(CFileItem):
    def __init__(self, owner, path, fname, attrs=""):
        CFileItem.__init__(self, owner, path, fname, attrs)
        self._ftype = 'd'

    @property
    def displayText(self):
        if self.owner._attributesVisible: return u"%s + %s" % (self.attrs, os.path.join(self.path, self._text))
        return u"+ %s" % os.path.join(self.path, self._text)


class CFileBrowser(CList):
    def __init__(self, *args, **kwds):
        if not kwds.has_key("title"): kwds["title"] = "File browser"
        CList.__init__(self, *args, **kwds)
        self.modifyKeymaps()
        self.currentPath = ""
        self.titleAlign = ">"
        self.minSize = (32, 8)
        self.osencoding = "utf-8" # TODO: get file-system encoding
        self.fileFilter = CFileFilter()
        self.optShowAttrs = True
        self.exprRecentDirList = "g:VXRECENTDIRS"
        self.callbackEditFile = ""
        self.subdirDepth = 0
        self.deepListLimit = 0
        self.__filesAdded = False # files added in addFiles (eg. by CTreeListerThread)
        self.__listerThread = None

    def getTitle(self, maxwidth):
        if self.subdirDepth < 1: return CList.getTitle(self, maxwidth)
        t = "%s [+%d]" % (self.title, self.subdirDepth)
        if len(t) < maxwidth: return t
        if maxwidth > 12:
            maxwidth -= 3
            dots = "..."
        else: dots = ""
        return dots + t[-maxwidth:]

    #@property
    #def _hideFilterMasks(self):
    #    if self._masks_hide == None:
    #        self._masks_hide = []
    #        for mask in self.filterHide.split(","):
    #            mask = mask.replace(".", r"\.").replace("*", ".*").replace("?", ".")
    #            try:
    #                mask = re.compile(mask + "$", re.IGNORECASE)
    #                self._masks_hide.append(mask)
    #            except: pass
    #    return self._masks_hide

    @property
    def _attributesVisible(self):
        return self.optShowAttrs and self.subdirDepth == 0

    #def _isHidden(self, fname):
    #    for mask in self._hideFilterMasks:
    #        mo = mask.match(fname)
    #        if mo != None: return True
    #    return False

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
            fname = f.decode(self.osencoding, "replace")
            if stat.S_ISDIR(mode):
                if not self.fileFilter.dirAccepted(fname): continue
                attrs = "%s %s %s%s" % ("     ", time.strftime("%Y-%m-%d %H:%M", mtime), modR, modW)
                dirs.append([fname, CDirectoryItem(self, "", f, attrs)])
            elif stat.S_ISREG(mode):
                if not self.fileFilter.fileAccepted(fname): continue
                attrs = "%s %s %s%s" % (self.hrsize(fst.st_size), time.strftime("%Y-%m-%d %H:%M", mtime), modR, modW)
                files.append([fname, CFileItem(self, "", f, attrs)])
            else: pass
        return dirs, files

    def onFilterChanged(self, old, new):
        if self.subdirDepth < 1: return
        if self.__listerThread != None: return
        if not self._filter.filterGrown: self.loadDirectory(self.currentPath)
        self.relayout()

    #def listtree_bfs(self, path, root=None, depth=0, listDirs=False):
    #    files = []
    #    if root == None: root = path
    #    tocheck = [(depth, path)]
    #    while len(tocheck) > 0:
    #        depth, path = tocheck[0]
    #        tocheck = tocheck[1:]
    #        for f in os.listdir(path):
    #            pathname = os.path.join(path, f)
    #            try:
    #                fst = os.stat(pathname)
    #                mode = fst.st_mode
    #            except: continue
    #            if self._isHidden(f): continue
    #            fname = os.path.relpath(pathname, root)
    #            fname = fname.decode(self.osencoding, "replace")
    #            if stat.S_ISDIR(mode):
    #                # TODO: configurable: list directories or not
    #                if listDirs:
    #                    good, pos = self._filter.match(fname.lower())
    #                    if good > 0: files.append([fname, CDirectoryItem(self, fname)])
    #                if depth > 0 and len(files) < 5000: # TODO: user configurable limit on # of files
    #                    tocheck.append( (depth-1, pathname) )
    #            elif stat.S_ISREG(mode):
    #                good, pos = self._filter.match(fname.lower())
    #                if good > 0: files.append([fname, CFileItem(self, fname)])
    #            else: pass
    #    return files

    # called by CTreeListerThread
    def addFiles(self, files, dirs):
        readMore = True
        self._pendingItemsLock.acquire()
        try:
            if self._pendingItems == None: self._pendingItems = []
            for path,f in files:
                fname = f.decode(self.osencoding, "replace")
                #good, pos = self._filter.match(fname.lower())
                #if good > 0: self._pendingItems.append( CFileItem(self, fname) )
                self._pendingItems.append( CFileItem(self, path, fname) )
            for path,f in dirs:
                fname = f.decode(self.osencoding, "replace")
                #good, pos = self._filter.match(fname.lower())
                #if good > 0: self._pendingItems.append( CDirectoryItem(self, fname) )
                self._pendingItems.append( CDirectoryItem(self, path, fname) )
            if self.subdirDepth > 0 and self.deepListLimit > 0:
                if len(self._pendingItems) + len(self.allitems) > self.deepListLimit:
                    readMore = False
        finally:
            self._pendingItemsLock.release()
        self.__filesAdded = len(self._pendingItems) > 0

        return readMore

    def mergeItems(self, current, newlist):
        newlist.sort(key=lambda x: x.filterText)
        current += newlist # TODO: merge sorted lists
        return current

    def getExtraPrompt(self, maxwidth=30):
        # TODO: User configurable path replacements, like
        #     "HOME" = "/home/user"; "DOC" = "/home/user/Documents"
        if len(self.currentPath) <= maxwidth: return self.currentPath
        else: return "...%s" % self.currentPath[-(maxwidth-3):]

    def loadDirectory(self, path):
        if self.__listerThread != None:
            self.__listerThread.stop()
            self.__listerThread = None
        path = os.path.abspath(path)
        self.currentPath = path
        self.allitems = [CDirectoryItem(self, "", u"..", " " * 25)]
        self.title = self.currentPath
        if self.subdirDepth < 1:
            dirs, files = self.listdir(path)
            dirs.sort()
            files.sort()
            for fn in dirs: self.allitems.append(fn[1])
            for fn in files: self.allitems.append(fn[1])
        else:
            #   XXX: Old: read all files, then display
            #files = self.listtree_bfs(path, path, self.subdirDepth)
            #files.sort()
            #for fn in files: self.allitems.append(fn[1])
            #   XXX: Experimetal: list files in separate therad
            #   TODO: while the path&depth is the same, __listerThread should be running.
            #   The files read should be cached in memory in raw form (less space),
            #   except the hidden ones which should be skipped.
            #   loadDirectory should only process files from cache.
            #   The files should be converted to display enocding in getDisplayText (how does
            #   this affect filtering?)
            self.__filesAdded = False
            self._pendingItems = None
            self.__listerThread = CTreeListerThread(self, path, path,
                    depth=self.subdirDepth, fileFilter=self.fileFilter)
            self.__listerThread.start()
            while not self.__filesAdded and self.__listerThread.isAlive():
               time.sleep(0.05)
        self.refreshDisplay()

    def onExit(self):
        if self.__listerThread != None: self.__listerThread.stop()

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
                if item.callbackText == curdir:
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
        List = CList(title="Recent directories") # , autosize="VH", align="B")
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
            self.cd(selitem.callbackText)
            if cmd == "dired-filter-select": return "filter-restart"
            return ""
        fn = os.path.join(self.currentPath, selitem.callbackText)
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
        return CList.expandVimCommand(self, command, curindex, extraParamHandlers)

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
        else: return CList.doListCommand(self, cmd, curindex)
        return ""

    def process(self, curindex=0, cwd=None, startmode=CList.MODE_NORMAL):
        # self.subdirDepth = 20 # XXX TESTING
        if cwd == None: cwd = os.getcwd()
        else:
            if not os.path.exists(cwd): cwd = os.getcwd()
            fst = os.stat(cwd)
            if not stat.S_ISDIR(fst.st_mode): cwd = os.getcwd()
        self.loadDirectory(cwd)
        CList.process(self, curindex, startmode=startmode) # TODO: startmode=sth.NORMAL
        self.onExit()

