" vim: set fileencoding=utf-8 sw=3 ts=8 et:vim
" vxlist.vim - a generic popup list implementation
"
" Author: Marko Mahnič
" Created: October 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; works only in terminal; using curses)

if vxlib#plugin#StopLoading("#au#vimuiex#vxlist")
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
map <SID>xx <SID>xx
let s:SID = substitute(maparg('<SID>xx'), '<SNR>\(\d\+_\)xx$', '\1', '')
unmap <SID>xx
" =========================================================================== 

let s:items = []
let s:callback = ""

function! s:getItems()
   return s:items
endfunc

function! s:selectItem(index)
   if s:callback != "" && exists("*" . s:callback)
      exec "call " . s:callback . " (" . a:index . ")"
   else
      echo s:callback
   endif
endfunc

function! vimuiex#vxlist#VxPopup(items, title, callback)
   let s:items = a:items
   let s:callback = a:callback
   exec 'python VIM_SNR_VXLIST="<SNR>' . s:SID .'"'

python << EOF
import vim
import vimuiex.popuplist as lister
EOF

   exec 'python List = lister.CList(title="'. escape(a:title, '"\\') .'", align="", autosize="VH")'

python << EOF
List.loadVimItems("%sgetItems()" % VIM_SNR_VXLIST)
List.cmdAccept = "call %sselectItem({{i}})" % VIM_SNR_VXLIST
List.process(curindex=0)
List=None
EOF

   let s:items = []
   let s:callback = ""
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxlist#colors" enabled="yes">
   hi def VxNormal term=reverse cterm=reverse guibg=DarkGrey
   hi def VxSelected term=NONE cterm=NONE guifg=White guibg=Black
   hi def VxQuickChar term=reverse,standout cterm=reverse ctermbg=1 guibg=DarkGrey guifg=White
" </VIMPLUGIN>
