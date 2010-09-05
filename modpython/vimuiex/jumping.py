#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et:vim
# Author:  Marko Mahnič
# Created: jun 2009 
# (requires a patch for if_python.c)

import vim
import ioutil

class CLineJump:
    def __init__(self):
        self.chars = "abcdefghijklmnoprstuvxyz"
        self.wchar = "w"
        self.stripPos = 0
        self.groupLines = 3

    def prepareChars(self):
        if self.chars.find(self.wchar) >= 0:
            self.chars = self.chars.replace(self.wchar, "")

    def getLabelSize(self, nrows):
        sz = 1
        nrows = (nrows + self.groupLines - 1) / self.groupLines
        N = len(self.chars)
        while nrows > N: nrows /= N; sz += 1
        return sz

    def mkjmp(self, i, labelsize):
        N = len(self.chars)
        if labelsize == 1: return self.chars[i]
        lab = ""
        while labelsize > 0:
            lab = self.chars[i%N] + lab
            i = i / N
            labelsize -= 1
        return lab

    def displayLabels(self):
        self.prepareChars()
        win = vim.current.window
        attr = vim.screen.getHighlightAttr("VxNormal")
        labelsize = self.getLabelSize(win.height)
        x0 = win.left + int ((win.width - labelsize - 2) * self.stripPos * 0.5)
        enc = vim.eval("&encoding")
        herelab = self.groupLines / 2
        for y in range(win.height):
            if y % self.groupLines == herelab:
                ilab = y / self.groupLines
                lab = u" %s " % self.mkjmp(ilab, labelsize)
            else: lab = u" %s " % (" " * labelsize)
            vim.screen.puts(win.top+y, x0, attr, lab.encode(enc, "replace"))
        return labelsize

    def process(self):
        ioutil.CheckColorScheme()
        nch = self.displayLabels()
        line = 0
        enc = vim.eval("&encoding")
        while nch > 0:
            ch = ioutil.CScreen().getkey()
            ch = ch.decode(enc, "replace")
            if ch == self.wchar:
                self.stripPos = (self.stripPos + 1) % 3
                vim.command("redraw!")
                self.displayLabels()
            elif self.chars.find(ch) >= 0:
                line = line * len(self.chars) + self.chars.find(ch)
                nch -= 1
            else:
                line = -1
                break
        if line >= 0:
            line = line * self.groupLines + self.groupLines / 2
            if line > vim.current.window.height: line = vim.current.window.height
            if line < 0: line = 0
            cy, cx = vim.current.window.wcursor
            dy = line - cy
            if dy > 0: vim.command("norm %s" % ("gj" * dy))
            elif dy < 0: vim.command("norm %s" % ("gk" * -dy))
            
        vim.command("redraw!")

class CWindowJump:
    def __init__(self):
        self.chars = "abcdefghijklmnoprstuvxyz"
        self.wchar = "w"
        self.stripPos = 1

    def prepareChars(self):
        if self.chars.find(self.wchar) >= 0:
            self.chars = self.chars.replace(self.wchar, "")

    def getLabelSize(self, nwins):
        sz = 1
        N = len(self.chars)
        while nwins > N: nwins /= N; sz += 1
        return sz

    def mkjmp(self, i, labelsize):
        N = len(self.chars)
        if labelsize == 1: return self.chars[i]
        lab = ""
        while labelsize > 0:
            lab = self.chars[i%N] + lab
            i = i / N
            labelsize -= 1
        return lab

    def displayLabels(self):
        self.prepareChars()
        attr = vim.screen.getHighlightAttr("VxNormal")
        labelsize = self.getLabelSize(len(vim.windows))
        enc = vim.eval("&encoding")
        for i, win in enumerate(vim.windows):
            x0 = win.left + int ((win.width - labelsize - 2) * self.stripPos * 0.5)
            y0 = win.top + int ((win.height - labelsize - 2) * self.stripPos * 0.5)
            lab = u" %s " % self.mkjmp(i, labelsize)
            vim.screen.puts(y0, x0, attr, lab.encode(enc, "replace"))
        return labelsize

    def process(self):
        ioutil.CheckColorScheme()
        nch = self.displayLabels()
        iwin = 0
        enc = vim.eval("&encoding")
        while nch > 0:
            ch = ioutil.CScreen().getkey()
            ch = ch.decode(enc, "replace")
            if ch == self.wchar:
                self.stripPos = (self.stripPos + 1) % 3
                vim.command("redraw!")
                self.displayLabels()
            elif self.chars.find(ch) >= 0:
                iwin = iwin * len(self.chars) + self.chars.find(ch)
                nch -= 1
            else:
                iwin = -1
                break
        if iwin >= 0:
            if iwin >= len(vim.windows):
                iwin = len(vim.windows)
            vim.command("exe \"%dwincmd w\"" % (iwin + 1))
            
        vim.command("redraw!")
