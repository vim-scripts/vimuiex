" vim:set fileencoding=utf-8 sw=3 ts=3 et
" vxcmdhist.vim - display command/search/etc. history in a popup window
"
" Author: Marko Mahnič
" Created: August 2010
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python)

if vxlib#plugin#StopLoading('#au#vimuiex#vxcmdhist')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
exec vxlib#plugin#MakeSID()
let g:_VxPopupListPosDefault['VxCmdHistoryPopup'] = 'position=515'
" =========================================================================== 

let s:selected = -1

function! vimuiex#vxcmdhist#PopupHist()
   let cmdtype = getcmdtype()
   let cmdline = getcmdline()
   let hist = vxlib#hist#GetHistory(cmdtype)
   let current = len(hist) - 1

   " find line in history that begins with current content of cmdline
   let cmlen = len(cmdline)
   if cmlen > 0
      let i = current
      while i >= 0
         if hist[i][:(cmlen-1)] == cmdline
            let current = i
            break
         endif
         let i = i - 1
      endwhile
   endif

   let s:selected = -1
   call vimuiex#vxlist#VxPopup(hist, "Cmd History", {
            \ "optid": "VxCmdHistoryPopup",
            \ "callback": s:SNR . 'SelectItem({{i}})',
            \ "current": current,
            \ "prompt": '>>>' . cmdtype . cmdline
            \ })
   if s:selected >= 0
      let cmdline = hist[s:selected]
   endif
   return cmdline
endfunc

function! s:SelectItem(index)
   let s:selected = a:index
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxcmdhist" require="python&&(!gui_running||python_screen)">
   call s:CheckSetting('g:vxcmdhist_default_map', '1')
   if g:vxcmdhist_default_map
      cnoremap <pageup> <C-\>evimuiex#vxcmdhist#PopupHist()<cr>
      cnoremap <pagedown> <C-\>evimuiex#vxcmdhist#PopupHist()<cr>
   endif
" </VIMPLUGIN>
