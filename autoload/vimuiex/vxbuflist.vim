" vim:set fileencoding=utf-8 sw=3 ts=3 et
" vxbuflist.vim - display a list of buffers in a popup window
"
" Author: Marko Mahnič
" Created: April 2009
" Changed: June 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python)

if vxlib#plugin#StopLoading("#au#vimuiex#vxbuflist")
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
map <SID>xx <SID>xx
let s:SID = substitute(maparg('<SID>xx'), '<SNR>\(\d\+_\)xx$', '\1', '')
unmap <SID>xx
let s:bufnumbers = []
" =========================================================================== 

function s:getBufOrderStr(lsline)
   let bo = matchstr(a:lsline, '\s*\zs\d\+\ze')
   let ai = index(g:VxPluginVar.vxbuflist_mru, 0 + bo)
   if ai < 0 | let ai = 99999 | endif
   return printf("%05d:", ai)
endfunc

function s:getDisplayStr(lsline)
   let b_st = matchstr(a:lsline, '^[^"]\+')
   let b_fn = matchstr(a:lsline, '"\zs.\{-}\ze"\s\+line \d\+\s*$')
   return b_st . printf("%-20s   %s", fnamemodify(b_fn, ":t"), fnamemodify(b_fn, ":h"))
endfunc

function! s:getBufferList()
   let show_hidden = 0
   let ls_bang = show_hidden ? '!' : ''
   let buffs = vxlib#cmd#Capture('ls' . ls_bang, 1)
   call map(buffs, 's:getBufOrderStr(v:val) . s:getDisplayStr(v:val)')
   call sort(buffs)
   call map(buffs, 'matchstr(v:val, ''\d\+:\zs.*$'')') | " remove order
   let s:bufnumbers = map(copy(buffs), 'matchstr(v:val, ''\s*\zs\d\+\ze'')')
   return buffs
endfunc

function! s:getRemoteBufferList()
   " TODO: s:getRemoteBufferList()
   "  use serverlist()
   "     and vxlib#cmd#Capture("!vim --servername ... --remote-expr getcwd()", 1)
   "     and vxlib#cmd#Capture("!vim --servername ... --remote-expr \"vxlib#cmd#Capture(':ls',1)\"", 1)
   "  or
   "     use remote_expr(<srv_name>, "getcwd()")
   "     and remote_expr(<srv_name>, "vxlib#cmd#Capture(':ls',1)")
endfunc

function! s:selectItem_cb(index)
   let nr = s:bufnumbers[a:index]
   exec "buffer " . nr
endfunc

function! vimuiex#vxbuflist#VxBufListSelect()
exec 'python VIM_SNR_VXBUFLIST="<SNR>' . s:SID .'"'

python << EOF
import vim
import vimuiex.popuplist as lister
List = lister.CList(title="Buffers")
## # List.loadBufferItems(__pybuflist_param_bufnr)
List.loadVimItems("%sgetBufferList()" % VIM_SNR_VXBUFLIST)
List.cmdAccept = "call %sselectItem_cb({{i}})" % VIM_SNR_VXBUFLIST
List.process(curindex=1)
List=None
EOF

endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxbuflist" require="python&&(!gui_running||python_screen)">
   let g:VxPluginVar.vxbuflist_mru = []
   function s:VIMUIEX_buflist_pushBufNr(nr)
      " mru code adapted from tlib#buffer
      let lst = g:VxPluginVar.vxbuflist_mru
      let i = index(lst, a:nr)
      if i > 0  | call remove(lst, i) | endif
      if i != 0 | call insert(lst, a:nr) | endif
   endfunc

   augroup vxbuflist
      autocmd BufEnter * call s:VIMUIEX_buflist_pushBufNr(bufnr('%'))
   augroup END
   command VxBufListSelect call vimuiex#vxbuflist#VxBufListSelect()
" </VIMPLUGIN>
