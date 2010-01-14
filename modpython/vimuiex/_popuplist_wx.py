# vim: set fileencoding=utf-8 sw=4 ts=8 et :
# _popuplist_wx.py - a popup listbox implementation for vim-gui (wxWidgets)
#
# Author: Marko Mahnič
# Created: April 2009
# License: GPL (http://www.gnu.org/copyleft/gpl.html)
# This program comes with ABSOLUTELY NO WARRANTY.
#
# (loaded by popuplist.py)

import wx
import time
import re
import vim
import ioutil.gwx
import simplekeymap
# import platform

def log(msg):
    f = open ("testlog.txt", "a")
    f.write(msg + "\n")
    f.close()

def vimCharSize():
    # w, h = int(vim.eval("&columns")), int(vim.eval("&lines"))
    # TODO: Calculate vim cell size
    # Could calculate from window size, but don't have vim.eval("&guiwidth"), vim.eval("&guiheight")
    return (8, 16) # FIXME: guessed

def vimWindowPos():
    return (int(vim.eval("getwinposx()")), int(vim.eval("getwinposy()")))

class MyFrame(wx.Frame):
    def __init__(self, parent, id, title, position=wx.DefaultPosition, size=(550, 350)):
        wx.Frame.__init__(self, parent, id, title, position, size)
        self.itemlist = None

        panel = wx.Panel(self, -1)
        self.listbox = wx.ListBox(panel)
        # self.font = wx.Font(9, wx.FONTFAMILY_DEFAULT, wx.FONTSTYLE_NORMAL, wx.FONTWEIGHT_NORMAL)
        # self.listbox.SetFont(self.font)
        plat = wx.PlatformInformation()
        if plat.GetPortId() == wx.PORT_MSW:
            self.listbox.SetWindowStyleFlag(wx.WANTS_CHARS)
        self.text = wx.TextCtrl(panel)
        szpanel = wx.BoxSizer(wx.VERTICAL)
        szpanel.Add(self.listbox, 7, wx.EXPAND | wx.LEFT | wx.TOP | wx.RIGHT, 4)
        horz = wx.BoxSizer(wx.HORIZONTAL)
        horz.Add(self.text, 7, wx.EXPAND | wx.LEFT | wx.TOP | wx.RIGHT | wx.BOTTOM, 4)
        szpanel.Add(horz)
        panel.SetSizer(szpanel)

        szdlg = wx.BoxSizer(wx.VERTICAL)
        szdlg.Add(panel, 1, wx.EXPAND)

        self.SetSizer(szdlg)
        self.listbox.SetFocus()
        szdlg.Layout()
        
        self.listbox.Bind(wx.EVT_KEY_DOWN, self.OnLbKeyDown)
        self.listbox.Bind(wx.EVT_CHAR, self.OnLbChar)
        self.listbox.Bind(wx.EVT_LEFT_DOWN, self.OnLbButtonDown)
        self.listbox.Bind(wx.EVT_MIDDLE_DOWN, self.OnLbButtonDown)
        self.listbox.Bind(wx.EVT_RIGHT_DOWN, self.OnLbButtonDown)
        self.listbox.Bind(wx.EVT_SIZE, self.OnLbSize)
        self.text.Bind(wx.EVT_KEY_DOWN, self.OnTxtKeyDown)
        self.text.Bind(wx.EVT_TEXT, self.OnTxtChange)

        self.pageSize = 10
        self.keyseq = ""

    def setItemList(self, list, curindex=0):
        self.itemlist = list
        self.syncListbox()
        if curindex < 0: curindex = 0
        if self.text.GetValue() != self.itemlist.strFilter:
            self.text.SetValue(self.itemlist.strFilter)
        self.setCurIndex(curindex)

    def syncListbox(self):
        LB = self.listbox
        while LB.GetCount() > 0: LB.Delete(0)
        for i in self.itemlist.items: LB.Append(i.displayText)

    def setCurIndex(self, index):
        if index < 0: index = -1
        LB = self.listbox
        if index >= LB.GetCount(): index = LB.GetCount() - 1
        LB.SetSelection(index)
        
    def offsetCurIndex(self, offs):
        index = self.listbox.GetSelection() + offs
        if index < 0: index = 0
        self.setCurIndex(index)

    @property
    def itemCount(self):
        return self.listbox.itemCount

    @property
    def curindex(self):
        i = self.listbox.GetSelection()
        return i

    def doCommand(self, cmd):
        cmd = self.itemlist.doCommand(cmd, self.curindex)
        if cmd == "" or cmd == None: return
        elif cmd == "next": self.offsetCurIndex(1)
        elif cmd == "prev": self.offsetCurIndex(-1)
        # elif cmd == "lshift": self.offsetDisplay(-1)
        # elif cmd == "rshift": self.offsetDisplay(1)
        elif cmd == "nextpage": self.offsetCurIndex(self.pageSize)
        elif cmd == "prevpage": self.offsetCurIndex(-self.pageSize)
        elif cmd == "home": self.setCurIndex(0)
        elif cmd == "end": self.setCurIndex(self.itemCount - 1)
        elif cmd == "quit":
            vimcmd = self.itemlist.cmdCancel
            if vimcmd != None and vimcmd != "": vim.command(vimcmd)
            self.Close()
        elif cmd == "accept":
            vimcmd = self.itemlist.cmdAccept
            if vimcmd != None and vimcmd != "":
                vimcmd = self.itemlist.expandVimCommand(vimcmd, self.curindex)
                vim.command(vimcmd)
            self.Close()
        elif cmd == "filter":
            self.text.SetFocus()
        elif cmd == "filter-accept":
            self.listbox.SetFocus()
        elif cmd == "filter-cancel":
            self.text.SetValue("")
            self.listbox.SetFocus()
        elif cmd == "filter-delete":
            # Handled in OnTxtKeyDown
            pass

    def _processkey(self, keymap, key):
        self.keyseq += key
        (res, cmd) = keymap.findKey(self.keyseq)
        if res == simplekeymap.KM_PREFIX: return # TODO: display prefix
        elif res == simplekeymap.KM_MATCH: self.doCommand(cmd)
        self.keyseq = ""

    def _previewCommand(self,keymap, key):
        keyseq = self.keyseq + key
        (res, cmd) = keymap.findKey(keyseq)
        if res == simplekeymap.KM_PREFIX: return None
        elif res == simplekeymap.KM_MATCH: return cmd
        return None

    def _wx2simple(self, keycode):
        key = None
        if keycode == wx.WXK_ESCAPE: key = simplekeymap.KEYCODE["ESC"]
        elif keycode == wx.WXK_RETURN: key = simplekeymap.KEYCODE["CR"]
        elif keycode == wx.WXK_BACK: key = simplekeymap.KEYCODE["BS"]
        elif keycode == wx.WXK_DELETE: key = simplekeymap.KEYCODE["BS"]
        elif keycode == wx.WXK_UP: key = simplekeymap.KEYCODE["up"]
        elif keycode == wx.WXK_DOWN: key = simplekeymap.KEYCODE["down"]
        elif keycode == wx.WXK_LEFT: key = simplekeymap.KEYCODE["left"]
        elif keycode == wx.WXK_RIGHT: key = simplekeymap.KEYCODE["right"]
        elif keycode == wx.WXK_PRIOR: key = simplekeymap.KEYCODE["pgup"]
        elif keycode == wx.WXK_NEXT: key = simplekeymap.KEYCODE["pgdown"]
        return key

    def OnLbSize(self, event):
        sz = event.GetSize()
        (w, h) = self.listbox.GetTextExtent("AN EXAMPLE ITEM")
        if h > 0: self.pageSize = int(sz.height / h * 12 / 19) # FIXME: 12/19 is a guess

    def OnLbChar(self, event):
        c = event.GetKeyCode()
        if c < 32 or c > 126:
            event.Skip()
            return
        km = self.itemlist.keymapNorm
        key = chr(c)
        self._processkey(km, key)

    def OnLbKeyDown(self, event):
        key = self._wx2simple(event.KeyCode)
        if key == None:
            event.Skip()
            return
        km = self.itemlist.keymapNorm
        self._processkey(km, key)

    def OnLbButtonDown(self, event):
        event.Skip()
        keycode = None
        if event.LeftDown(): keycode = "LeftMouse"
        elif event.RightDown(): keycode = "RightMouse"
        elif event.MiddleDown(): keycode = "MiddleMouse"
        if keycode != None:
            mod = ""
            if event.ShiftDown(): mod += "S-"
            if event.ControlDown(): mod += "C-"
            if event.AltDown(): mod += "A-"
            keycode = simplekeymap.KEYCODE[mod + keycode]
            wx.CallAfter(self.AfterLbButtonDown, keycode)

    def AfterLbButtonDown(self, keycode):
        # log ("%s" % keycode)
        km = self.itemlist.keymapNorm
        self._processkey(km, keycode)

    def OnTxtKeyDown(self, event):
        key = self._wx2simple(event.KeyCode)
        if key == None:
            event.Skip()
            return
        km = self.itemlist.keymapFilter
        cmd = self._previewCommand(km, key)
        if cmd == "filter-delete":
            txt = self.text.GetValue()
            if len(txt) < 1: self.listbox.SetFocus()
            event.Skip()
            wx.CallAfter(self.doCommand, "filter-delete")
        else: self._processkey(km, key)

    def OnTxtChange(self, event):
        cursel = self.listbox.GetSelection()
        self.itemlist.setFilter(self.text.GetValue())
        self.syncListbox()
        self.setCurIndex(cursel)

    def OnClose(self, event):
        self.Close()

class CPopupListbox:
    def __init__(self, position, size):
        self.itemlist = None
        self.left = position.x
        self.top = position.y
        self.width = size.x
        self.height = size.y
        self.title = ""
        self.curindex = 0
        self.__frame = None

    @property
    def itemCount(self):
        if self.itemlist == None or self.itemlist.items == None: return 0
        return len(self.itemlist.items)

    def setItemList(self, clist):
        self.itemlist = clist
        self.refreshDisplay()

    def refreshDisplay(self):
        if self.__frame != None:
            self.__frame.setItemList(self.itemlist)

    def setCurIndex(self, index):
        if self.__frame != None:
            self.__frame.setCurIndex(index)

    def show(self, curindex=None):
        # py25.(2): self.curindex = curindex if curindex != None else 0
        if curindex != None: self.curindex = curindex
        else: self.curindex = 0

    def hide(self):
        pass

    def relayout(self, position, size):
        self.left = position.x
        self.top = position.y
        self.width = size.x
        self.height = size.y
        if self.__frame == None: return
        cw, ch = vimCharSize()
        x, y = vimWindowPos()
        pos = (x + self.left * cw, y + self.top * ch)
        size = ((self.width + 2) * cw, (self.height + 4) * ch)
        self.__frame.SetDimensions(pos[0], pos[1], size[0], size[1], wx.SIZE_FORCE)

    def process(self, curindex=0, startmode=1):
        app = ioutil.gwx.vimPrepareWx()
        cw, ch = vimCharSize()
        x, y = vimWindowPos()
        pos = (x + self.left * cw, y + self.top * ch)
        size = ((self.width + 2) * cw, (self.height + 4) * ch)
        self.__frame = MyFrame(None, -1, self.itemlist.title, position=pos, size=size)
        self.__frame.setItemList(self.itemlist, curindex)
        self.__frame.Show()
        app.MainLoop()
        return None

# Factory
def createListboxView(position, size):
    if ioutil.PLATFORM == "wx":
        return CPopupListbox(position, size)
    return None
