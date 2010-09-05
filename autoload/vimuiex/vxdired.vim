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
exec vxlib#plugin#MakeSID()
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

function! s:OpenMarkedFiles_cb(curdir, marked, selected, winmode)
   if len(a:marked) < 1
      return s:OpenFile_cb(a:curdir . '/' . a:selected, a:winmode)
   endif
   only
   let first = 1
   for fname in a:marked
      call s:OpenFile_cb(a:curdir . '/' . fname, first ? '' : a:winmode)
      let first = 0
   endfor
   let s:lastdir = a:curdir
   return 'q'
endfunc

function! s:NewFile_cb(curdir)
   let cwd = getcwd()
   redraw!
   echo a:curdir
   try
      " let hinp = vxlib#hist#GetHistory('input')
      exec 'chdir ' . a:curdir
      let newfn = input('Edit file:', '', 'file')
      " call vxlib#hist#SetHistory('input', l:hinp) " restore
   finally
      exec 'chdir ' . cwd
   endtry
   if empty(newfn) | return '' | endif
   try
      exec 'edit ' . fnameescape(a:curdir . '/' . newfn)
   catch /.*/
      return ''
   endtry
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
" @param mode:
"     'browse' - show current directory, normal operation
"     'filter' - show directory tree, filter mode
function! vimuiex#vxdired#VxFileBrowser(mode)
   exec 'python def SNR(s): return s.replace("$SNR$", "' . s:SNR . '")'

python << EOF
import vim
import vimuiex.dired as dired
import vimuiex.popuplist as popuplist
FBrowse = dired.CFileBrowser(optid="VxFileBrowser")
FBrowse.exprRecentDirList = SNR("$SNR$GetRecentDirList_cb()")
FBrowse.callbackEditFile = SNR("$SNR$OpenMarkedFiles_cb({{pwd}}, {{S}}, {{s}}, {{p}})")
# default command
FBrowse.keymapNorm.setKey(r"\<cr>", "list:dired-select") # also mapped in python
FBrowse.keymapNorm.setKey(r"\<c-cr>", "list:dired-select t")
# additional commands
FBrowse.keymapNorm.setKey(r"e", SNR("vim:$SNR$NewFile_cb({{pwd}})"))
FBrowse.keymapNorm.setKey(r"gt", "list:dired-select t")
FBrowse.keymapNorm.setKey(r"gs", "list:dired-select s")
FBrowse.keymapNorm.setKey(r"gv", "list:dired-select v")
EOF
   if a:mode == 'filter'
      exec 'python FBrowse.subdirDepth=' . g:VxFileFilter_treeDepth
      exec 'python FBrowse.deepListLimit=' . g:VxFileFilter_limitCount
      exec 'python FBrowse.fileFilter.skipFiles("' . escape(g:VxFileFilter_skipFiles, '\"') . '")'
      exec 'python FBrowse.fileFilter.skipDirs("' . escape(g:VxFileFilter_skipDirs, '\"') . '")'
      exec 'python FBrowse.process(curindex=0, cwd="' . escape(s:GetStartupDir(), ' \"') . '"' .
               \ ', startmode=popuplist.CList.MODE_FILTER)'
   else
      exec 'python FBrowse.fileFilter.skipFiles("' . escape(g:VxFileBrowser_skipFiles, '\"') . '")'
      exec 'python FBrowse.fileFilter.skipDirs("' . escape(g:VxFileBrowser_skipDirs, '\"') . '")'
      exec 'python FBrowse.process(curindex=0, cwd="' . escape(s:GetStartupDir(), ' \"') . '")'
   endif
   python FBrowse=None

endfunc

" ===========================================================================
" Global Initialization - Processed by Plugin Code Generator
" ===========================================================================
finish

" <VIMPLUGIN id="vimuiex#vxdired" require="python&&(!gui_running||python_screen)">
   call s:CheckSetting('g:VxRecentFile_nocase', !has('fname_case'))
   call s:CheckSetting('g:VxRecentDir_size', 20)
   call s:CheckSetting('g:VxFileFilter_treeDepth', 6)
   call s:CheckSetting('g:VxFileFilter_skipFiles', "'*.pyc,*.o,*.*~,*.~*,.*.swp'")
   call s:CheckSetting('g:VxFileFilter_skipDirs', "'.git,.svn'")
   call s:CheckSetting('g:VxFileFilter_limitCount', 0)
   call s:CheckSetting('g:VxFileBrowser_skipFiles', 'g:VxFileFilter_skipFiles')
   call s:CheckSetting('g:VxFileBrowser_skipDirs', "''")

   function! s:VIMUIEX_dired_SaveHistory()
      let g:VXRECENTDIRS = join(g:VxPluginVar.vxrecentfile_dirs, "\n")
   endfunc

   function! s:VIMUIEX_dired_AutoMRU(filename) " based on tmru.vim
      if ! has_key(g:VxPluginVar, 'vxrecentfile_dirs') | return | endif
      if &buflisted && &buftype !~ 'nofile' && fnamemodify(a:filename, ':t') != ''
         let dir = fnamemodify(a:filename, ':p:h')
         let dirs = g:VxPluginVar.vxrecentfile_dirs
         let idx = index(dirs, dir, 0, g:VxRecentFile_nocase)
         if idx == -1
            let rdirs = []
            for fnm in dirs
               call add(rdirs, resolve(fnm))
            endfor
            let rfname = resolve(dir)
            let idx = index(rdirs, rfname, 0, g:VxRecentFile_nocase)
         endif
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

   command VxFileBrowser call vimuiex#vxdired#VxFileBrowser('browse')
   command VxFileFilter call vimuiex#vxdired#VxFileBrowser('filter')
   nmap <silent><unique> <Plug>VxFileBrowser :VxFileBrowser<cr>
   imap <silent><unique> <Plug>VxFileBrowser <Esc>:VxFileBrowser<cr>
   vmap <silent><unique> <Plug>VxFileBrowser :<c-u>VxFileBrowser<cr>
   nmap <silent><unique> <Plug>VxFileFilter :VxFileFilter<cr>
   imap <silent><unique> <Plug>VxFileFilter <Esc>:VxFileFilter<cr>
   vmap <silent><unique> <Plug>VxFileFilter :<c-u>VxFileFilter<cr>

" </VIMPLUGIN>
