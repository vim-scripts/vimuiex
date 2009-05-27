import wx

WXAPP = None

def vimPrepareWx():
    global WXAPP
    if WXAPP == None: WXAPP = wx.App()
    return WXAPP
