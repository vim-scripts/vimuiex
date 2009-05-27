" vim: fileencoding=utf-8
" vxbuflist.vim - display a list of buffers in a popup window
"
" Author: Marko Mahnič
" Created: April 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python)

if exists("g:vxbuflist_loaded") && g:vxbuflist_loaded
	finish
endif
let g:vxbuflist_loaded = 1

let s:bufnumbers = []
function! s:getBufferList()
	let [s:bufnumbers, bufnames] = tlib#buffer#GetList(0, 1, "mru")
	return bufnames
endfunc

function! s:selectItem_cb(index)
	let nr = s:bufnumbers[a:index]
	exec "buffer " . nr
endfunc

call tlib#buffer#EnableMRU()
map <SID>xx <SID>xx
let s:SID = substitute(maparg('<SID>xx'), '<SNR>\(\d\+_\)xx$', '\1', '')
unmap <SID>xx

function! VxBufListSelect()
	call modpython#prepare()
	" exec "python __pybuflist_param_bufnr=" . s:buflist_nr
	" exec "python __pybuflist_param_items="  
	" let [s:bufnumbers, g:PYBUFLIST_bufnames] = tlib#buffer#GetList(0, 1, "mru")

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

