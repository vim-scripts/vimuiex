" vim:set fileencoding=utf-8 sw=3 ts=3 et:vim
" 
" Author: Marko Mahnič
" Created: December 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#plugin#StopLoading('#au#vxlib#win')
   finish
endif

function! vxlib#win#GetPreviewWinNr()
   if &previewwindow
      return winnr()
   endif
   silent! wincmd P
   if &previewwindow
      let wnr = winnr()
      silent! wincmd p
      return wnr
   endif
   return 0
endfunc

" Some application might call pclose only when it created the preview:
"     let s:x = vxlib#win#PreviewExists()
"     call vxlib#win#OpenPreview("K", 30)
"     ...
"     if s:x | pclose | endif
function! vxlib#win#PreviewExists()
   if vxlib#win#GetPreviewWinNr() > 0
      return 1
   endif
   return 0
endfunc

" Opens, moves, resizes and activates the preview window
" position:    HJKL
" size:        number of lines/columns; only used if GT 0
" activate:    nonzero if the preview window should be activated
" TODO: check if vxlib#cmd#PreviewLine can replace vxlib#win#OpenPreview
function! vxlib#win#OpenPreview(pos, size, activate)
   let rest_on_no_act = 1 " restore the current window if preview should not be activated
   let neww = 0
   if &previewwindow
      let rest_on_no_act = 0
   endif
   silent! wincmd P
   if ! &previewwindow
      split
      set previewwindow
      let neww = 1
   endif
   if &previewwindow
      if match(a:pos, '^[HJKL]$') >= 0
         exec 'norm ' . a:pos
      endif
      set cursorline
      if a:size > 0 && match(a:pos, '^[HL]$') >= 0
         exec 'vertical resize ' . a:size
      else
         exec 'resize ' . a:size
      endif
      if rest_on_no_act && ! a:activate
         silent! wincmd p
      endif
   endif
   return neww
endfunc

" Find tab number for buffer; from bufExplorer
" return 0 if not found
function vxlib#win#GetTabNr(bufNr)
   for i in range(tabpagenr('$'))
      if index(tabpagebuflist(i + 1), a:bufNr) != -1
         return i + 1
      endif
   endfor

   return 0
endfunc

" Find the first window number on tab with buffer in it; from bufExplorer
" return 0 if not found
function vxlib#win#GetTabWinNr(tabNr, bufNr)
   return index(tabpagebuflist(a:tabNr), a:bufNr) + 1
endfunc

" Find all (tab,win) pairs that display buffer bufNr
function vxlib#win#ListBufferWindows(bufNr)
   let twlist = []
   for itab in range(tabpagenr('$'))
      let tbufs = tabpagebuflist(itab+1) " buffers displayed in tab itab+1
      for iwin in range(len(tbufs))
         if tbufs[iwin] == a:bufNr
            call add(twlist, [itab+1, iwin+1])
         endif
      endfor
   endfor
   return twlist
endfunc

