#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et:vim

import re

# Settings for a single plugin.
# The layout of the input config file is preserved on write.
class CPluginSettings:
    rxvar = re.compile(r"\s*([a-zA-Z0-9_.]+)\s*=\s*(.*)$")
    def __init__(self, plugid):
        self.plugid = plugid.strip("[] \n\r\t")
        self.lines = [] # preserve file layout
        self.settings = {}
        pass

    def addLine(self, line):
        if line.strip() == "" and len(self.lines) > 0 and self.lines[-1].strip() == "":
            return
        self.lines.append(line.rstrip())
        line = line.strip()
        mo = CPluginSettings.rxvar.match(line)
        if mo != None and len(mo.group(1).strip()) > 0:
            self.settings[mo.group(1).strip()] = mo.group(2).strip()

    def addMissingVar(self, name, value=""):
        rxvar = re.compile(r"^\s*" + re.escape(name) + r"\s*=")
        for line in self.lines:
            mo = rxvar.search(line)
            if mo != None: return
        rxvar = re.compile(r"^\s*#.*" + re.escape(name) + r"\s*=")
        for line in self.lines:
            mo = rxvar.search(line)
            if mo != None: return
        self.lines.append("# %s=%s" % (name, value))

    def _compressLines(self):
        lines = []
        addblank = False
        for ln in self.lines:
            if ln.strip() == "":
                addblank = True
                continue
            if addblank: lines.append(" ")
            lines.append(ln)
            addblank = False
        self.lines = lines

    def saveSettings(self):
        for k,v in self.settings.iteritems():
            self.addMissingVar(k, v)
        self._compressLines()

    def getValue(self, name):
        if self.settings.has_key(name): return self.settings[name]
        return None

# Settings for multiple plugins read from a config file (windows ini style)
class CPluginConfig:
    rxsec = re.compile(r"\s*\[(\S+)\].*$")
    def __init__(self):
        self.plugins = {}
        self.loadorder = []

    def getPluginConf(self, pid):
        if self.plugins.has_key(pid): plugin = self.plugins[pid]
        else:
            plugin = CPluginSettings(pid)
            self.plugins[pid] = plugin
        return plugin

    def loadConfig(self, filename):
        f = open(filename, "r")
        plugin = None
        line = "\n"
        while line != "":
            line = f.readline()
            mo = CPluginConfig.rxsec.match(line)
            if mo != None:
                pid = mo.group(1).strip()
                plugin = self.getPluginConf(pid)
                if not pid in self.loadorder: self.loadorder.append(pid)
                continue
            if plugin != None: plugin.addLine(line)

    def saveConfig(self, filename):
        fout = open(filename, "w")
        tosave = []

        # reorder the plugins to load-order
        for pid in self.loadorder:
            if self.plugins.has_key(pid):
                tosave.append(self.plugins[pid])
                self.plugins.pop(pid)

        # add the plugins that were not in self.loadorder
        thenew = []
        for k,p in self.plugins.iteritems(): thenew.append(p)
        thenew.sort(key=lambda p: p.plugid)
        tosave.extend(thenew)

        # rebuild dictionary
        for p in tosave: self.plugins[p.plugid] = p

        for p in tosave:
            p.addMissingVar("generate", "1")
            p.addMissingVar("enabled", "1")
            p.saveSettings()
            fout.write("[%s]\n" % p.plugid)
            for l in p.lines:
                fout.write("%s\n" % l)
            fout.write("\n")
        fout.close()

    def dump(self):
        for k,p in self.plugins.iteritems():
            print "------------", p.plugid
            print p.lines
            print p.settings

def Test():
    C = CPluginConfig()
    C.loadConfig("plugin.conf")
    C.dump()
    C.saveConfig("")
