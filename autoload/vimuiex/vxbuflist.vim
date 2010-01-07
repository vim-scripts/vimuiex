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

if vxlib#plugin#StopLoading('#au#vimuiex#vxbuflist')
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
let g:_VxPopupListPosDefault['VxBufListSelect'] = 'minsize=0.4,8'
" =========================================================================== 

let s:bufOrderDef = [ ['m', 'MRU'], ['#', 'BufNr'], ['n', 'Name'], ['e', 'Ext'], ['f', 'Path'] ]
let s:bufOrder = 0
let s:bufFileFormat = 's' " split, normal
let s:bufPath = 'r'       " relative, full
let s:showUnlisted = 0
function s:GetBufOrderStr(lsline)
   let order = s:bufOrderDef[s:bufOrder][0]
   if order == 'm' || order == '#'
      let bo = matchstr(a:lsline, '\s*\zs\d\+\ze')
      if order == '#' | let ai = bo
      else
         let ai = index(g:VxPluginVar.vxbuflist_mru, 0 + bo)
         if ai < 0 | let ai = 99999 | endif
      endif
      return printf('%05d', ai)
   else
      let b_fn = matchstr(a:lsline, '"\zs.\{-}\ze"\s\+line \d\+\s*$')
      if order == 'n' | return fnamemodify(b_fn, ':t')
      elseif order == 'e' 
         try
            return fnamemodify(b_fn, ':e')
         catch /.*/
            return ""
         endtry
      else | return fnamemodify(b_fn, ':p')
      endif
   endif
endfunc

function s:GetDisplayStr(lsline)
   let b_st = matchstr(a:lsline, '^[^"]\+')
   let b_fn = matchstr(a:lsline, '"\zs.\{-}\ze"\s\+line \d\+\s*$')
   return b_st . fnamemodify(b_fn, ':t') . "\t" . fnamemodify(b_fn, ':h')
endfunc

function! s:GetBufferList()
   let lscmd = s:showUnlisted ? 'ls!' : 'ls'
   let buffs = vxlib#cmd#Capture(lscmd, 1)
   call map(buffs, '[s:GetBufOrderStr(v:val), s:GetDisplayStr(v:val)]')
   call sort(buffs, 1)
   call map(buffs, 'v:val[1]')
   let s:bufnumbers = map(copy(buffs), 'matchstr(v:val, ''\s*\zs\d\+\ze'')')
   return buffs
endfunc

function! s:GetRemoteBufferList()
   " TODO: s:GetRemoteBufferList()
   "  use serverlist()
   "     and vxlib#cmd#Capture("!vim --servername ... --remote-expr getcwd()", 1)
   "     and vxlib#cmd#Capture("!vim --servername ... --remote-expr \"vxlib#cmd#Capture(':ls',1)\"", 1)
   "  or
   "     use remote_expr(<srv_name>, 'getcwd()')
   "     and remote_expr(<srv_name>, "vxlib#cmd#Capture(':ls',1)")
endfunc

function! s:GetTitle()
   let order = s:bufOrderDef[s:bufOrder]
   let title = 'Buffers by ' . order[1]
   return title
endfunc

function! s:SelectBuffer_cb(index, winmode)
   let bnr = s:bufnumbers[a:index]
   call vxlib#cmd#GotoBuffer(0 + bnr, a:winmode)
   return 'q'
endfunc

function! s:SelectMarkedBuffers_cb(marked, index, winmode)
   if len(a:marked) < 1
      return s:SelectBuffer_cb(a:index, a:winmode)
   endif
   only
   let first = 1
   for idx in a:marked
      call s:SelectBuffer_cb(idx, first ? '' : a:winmode)
      let first = 0
   endfor
   return 'q'
endfunc

function! s:ResortItems_cb()
   let s:bufOrder = (s:bufOrder + 1) % len(s:bufOrderDef)
   exec 'python BufList.title="' . s:GetTitle() . '"'
   call s:ReloadBufferList()
   return ""
endfunc

" command: bdelete, bwipeout, bunload
function! s:RemoveBuffer_cb(index, command)
   let nr = s:bufnumbers[a:index]
   exec a:command . ' ' . nr
   call s:ReloadBufferList()
   return ''
endfunc

function! s:ToggleUnlisted_cb()
   let s:showUnlisted = s:showUnlisted ? 0 : 1
   call s:ReloadBufferList()
   return ''
endfunc

function! s:ReloadBufferList()
   python BufList.loadVimItems('%sGetBufferList()' % VIM_SNR_VXBUFLIST)
endfunc

function! vimuiex#vxbuflist#VxBufListSelect()
   exec 'python VIM_SNR_VXBUFLIST="<SNR>' . s:SID .'"'

python << EOF
import vim
import vimuiex.popuplist as lister
BufList = lister.CList(title="Buffers", optid="VxBufListSelect")
BufList._firstColumnAlign = True
EOF
   exec 'python BufList.title="' . s:GetTitle() . '"'
python << EOF
BufList.loadVimItems("%sGetBufferList()" % VIM_SNR_VXBUFLIST)
BufList.cmdAccept = "%sSelectBuffer_cb({{i}}, '')" % VIM_SNR_VXBUFLIST
BufList.keymapNorm.setKey(r"\<s-cr>", "vim:%sSelectBuffer_cb({{i}}, 't')" % VIM_SNR_VXBUFLIST)
# x-"execute" 
BufList.keymapNorm.setKey(r"xd", "vim:%sRemoveBuffer_cb({{i}}, 'bdelete')" % VIM_SNR_VXBUFLIST)
BufList.keymapNorm.setKey(r"xw", "vim:%sRemoveBuffer_cb({{i}}, 'bwipeout')" % VIM_SNR_VXBUFLIST)
# g-"goto" 
BufList.keymapNorm.setKey(r"gs", "vim:%sSelectMarkedBuffers_cb({{M}}, {{i}}, 's')" % VIM_SNR_VXBUFLIST)
BufList.keymapNorm.setKey(r"gv", "vim:%sSelectMarkedBuffers_cb({{M}}, {{i}}, 'v')" % VIM_SNR_VXBUFLIST)
BufList.keymapNorm.setKey(r"gt", "vim:%sSelectBuffer_cb({{i}}, 't')" % VIM_SNR_VXBUFLIST)
# o-"option"
BufList.keymapNorm.setKey(r"ou", "vim:%sToggleUnlisted_cb()" % VIM_SNR_VXBUFLIST)
BufList.keymapNorm.setKey(r"os", "vim:%sResortItems_cb()" % VIM_SNR_VXBUFLIST)
BufList.process(curindex=1)
BufList=None
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
