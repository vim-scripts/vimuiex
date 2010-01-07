" vim: set fileencoding=utf-8 sw=3 ts=8 et:vim
" vxlist.vim - a generic popup list implementation
"
" Author: Marko Mahnič
" Created: October 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; works only in terminal; using curses)

if vxlib#plugin#StopLoading('#au#vimuiex#vxlist')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
map <SID>xx <SID>xx
let s:SID = substitute(maparg('<SID>xx'), '<SNR>\(\d\+_\)xx$', '\1', '')
unmap <SID>xx
let s:_VxPopupList_DefaultPos = 'position=c autosize=vh minsize=20,4 size=0.5,0.5'
" =========================================================================== 

let s:items = []
let s:callback = ""

function! s:GetItems()
   return s:items
endfunc

function! s:SelectItem(index)
   if s:callback != '' && exists('*' . s:callback)
      exec 'call ' . s:callback . ' (' . a:index . ')'
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

   let id = substitute(a:title, '[^a-zA-Z0-9_]', '_', 'g')
   let id = substitute(id, '_\+', '_', 'g')
   exec 'python List = lister.CList(title="'. escape(a:title, '"\\') .'", optid="VxPopup-' . id . '")'

python << EOF
List.loadVimItems("%sGetItems()" % VIM_SNR_VXLIST)
List.cmdAccept = "%sSelectItem({{i}})" % VIM_SNR_VXLIST
List.process(curindex=0)
List=None
EOF

   let s:items = []
   let s:callback = ''
endfunc

" Plugin Box Position settings
"   VxPopupListPos - user settings in .vimrc
"   _VxPopupListPosDefault - plugin settings in code
"
" Each setting is a dictionary entry formatted like a :set command.
" Flagged settings can be modified with += / -=. Other settings can only be
" replaced with =.
"
" Options are parsed in python. Settings are merged in this order:
"   1. s:_VxPopupList_DefaultPos
"   2. g:VxPopupListPos["default"]
"   3. g:_VxPopupListPosDefault["plugin-id"]
"   4. g:VxPopupListPos["plugin-id"]

function! vimuiex#vxlist#GetPosOptions(optid)
   let opts = [s:_VxPopupList_DefaultPos]
   if exists('g:VxPopupListPos') && has_key(g:VxPopupListPos, 'default')
      call add(opts, g:VxPopupListPos['default'])
   endif
   if exists('g:_VxPopupListPosDefault') && has_key(g:_VxPopupListPosDefault, a:optid)
      call add(opts, g:_VxPopupListPosDefault[a:optid])
   endif
   if exists('g:VxPopupListPos') && has_key(g:VxPopupListPos, a:optid)
      call add(opts, g:VxPopupListPos[a:optid])
   endif
   return join(opts, ' ')
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxlist#colors" enabled="yes">
   hi def VxNormal term=reverse cterm=reverse guibg=DarkGrey
   hi def VxSelected term=NONE cterm=NONE guibg=Black guifg=White
   hi def VxQuickChar term=reverse,standout cterm=reverse ctermbg=1 guibg=DarkGrey guifg=White
   hi def VxMarked term=reverse,standout cterm=reverse ctermbg=1 guibg=DarkGrey guifg=Yellow
   hi def VxSelMarked term=NONE cterm=NONE guibg=Black guifg=Yellow
" </VIMPLUGIN>

" <VIMPLUGIN id="vimuiex#vxlist#init">
   call s:CheckSetting('g:VxPopupListPos', '{}')
   call s:CheckSetting('g:_VxPopupListPosDefault', '{}')
" </VIMPLUGIN>
