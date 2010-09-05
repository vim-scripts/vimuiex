#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et:vim
#
# Author: Marko Mahnič
# Created: May 2010
# License: GPL (http://www.gnu.org/copyleft/gpl.html)
# This program comes with ABSOLUTELY NO WARRANTY.

import popuplist

stdcmds = [
    "next", "prev", "nextpage", "prevpage", "home", "end",
    "lshift", "rshift", "togglemarked",
    "filter", "quickchar", "numselect",
    "accept", "quit"]
def cmdOrder(cmd):
    global stdcmds
    if cmd in stdcmds: return "a%02d" % stdcmds.index(cmd)
    elif cmd.startswith("list:"): return "l" + cmd
    elif cmd.startswith("vim:") or cmd.startswith("winpos:"): return "z" + cmd
    else: return "b" + cmd

def keyOrder(key):
    return key.upper().replace("<", "\xff")

class CHelpDisplay(popuplist.CList):
    def __init__(self, *args, **kwds):
        if not kwds.has_key("title"): kwds["title"] = "Help"
        popuplist.CList.__init__(self, *args, **kwds)
        self.keymaps = []

    def setKeymaps(self, keymapList):
        self.keymaps = keymapList
        for kn in [self.keymapNorm, self.keymapFilter, self.keymapQuickChar, self.keymapNumSelect]:
            kn.clearKey(r"\<F1>")

    # returns: list[ tuple(list[key, ...], string), ... ]
    def _mergeKeys(self, keymap):
        keydefs = []
        lastcmd = ""
        cmdkeys = []
        keys = keymap.getMappedKeys()
        keys.sort(key=lambda x: cmdOrder(x[1]))
        for km in keys:
            if lastcmd == km[1]: cmdkeys.append(km[0])
            else:
                if lastcmd != "":
                    cmdkeys.sort(key=lambda x: keyOrder(x))
                    keydefs.append( (cmdkeys, lastcmd) )
                lastcmd = km[1]
                cmdkeys = [ km[0] ]
        if lastcmd != "":
            cmdkeys.sort(key=lambda x: keyOrder(x))
            keydefs.append( (cmdkeys, lastcmd) )
        return keydefs

    def makeContent(self):
        self.allitems = []
        for km in self.keymaps:
            self.allitems.append(popuplist.CListItem("Mode: " + km.name))
            keys = self._mergeKeys(km)
            for k in keys:
                ktext = ", ".join(k[0]).replace("\t", r"\t")
                kdescr = k[1]
                txt = " %-19s\t%s" % (ktext, kdescr)
                self.allitems.append(popuplist.CListItem(txt))
        self.setTitleItems(r"^\s+", 0)
        self.hasTitles = True
        self.maxColumnWidth = 0.2
        self._firstColumnAlign = True

    def process(self):
        self.makeContent()
        popuplist.CList.process(self)
