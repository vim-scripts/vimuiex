#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et:vim
# Author:  Marko Mahnič
# Created: jun 2009 
import vim
import curses
import gcurses
stdscr = gcurses.vimPrepareScreen()

class CWindow(object):
    def __init__(self, height, width, y, x):
        if y != None and x != None:
            self.__win = curses.newwin(height, width, y, x)
        else:
            self.__win = None
        self.linechars = [curses.ACS_HLINE, curses.ACS_VLINE]
        pass

    def __getattr__(self, name):
        fn = getattr(self.__win, name)
        return fn

    def derwin(self, height, width, y, x):
        win = CWindow(None, None, None, None)
        win.__win = self.__win.derwin(height, width, y, x)
        return win

class CScreen(object):
    def __init__(self):
        self.lastClick = (0, 0)
    def refresh(self):
        stdscr.refresh()
    def clear(self):
        stdscr.clear()
    def showPrompt(self, prompt):
        yPrompt = int(vim.eval("&lines")) - 1
        stdscr.addstr(yPrompt, 0, prompt)
        stdscr.refresh()

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
