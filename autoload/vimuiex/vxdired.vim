" vim: set fileencoding=utf-8 sw=3 ts=8 et
" vxdired.vim - file browsing utilities
"
" Author: Marko Mahnič
" Created: June 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; works only in terminal; using curses)

if vxlib#plugin#StopLoading('#au#vimuiex#vxdired')
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

let s:lastdir = ''

function! s:GetRecentDirList_cb()
   return join(g:VxPluginVar.vxrecentfile_dirs, "\n")
endfunc

function! s:OpenFile_cb(filename, winmode)
   call vxlib#cmd#Edit(a:filename, a:winmode)
   let s:lastdir = fnamemodify(a:filename, ':p:h')
   return 'q'
endfunc

" vxdired initial directory: respect browsedir setting if available
function! s:GetStartupDir()
   try
      let brd = &browsedir
   catch /.*/
      let brd = 'buffer'
   endtry
   if brd == 'buffer' || s:lastdir == ''
      let sdir = fnamemodify(bufname('%'), ':p:h') 
   elseif brd == 'last'
      let sdir = s:lastdir
   else 
      let sdir = getcwd()
   endif
   return sdir
endfunc

" The file browser uses an internal command 'list:dired-select' to open
" selected items. If the selected item is a file, the internal command will
" use the expression defined in FBrowse.callbackEditFile to construct
" a callback and evaluate it. The internal command can accept one string
" parameter (without quotes) which will be passed to vxlib#cmd#Edit.
function! vimuiex#vxdired#VxFileBrowser()
   exec 'python VIM_SNR_VXDIRED="<SNR>' . s:SID .'"'

python << EOF
import vim
import vimuiex.dired as dired
FBrowse = dired.CFileBrowser(optid="VxFileBrowser")
FBrowse.exprRecentDirList = "%sGetRecentDirList_cb()" % VIM_SNR_VXDIRED
FBrowse.callbackEditFile = "%sOpenFile_cb({{s}}, {{p}})" % VIM_SNR_VXDIRED
# default keymap
FBrowse.keymapNorm.setKey(r"\<cr>", "list:dired-select") # also defined in python
FBrowse.keymapNorm.setKey(r"\<c-cr>", "list:dired-select t")
# keymaps: xs, xt, xv
FBrowse.keymapNorm.setKey(r"gt", "list:dired-select t")
FBrowse.keymapNorm.setKey(r"gs", "list:dired-select s")
FBrowse.keymapNorm.setKey(r"gv", "list:dired-select v")
EOF
   exec 'python FBrowse.process(curindex=0, cwd="' . s:GetStartupDir() . '")'
   python FBrowse=None

endfunc

" ===========================================================================
" Global Initialization - Processed by Plugin Code Generator
" ===========================================================================
finish

" <VIMPLUGIN id="vimuiex#vxdired" require="python&&(!gui_running||python_screen)">
   call s:CheckSetting('g:VxRecentFile_nocase', !has('fname_case'))
   call s:CheckSetting('g:VxRecentDir_size', 20)

   function! s:VIMUIEX_dired_SaveHistory()
      let g:VXRECENTDIRS = join(g:VxPluginVar.vxrecentfile_dirs, "\n")
   endfunc

   function! s:VIMUIEX_dired_AutoMRU(filename) " based on tmru.vim
      if ! has_key(g:VxPluginVar, 'vxrecentfile_dirs') | return | endif
      if &buflisted && &buftype !~ 'nofile' && fnamemodify(a:filename, ':t') != ''
         let dir = fnamemodify(a:filename, ':p:h')
         let dirs = g:VxPluginVar.vxrecentfile_dirs
         let idx = index(dirs, dir, 0, g:VxRecentFile_nocase)
         if idx == -1 && len(dirs) >= g:VxRecentDir_size
            let idx = g:VxRecentDir_size - 1
         endif
         if idx > 0  | call remove(dirs, idx) | endif
         if idx != 0 | call insert(dirs, dir) | endif
      endif
   endf

   augroup vxdired
      autocmd!
      autocmd BufWritePost,BufReadPost  * call s:VIMUIEX_dired_AutoMRU(expand('<afile>:p'))
      autocmd VimLeavePre * call s:VIMUIEX_dired_SaveHistory()
   augroup END

   " <STARTUP>
      call s:CheckSetting('g:VXRECENTDIRS', '""')
      let g:VxPluginVar.vxrecentfile_dirs = split(g:VXRECENTDIRS, "\n")
   " </STARTUP>

   command VxFileBrowser call vimuiex#vxdired#VxFileBrowser()

" </VIMPLUGIN>
