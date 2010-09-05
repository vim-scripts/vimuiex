#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et:vim
# Author:  Marko Mahnič
# Created: jun 2009 

import vim

PLATFORM = None
def __detectPlatform():
    try:
        if vim.screen != None: return "vim.screen"
    except Exception as e:
        print "Exception: %s" % e
    hasgui = int(vim.eval('has("gui_running")'))
    if hasgui != 0:
        try: # Deprecated: wx platform will be dropped!
            import wx
            return "wx"
        except Exception as e:
            print "Exception: %s" % e
    else:
        try:
            import curses
            import gcurses
            gcurses.vimPrepareScreen()
            return "curses"
        except Exception as e:
            print "Exception: %s" % e
    print "ioutil: Platform detection failed"
    return None

PLATFORM = __detectPlatform()

def CScreen():
    global PLATFORM
    if PLATFORM == "vim.screen":
        import winvim
        return winvim.CScreen()
    elif PLATFORM == "curses":
        import wincurses
        return wincurses.CScreen()
    return None

def CWindow(height, width, y, x):
    global PLATFORM
    if PLATFORM == "vim.screen":
        import winvim
        return winvim.CWindow(height, width, y, x)
    elif PLATFORM == "curses":
        import wincurses
        return wincurses.CWindow(height, width, y, x)
    return None

colorSchemeChecked = "--"
def CheckColorScheme():
    global colorSchemeChecked
    try: cs = vim.eval("exists('g:colors_name') ? g:colors_name : ('*bg*' . &background)")
    except vim.error: cs="--"
    if cs != colorSchemeChecked:
        try: vim.eval("vimuiex#vxlist#CheckHilightItems()")
        except vim.error: pass
        colorSchemeChecked = cs

