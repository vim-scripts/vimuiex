# vim: set fileencoding=utf-8 sw=4 ts=8 et :
# simplekeymap.py - A simplistic keymap implementation
#
# Author: Marko Mahnič
# Created: April 2009
# License: GPL (http://www.gnu.org/copyleft/gpl.html)
# This program comes with ABSOLUTELY NO WARRANTY.

import re
import vim

KM_NOTFOUND = 0
KM_PREFIX = 1
KM_MATCH = 2

def rewriteKey(keyseq):
    return vim.eval('"%s"' % keyseq)
    # old code
    parts = keyseq.split(r"\\")
    newparts = []
    def replUpper(match):
        key = match.group(1).upper()
        return "\xff%s" % key
    for p in parts:
        newparts.append(re.sub(r"\\(<[a-zA-Z0-9-]+>)", replUpper, p))
    return "\\".join(newparts)

## a read-only dictionary
#class CKeyCode:
#    def __init__(self):
#        self.keys = {}
#    def __getitem__(self, key):
#        # TODO: do some preprocessing on the key (eg. <C-A> --> \x01)
#        if not self.keys.has_key(key):
#            self.keys[key] = rewriteKey(r"\<%s>" % key.upper())
#        return self.keys[key]

#KEYCODE = CKeyCode()

class CSimpleKeymap:
    def __init__(self, name="Keymap"):
        self.name = name
        self._keys = {}
        self._keydefs = {}

    def findKey(self, keyseq):
        for seq in self._keys.iterkeys():
            if keyseq == seq: return (KM_MATCH, self._keys[keyseq])
        for seq in self._keys.iterkeys():
            if seq.startswith(keyseq): return (KM_PREFIX, None)
        return (KM_NOTFOUND, None)

    def setKey(self, vimKeyExpr, command):
        keyseq = rewriteKey(vimKeyExpr)
        for seq in self._keys.iterkeys():
            if seq == keyseq: continue # replacing a command
            elif seq.startswith(keyseq):
                print "Warning: key '%s' is a prefix of key '%s'" (keyseq, seq)
            elif keyseq.startswith(seq):
                print "Warning: key '%s' is a prefix of key '%s'" (seq, keyseq)
        self._keys[keyseq] = command

        def fmtKey(match):
            key = match.group(1).lower()
            return "%s" % key
        vimKeyExpr = re.sub(r"\\(<[a-zA-Z0-9-]+>)", fmtKey, vimKeyExpr)

        self._keydefs[keyseq] = vimKeyExpr

    def clearKey(self, vimKeyExpr):
        keyseq = rewriteKey(vimKeyExpr)
        self._keys.pop(keyseq, None)
        self._keydefs.pop(keyseq, None)

    # Clear all keys with prefix keyseq
    def clearKeyPrefix(self, vimKeyExpr):
        keyseq = rewriteKey(vimKeyExpr)
        for k in self._keys.iterkeys():
            if k.startswith(keyseq):
                self._keys.pop(keyseq, None)
                self._keydefs.pop(keyseq, None)

    def clearAllKeys(self):
        self._keys = {}
        self._keydefs = {}

    # returns: list[ (keyname, command), ... ]
    def getMappedKeys(self):
        keys = []
        for k,v in self._keydefs.items():
            if not self._keys.has_key(k): keys.append( (v, '????') )
            else: keys.append( (v, self._keys[k]) )
        return keys

if __name__ == "__main__":
    keyseq = r"g\<CR>\<Esc>\\f"
    print keyseq, "-->", rewriteKey(keyseq)
