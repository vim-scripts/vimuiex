" vim: set fileencoding=utf-8 sw=3 ts=8 et
" vxrecentfile.vim - display a list of recent files in a popup window
"
" Author: Marko Mahnič
" Created: April 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python)

if vxlib#plugin#StopLoading('#au#vimuiex#vxrecentfile')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
exec vxlib#plugin#MakeSID()
" =========================================================================== 

" -------------------------------------------------------
" Displaying the MRU list
" -------------------------------------------------------

let s:SHOWNFILES=[]
function! s:GetRecentFiles()
   let s:SHOWNFILES = []
   for item in g:VxPluginVar.vxrecentfile_files
      call add(s:SHOWNFILES, fnamemodify(item, ':t') . "\t" . fnamemodify(item, ':p:~:h'))
   endfor
   return s:SHOWNFILES
endfunc

function! s:SelectFile_cb(index, winmode)
   let filename = s:SHOWNFILES[a:index]
   let fparts = split(filename, "\t")
   let filename = fparts[1] . '/' . fparts[0]
   let filename = fnamemodify(filename, ':p')

   call vxlib#cmd#Edit(filename, a:winmode)
   return 'q'
endfunc

function! s:SelectMarkedFiles_cb(marked, index, winmode)
   if len(a:marked) < 1
      return s:SelectFile_cb(a:index, a:winmode)
   endif
   only
   let first = 1
   for idx in a:marked
      call s:SelectFile_cb(idx, first ? '' : a:winmode)
      let first = 0
   endfor
   return 'q'
endfunc

function! vimuiex#vxrecentfile#VxOpenRecentFile()
   call vimuiex#vxlist#VxPopup(s:GetRecentFiles(), 'Recent files', {
      \ 'optid': 'VxOpenRecentFile',
      \ 'callback': s:SNR . 'SelectMarkedFiles_cb({{M}}, {{i}}, '''')', 
      \ 'columns': 1,
      \ 'keymap': [
         \ ['gs', 'vim:' . s:SNR . 'SelectMarkedFiles_cb({{M}}, {{i}}, ''s'')'],
         \ ['gv', 'vim:' . s:SNR . 'SelectMarkedFiles_cb({{M}}, {{i}}, ''v'')'],
         \ ['gt', 'vim:' . s:SNR . 'SelectMarkedFiles_cb({{M}}, {{i}}, ''t'')'],
         \ ['\<s-cr>', 'vim:' . s:SNR . 'SelectMarkedFiles_cb({{M}}, {{i}}, ''t'')'],
      \  ]
      \ })
   
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxrecentfile" require="python&&(!gui_running||python_screen)">
   call s:CheckSetting('g:VxRecentFile_size', 50)
   call s:CheckSetting('g:VxRecentFile_exclude', '""')
   call s:CheckSetting('g:VxRecentFile_nocase', !has('fname_case'))

   function! s:VIMUIEX_recentfile_SaveHistory()
      let g:VXRECENTFILES = join(g:VxPluginVar.vxrecentfile_files, "\n")
   endfunc

   function! s:VIMUIEX_recentfile_AutoMRU(filename) " based on tmru.vim
      if ! has_key(g:VxPluginVar, 'vxrecentfile_files') | return | endif
      if &buflisted && &buftype !~ 'nofile' && fnamemodify(a:filename, ':t') != ''
         if g:VxRecentFile_exclude != '' && a:filename =~ g:VxRecentFile_exclude
            return
         endif
         let files = g:VxPluginVar.vxrecentfile_files
         let idx = index(files, a:filename, 0, g:VxRecentFile_nocase)
         if idx == -1
            let rfiles = []
            for fnm in files
               call add(rfiles, resolve(fnm))
            endfor
            let rfname = resolve(a:filename)
            let idx = index(rfiles, rfname, 0, g:VxRecentFile_nocase)
         endif
         if idx == -1 && len(files) >= g:VxRecentFile_size
            let idx = g:VxRecentFile_size - 1
         endif
         if idx > 0  | call remove(files, idx) | endif
         if idx != 0 | call insert(files, a:filename) | endif
      endif
   endf

   augroup vxrecentfile
      autocmd!
      autocmd BufWritePost,BufReadPost * call s:VIMUIEX_recentfile_AutoMRU(expand('<afile>:p'))
      autocmd VimLeavePre * call s:VIMUIEX_recentfile_SaveHistory()
   augroup END

   " <STARTUP>
      call s:CheckSetting('g:VXRECENTFILES', '""')
      let g:VxPluginVar.vxrecentfile_files = split(g:VXRECENTFILES, "\n")
   " </STARTUP>

   command VxOpenRecentFile call vimuiex#vxrecentfile#VxOpenRecentFile()
   nmap <silent><unique> <Plug>VxOpenRecentFile :VxOpenRecentFile<cr>
   imap <silent><unique> <Plug>VxOpenRecentFile <Esc>:VxOpenRecentFile<cr>
   vmap <silent><unique> <Plug>VxOpenRecentFile :<c-u>VxOpenRecentFile<cr>
" </VIMPLUGIN>
