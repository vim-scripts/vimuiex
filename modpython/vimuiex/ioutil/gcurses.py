# Global curses intialization

import curses
import vim
import locale

locale.setlocale(locale.LC_ALL, 'C')
code = locale.getpreferredencoding()

# The one and only curses screen
STDSCR = None

# Prepares the screen and returns the global screen variable
def vimPrepareScreen():
    global STDSCR
    if STDSCR == None:
        STDSCR = curses.initscr()
        if curses.has_colors():
            curses.start_color()
        curses.def_prog_mode()
        curses.mousemask(curses.ALL_MOUSE_EVENTS)
        STDSCR.redrawwin()
        STDSCR.refresh()
        vim.command("redraw!")
    curses.noecho()   # don't echo keypresses
    curses.cbreak()   # no need to press Return after each char
    STDSCR.keypad(1)  # translate multibyte keypresses
    return STDSCR

