#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et:vim

import vim
import string, re, copy

def str2num(x):
    if x == "": return None
    elif x.find('.') >= 0: x = float(x)
    else: x = int(x)
    return x

def vimecho(val, echoType="m"):
    vim.command("echo%s '%s'" % (echoType, val))

class CColRow:
    def __init__(self, x=0, y=0):
        if type(x) == type(""): x = str2num(x)
        if type(y) == type(""): y = str2num(y)
        self.x=x
        self.y=y

    def getAbs(self, fullSize=None):
        if fullSize == None: fullSize = vimMaxSize()
        sz = CColRow(self.x, self.y)
        if type(self.x) is float: sz.x = int(fullSize.x * self.x + 0.5)
        if type(self.y) is float: sz.y = int(fullSize.y * self.y + 0.5)
        return sz

    def __str__(self):
        return "(%s,%s)" % (self.x, self.y)

BORDER=None
def setBorder(x, y):
    global BORDER
    BORDER=CColRow(x, y)

def vimScreenSize():
    return CColRow(int(vim.eval("&columns")), int(vim.eval("&lines")))

def vimMaxSize():
    global BORDER
    sz = vimScreenSize()
    sz.x -= BORDER.x
    sz.y -= BORDER.y
    return sz

def vimTopLeft():
    global BORDER
    return CColRow(BORDER.x / 2, BORDER.y / 2)

def vimBottomRight():
    global BORDER
    sz = vimScreenSize()
    sz.x -= BORDER.x / 2
    sz.y -= BORDER.y / 2
    return sz

def vimMaxRect():
    global BORDER
    tl = vimTopLeft()
    br = vimBottomRight()
    return [tl.x, tl.y, br.x, br.y]

# The absolutely minimal size for the window: 2 lines + border
def absMinSize():
    return CColRow(12, 4)

#class IOwner:
#    def __init__(self):
#        self.size = CColRow(32, 16)
#        self.position = CColRow(1, 1)
#    def getMaxWidth(): pass
#    def getMaxHeight(): pass

class CSettingParser:
    def __init__(self, settingDef):
        # xy - location, F - flags, f - flag, b - bool
        self.reSetting = re.compile("^([a-z]+)([-+])?=(.*)$")
        self.reLoc = re.compile("^([0-9.]*),([0-9.]*)$")
        self.settingDef = settingDef # TODO: validate settingDef
        pass

    def _isValidSetting(self, sname):
        for sd in self.settingDef:
            for sn in sd[0]:
                if sn == sname: return True
        return False

    def _getSettingName(self, sname):
        for sd in self.settingDef:
            for sn in sd[0]:
                if sn == sname: return sd[0][0]
        return None

    def _getSettingInfo(self, sname):
        for sd in self.settingDef:
            for sn in sd[0]:
                if sn == sname: return sd
        return None

    def parseSettings(self, settings):
        values = {}
        setlist = settings.split()
        for s in setlist:
            mo = self.reSetting.match(s)
            if mo == None: continue
            sname = mo.group(1)
            # if not _isValidSetting(sname): continue
            # sname = self._getSettingName(sname)
            sett = self._getSettingInfo(sname)
            if sett == None: continue
            sname = sett[0][0]
            stype = sett[1]
            # vimecho("%s:%s" % (sname, stype))
            op = mo.group(2)
            sval = mo.group(3)
            if stype == "xy":
                mo = self.reLoc.match(sval)
                if mo == None: continue
                values[sname] = CColRow(mo.group(1), mo.group(2))
            elif stype == 'f':
                values[sname] = sval[:1]
            elif stype == 'b':
                if sval == '1' or sval == 'y' or sval == 't': values[sname] = True
                else: values[sname] = False
            elif stype == 'F':
                # if op == "+": values[sname] += sval; cleanup(values[sname])
                # elif op == "-": values[sname] -= sval; cleanup(values[sname])
                # else: values[sname] = cleanup(sval)
                values[sname] = sval
            # vimecho("%s=%s" % (sname, values[sname]))
        return values

# Resize and reposition a box based on positioning rules.
# Save and restore positioning rules (viminfo).
class CBoxPositioner:
    def __init__(self, owner):
        self.owner = owner
        self.optPoint = None # Point on screen; default: center
        self.optAlign = None # Point on box; default: center
        self.autosize = CColRow(True, True)
        self.optMinSize = None # CColRow(16, 4)
        self.optMaxSize = None # vimMaxSize
        self.optDefaultSize = CColRow(0.7, 0.7) # when owner.size is none
        self._clearSizes()

    def _clearSizes(self):
        self._minSize = None
        self._maxSize = None
        self._defaultSize = None

    # Nxy, eg. 311=left-top, 332=right-middle
    # x=[lcr], y=[tmb], converted to 3xy
    def _parsePointDef(self, pointDef, defaultPoint=None):
        if defaultPoint == None: x = 0.5; y = 0.5
        else: x = defaultPoint.x; y = defaultPoint.y
        if pointDef != None and pointDef != "":
            mo = re.match(r"\d\d\d", pointDef)
            if mo != None:
                N = int(pointDef[0])-1
                if N <= 0: x = 0.0; y = 0.0
                else:
                    x = max(int(pointDef[1])-1, 0)
                    y = max(int(pointDef[2])-1, 0)
                    x = min(1.0 * x / N, 1.0)
                    y = min(1.0 * y / N, 1.0)
            else:
                pointDef = pointDef.lower()
                validx = ['l', 'h', 'r', 'c']; coorx = [0.0, 0.5, 1.0, 0.5]
                validy = ['t', 'v', 'b', 'c']; coory = [0.0, 0.5, 1.0, 0.5]
                for i,c in enumerate(validx):
                    if pointDef.find(c) >= 0: x = coorx[i]
                for i,c in enumerate(validy):
                    if pointDef.find(c) >= 0: y = coory[i]
        return CColRow(x, y)

    def parseOptions(self, options):
        settingDef = [
            (["size"], "xy"),
            (["minsize", "mins"], "xy"),
            (["maxsize", "maxs"], "xy"),
            (["position", "pos"], "F"),
            (["align", "al"], "F"),
            (["autosize", "as"], "F"),
            (["firstcolumn", "fc"], "b"),
            (["startupmode", "stm"], "f"),
        ]
        p = CSettingParser(settingDef)
        vals = p.parseSettings(options)
        if vals.has_key("minsize"): self.optMinSize = vals["minsize"]
        if vals.has_key("maxsize"): self.optMaxSize = vals["maxsize"]
        if vals.has_key("position"): self.setScreenPoint(vals["position"])
        if vals.has_key("align"): self.setBoxPoint(vals["align"])
        if vals.has_key("autosize"): self.setAutoSize(vals["autosize"])

    # The point on screen to align to
    def setScreenPoint(self, pointDef):
        self.optPoint = self._parsePointDef(pointDef, self.optPoint)

    # The point on box which should be placed on the screen point
    def setBoxPoint(self, pointDef):
        self.optAlign = self._parsePointDef(pointDef, self.optAlign)

    def setAutoSize(self, autosizeDef):
        if autosizeDef == None: return
        autosize = autosizeDef.lower()
        self.autosize.x = autosize.find("v") >= 0
        self.autosize.y = autosize.find("h") >= 0

    @property
    def minSize(self):
        if self._minSize == None:
            if self.optMinSize == None: sz = CColRow(16, 4)
            else: sz = self.optMinSize.getAbs()
            am = absMinSize()
            if sz.x < am.x: sz.x = am.x
            if sz.y < am.y: sz.y = am.y
            am = self.maxSize
            if sz.x > am.x: sz.x = am.x
            if sz.y > am.y: sz.y = am.y
            self._minSize = sz
        return self._minSize

    @property
    def maxSize(self):
        if self._maxSize == None:
            if self.optMaxSize == None: sz = vimMaxSize()
            else: sz = self.optMaxSize.getAbs()
            am = absMinSize()
            if sz.x < am.x: sz.x = am.x
            if sz.y < am.y: sz.y = am.y
            am = vimMaxSize()
            if sz.x > am.x: sz.x = am.x
            if sz.y > am.y: sz.y = am.y
            self._maxSize = sz
        return self._maxSize

    @property
    def defaultSize(self):
        if self._defaultSize == None:
            self._defaultSize = self.optDefaultSize.getAbs()
        return self._defaultSize

    def _limitSize(self, sz):
        ms = self.minSize
        if sz.x < ms.x: sz.x = ms.x
        if sz.y < ms.y: sz.y = ms.y
        ms = self.maxSize
        if sz.x > ms.x: sz.x = ms.x
        if sz.y > ms.y: sz.y = ms.y
        return sz

    def _limitPosition(self, pos, size):
        pos = copy.copy(pos)
        szmax = vimMaxSize()
        tl = vimTopLeft()
        br = vimBottomRight()
        if pos.x < tl.x: pos.x = tl.x
        if pos.y < tl.y: pos.y = tl.y
        if pos.x - tl.x + size.x > br.x: pos.x = br.x - size.x
        if pos.y - tl.y + size.y > br.y: pos.y = br.y - size.y
        return pos

    def calcSize(self, curSize):
        if curSize != None: sz = copy.copy(curSize)
        else: sz = self.defaultSize

        self._clearSizes()
        if self.autosize.x: sz.x = max(0, self.owner.getMaxWidth())
        if self.autosize.y: sz.y = max(0, self.owner.getMaxHeight())
        return self._limitSize(sz)

    def calcPosition(self, curPos, curSize):
        if curPos != None: pos = copy.copy(curPos)
        else: pos = vimTopLeft()
        if curSize != None: sz = copy.copy(curSize)
        else: sz = self.defaultSize.getAbs()
        point = self.optPoint; align = self.optAlign
        if point == None and align == None: point = CColRow(0.5, 0.5)
        if align == None: align = point
        if point == None: point = align
        tl = vimTopLeft()
        pos = point.getAbs()
        offs = align.getAbs(fullSize = curSize)
        pos.x += (tl.x - offs.x)
        pos.y += (tl.y - offs.y)
        return self._limitPosition(pos, curSize)

    def relayout(self):
        size = self.calcSize(self.owner.size)
        pos = self.calcPosition(self.owner.position, size)
        # vimecho('pos%s size%s max%s' % (pos, size, vimMaxSize()))
        self.owner.size = size
        self.owner.position = pos

    def reposition(self, pointDef):
        self.point = self._parsePointDef(pointDef, self.point)
        pos = self.calcPosition(self.owner.position, self.owner.size)
        self.owner.position = pos

