#!/usr/bin/env python
# vim:set fileencoding=utf-8 sw=4 ts=8 et:vim
# Author:  Marko Mahnič
# Created: mar 2010 

class CWordFilter:
    def __init__(self):
        self.separator = ","
        self.filterWords = [] # [ (word, negated) ]
        self.ignoreCase = True
        self.strFilter = ""
        self.filterGrown = False # enable incremental filtering

    def setFilter(self, text):
        self.filterGrown = text.find(self.strFilter) >= 0
        self.strFilter = text
        if self.ignoreCase: text = text.lower()
        if self.separator == "": sep = " "
        else: sep = self.separator
        filt = text.split(sep)
        filt = [ f.strip() for f in filt if f.strip() != "" ]
        filt = [ (f.lstrip("-"), f.startswith("-")) for f in filt if f.lstrip("-") != ""]
        self.filterWords = filt

    # @returns (good, bestpos)
    #    good = 1  - all (+words) accepted
    #    good = -1 - one (-words) rejected
    #    good = 0  - one (+words) didn't match
    def match(self, text, startat=0):
        if self.isEmpty(): return (1, startat)
        good = 1; bestpos = -1
        if self.ignoreCase: text = text.lower()
        # match ALL of +words and NONE of -words
        for word,neg in self.filterWords:
            pos = text.find(word, startat)
            if pos >= 0 and neg:
                good = -1
                break
            if pos < 0 and not neg:
                good = 0
                break
            if bestpos < 0 and not neg and pos >= 0: bestpos = pos
        return (good, bestpos)

    def isEmpty(self):
        return len(self.filterWords) < 1
