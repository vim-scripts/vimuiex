" vim:set fileencoding=utf-8 sw=3 ts=3 et
" vxquickfix.vim - display quickfixlist or locationlist in a popup buffer 
"
" Author: Marko Mahnič
" Created: January 2010
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python)

if vxlib#plugin#StopLoading('#au#vimuiex#vxquickfix')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
exec vxlib#plugin#MakeSID()
let s:Qfitems = []
" =========================================================================== 

function! vimuiex#vxquickfix#TransformQfItems(items)
   let lastbuf = -1 
   let vxitems = []
   let vxids = []
   let i = 0
   for err in a:items
      let i += 1
      if lastbuf != err.bufnr
         if err.bufnr != 0 | let filename = bufname(err.bufnr)
         else | let filename = 'No Name'
         endif
         call add(vxids, i)
         call add(vxitems, filename)
         let lastbuf = err.bufnr
      endif
      call add(vxids, i)
      call add(vxitems, printf(' %2d: %3d %s %s', i, err.lnum, err.type, err.text))
   endfor
   return [vxids, vxitems]
endfunc

" TODO: Select error list or location list
function! s:GetQuickfixItems()
   let [s:Qfitems, items] = vimuiex#vxquickfix#TransformQfItems(getqflist())
   return items
endfunc

" TODO: Display location from error list (cc) or location list (ll)
function! s:SelectQfItem_cb(index)
   let idqf = s:Qfitems[a:index]
   exec 'cc ' . idqf
   return 'q'
endfunc

" TODO: Add preview (like vxoccur)
function! vimuiex#vxquickfix#VxQuickFix()
   call vimuiex#vxlist#VxPopup(s:GetQuickfixItems(), "Quickfix List", {
      \ 'optid': 'VxQuickFix',
      \ 'callback': s:SNR . 'SelectQfItem_cb({{i}})'
      \ })
endfunc

