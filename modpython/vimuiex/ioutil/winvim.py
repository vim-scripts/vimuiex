#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et
# Author:  Marko Mahnič
# Created: jun 2009

import vim
screen = vim.screen

LINECHARS = {
    "ascii":   u"-|++++",
    "single":  u"─│┌┐└┘",
    "double":  u"═║╔╗╚╝",
    "mixed1":  u"─║╓╖╙╜",
    "mixed2":  u"═│╒╕╘╛"
}

class CWindow(object):
    def __init__(self, height, width, y, x):
        self.height = height
        self.width = width
        self.y = y
        self.x = x
        self.attr = 0
        self.lasty = 0
        enc = vim.eval("&encoding") # enc = "utf-8"
        try:
            uchars = LINECHARS["double"]
            chars = uchars.encode(enc) # check if encoding works; exception if not
            self.linechars = [ ch.encode(enc) for ch in uchars ]
        except:
            self.linechars = [ ch.encode("ascii") for ch in LINECHARS["ascii"] ]

    def bkgd(self, char, attr):
        line = char[0] * self.width
        for i in xrange(self.height):
            screen.puts(i + self.y, self.x, attr, line)
        self.lasty = self.height

    def attrset(self, attr):
        self.attr = attr

    def border(self):
        if self.width < 2 or self.height < 2: return
        line = self.linechars[2] + self.linechars[0] * (self.width - 2) + self.linechars[3]
        self.addstr(0, 0, line)
        line = self.linechars[4] + self.linechars[0] * (self.width - 2) + self.linechars[5]
        self.addstr(self.height-1, 0, line)
        self.vline(1, 0, self.linechars[1],  self.height-2)
        self.vline(1, self.width-1, self.linechars[1], self.height-2)
        pass

    # used only before drawing items so that clrtobot works ok
    def move(self, y, x):
        self.lasty = y - 1 # FIXME: = y when clrtobot will be ok (will consider x)

    def hline(self, y, x, char, length):
        if length < 1: return
        line = char * length
        self.addstr(y, x, line)
        self.lasty = y
        pass

    def vline(self, y, x, char, length):
        for ll in xrange (y, y+length):
            self.addstr(ll, x, char)
        pass

    def redrawwin(self):
        pass

    def redrawln(self, y, unknown_todo):
        pass

    def refresh(self):
        pass

    def scrollok(self, flag):
        pass

    def clear(self):
        pass

    def clrtobot(self):
        if self.lasty+1 < self.height:
            line = " " * self.width
            for y in xrange(self.lasty+1, self.height):
                self.addstr(y, 0, line)
        pass

    def derwin(self, height, width, y, x):
        return CWindow(height, width, self.y + y, self.x + x)

    def addstr(self, y, x, line, attr=None):
        if attr == None: attr = self.attr
        screen.puts(y + self.y, x + self.x, attr, line)
        self.lasty = y

    def insstr(self, y, x, line, attr=None):
        self.addstr(y, x, line, attr)

    def enclose(self, y, x):
        return y >= self.y and y < self.y + self.width and x >= self.x and x < self.x + self.height

class CScreen(object):
    def __init__(self):
        self.lastClick = (0, 0)
    def refresh(self): pass
    def clear(self): pass
    def showPrompt(self, prompt):
        yPrompt = int(vim.eval("&lines")) - 1
        screen.puts(yPrompt, 0, 0, prompt)

    def getkey(self, prompt=None):
        if prompt != None: self.showPrompt(prompt)
        key = vim.eval("getchar()")
        try:
            key = int(key)
            if key >= 0 and key < 256: key = chr(key)
            elif key > 255:
                key = u"%c" % key
                key = key.encode("utf-8")
        except:
            key = "" 
        # TODO: Capture mouse position
        # Useless... v:mouse_lnum contains text line number, not screen line number
        # ( variables added with pathch 7.0.155, eval.c, vim.h )
        # print vim.eval('v:mouse_win . " " . v:mouse_lnum . " " . v:mouse_col')
        # self.lastclick = (screen.mousex - self.left, screen.mousey - self.top)
        # print self.lastclick
        return key


