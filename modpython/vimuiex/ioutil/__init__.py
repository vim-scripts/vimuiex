#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et:vim
# Author:  Marko Mahnič
# Created: jun 2009 

PLATFORM = None
def __detectPlatform():
    try:
        import vim
        if vim.screen != None: return "vim.screen"
    except: pass
    hasgui = int(vim.eval('has("gui_running")'))
    if hasgui != 0:
        try: # Deprecated: wx platform will be dropped!
            import wx
            return "wx"
        except: pass
    else:
        try:
            import curses
            import gcurses
            gcurses.vimPrepareScreen()
            return "curses"
        except: pass
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
