" vim: fileencoding=utf-8 sw=3 ts=8 et :
" vxrecentfile.vim - display a list of recent files in a popup window
"
" Author: Marko Mahnič
" Created: April 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python)

if exists("g:vxrecentfile_loaded") && g:vxrecentfile_loaded
   finish
endif
let g:vxrecentfile_loaded = 1

function! s:CheckSetting(name, default)
   if !exists(a:name)
      exec "let " . a:name . "=" . a:default
   endif
endfunc
call s:CheckSetting('g:VxRecentFile_size', 50)
call s:CheckSetting('g:VxRecentFile_exclude', '""')
call s:CheckSetting('g:VxRecentFile_nocase', !has('fname_case'))
call s:CheckSetting('g:VXRECENTFILES', '""')

" -------------------------------------------------------
" Displaying the MRU list
" -------------------------------------------------------

let s:SHOWNFILES=[]
function! s:getRecentFiles()
   let s:SHOWNFILES = []
   for item in split(g:VXRECENTFILES, "\n")
      call add(s:SHOWNFILES, fnamemodify(item, ":t") . "\t" . fnamemodify(item, ":p:~:h"))
   endfor
   return s:SHOWNFILES
endfunc

function! s:selectItem_cb(index)
   let filename = s:SHOWNFILES[a:index]
   let fparts = split(filename, "\t")
   let filename = fparts[1] . g:tlib_filename_sep . fparts[0]
   let filename = fnamemodify(filename, ":p")

   " This code is copied from tmru#Edit
   let bn = bufnr(filename)
   if bn != -1 && buflisted(bn)
      exec 'buffer '. bn
   elseif filereadable(filename)
      try
         exec 'edit '. tlib#arg#Ex(filename)
      catch
         echohl error
         echom v:errmsg
         echohl NONE
      endtry
   else
      echom "File not readable: ". filename
   endif
endfunc

map <SID>xx <SID>xx
let s:SID = substitute(maparg('<SID>xx'), '<SNR>\(\d\+_\)xx$', '\1', '')
unmap <SID>xx

function! VxOpenRecentFile()
   call modpython#prepare()

exec 'python VIM_SNR_VXRECENTFILES="<SNR>' . s:SID .'"'
python << EOF
import vim
import vimuiex.popuplist as lister
List = lister.CList(title="Recent files", autosize="HC", align="")
List.loadVimItems("%sgetRecentFiles()" % VIM_SNR_VXRECENTFILES)
List.cmdAccept = "call %sselectItem_cb({{i}})" % VIM_SNR_VXRECENTFILES
# TODO: s - split, v - vsplit
List.process(curindex=0)
List=None
EOF

endfunc

" -------------------------------------------------------
" Keeping the MRU list
" -------------------------------------------------------

function! s:MruRegister(fname) " based on tmru.vim
    if g:VxRecentFile_exclude != '' && a:fname =~ g:VxRecentFile_exclude
        return
    endif
    let files = split(g:VXRECENTFILES, "\n")
    let idx = index(files, a:fname, 0, g:VxRecentFile_nocase)
    if idx == -1 && len(files) >= g:VxRecentFile_size
        let idx = g:VxRecentFile_size - 1
    endif
    if idx != -1
        call remove(files, idx)
    endif
    call insert(files, a:fname)
    let g:VXRECENTFILES = join(files, "\n")
endf

function! s:AutoMRU(filename) " based on tmru.vim
    if &buflisted && &buftype !~ 'nofile' && fnamemodify(a:filename, ":t") != ''
        call s:MruRegister(a:filename)
    endif
endf

augroup vxrecentfile
    au!
    au BufWritePost,BufReadPost  * call s:AutoMRU(expand("<afile>:p"))
augroup END

