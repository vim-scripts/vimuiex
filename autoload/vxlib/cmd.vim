" vim:set fileencoding=utf-8 sw=3 ts=3 et:vim
"
" Author: Marko Mahnič
" Created: October 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#plugin#StopLoading('#au#vxlib#cmd')
   finish
endif

" use in script that needs SID with: exec vxlib#cmd#MakeSID()
function! vxlib#cmd#MakeSID()
   let sid_script = "map <SID>xx <SID>xx\n" .
      \ "let s:SID = substitute(maparg('<SID>xx'), '<SNR>\\(\\d\\+_\\)xx$', '\\1', '') \n" .
      \ "unmap <SID>xx"
   return sid_script
endfunc

function! vxlib#cmd#CaptureShell(aCommand)
   let capture = []
   try
      botright 1 new
      setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
      exec '$read ' . a:aCommand
      let capture = getline(1, '$')
   finally
      bdelete!
   endtry
   return capture
endfunc

function! vxlib#cmd#Capture(aCommand, doSplit)
   let l:capture = ''
   redir => l:capture
   exec 'silent ' . a:aCommand
   redir END
   if a:doSplit
      return split(l:capture, '\n')
   endif
   return l:capture
endfunc

function! s:InitCtrlTr()
   let s:trFrom = ''
   let s:trTo = ''
   for i in range(32)
      if i == 0 || i == 9 | continue | endif
      let s:trFrom = s:trFrom . nr2char(i)
      let s:trTo = s:trTo . ' '
   endfor
endfunc
call s:InitCtrlTr()

function! vxlib#cmd#ReplaceCtrlChars(text)
   return tr(a:text, s:trFrom, s:trTo)
endfunc

" \param [winmode]:
"        s-split
"        v-vertical split
"        t-open in new tab (if not displayed). Based on BufExplorer behaviour.
function! vxlib#cmd#GotoBuffer(bufnr, ...)
   let winmode = ''
   if a:0 > 0
      let winmode = a:1
   endif
   if winmode == 's' | exec 'split +buffer' . a:bufnr
   elseif winmode == 'v' |exec 'vsplit +buffer' . a:bufnr 
   else
      let btab = vxlib#win#GetTabNr(0 + a:bufnr)
      if btab < 1 " buffer not displayed
         if winmode == 't' | exec '999tab split +buffer' . a:bufnr 
         else | exec 'buffer ' . a:bufnr
         endif
      else " buffer is displayed in a tab
         exec btab . 'tabnext'
         let bwin = vxlib#win#GetTabWinNr(btab, a:bufnr)
         exec bwin . 'wincmd w'
      endif
   endif
endfunc

" \param filename: an existing filename
" \param [winmode]: \see #GotoBuffer
" result:
"     -1    file not readable
"     -2    error while loading
"      1    file was already in buffer, buffer was selected
"      2    file loadede and selected
function! vxlib#cmd#Edit(filename, ...)
   if a:0 > 0 | let winmode = a:1 | else | let winmode = '' | endif
   let bnr = bufnr(a:filename)
   if bnr != -1 && bufexists(bnr)
      call vxlib#cmd#GotoBuffer(bnr, winmode)
      return 1
   elseif filereadable(a:filename)
      try
         if winmode == "s" | exec 'split ' . fnameescape(a:filename)
         elseif winmode == "v" | exec 'vsplit ' . fnameescape(a:filename) 
         elseif winmode == "t" | exec 'tabedit ' .fnameescape(a:filename)
         else | exec 'edit '. fnameescape(a:filename)
         endif
         return 2
      catch
         echohl error
         echom v:errmsg
         echohl NONE
         return -2
      endtry
   else
      echom 'File not readable: '. a:filename
      return -1
   endif
endfunc

" \param filename: (use '' or '%' for current file)
" \param line, column:   the position to jump to
" \param [zflags]:       string with flags
"     O     execute zO on closed folds
"     z     execute zz
" \param [winmode]: \see #GotoBuffer
function! vxlib#cmd#EditLine(filename, line, column, ...)
   let isopen = 1
   if a:0 > 0 | let zflags = a:1 | else | let zflags = '' | endif
   if a:0 > 1 | let winmode = a:2 | else | let winmode = '' | endif
   if a:filename != '' && a:filename != '%'
      let isopen = vxlib#cmd#Edit(a:filename, winmode)
      if isopen <= 0
         return isopen
      endif
   endif
   call setpos('.', [0, a:line, a:column, 0])
   " Unfold and center
   if v:foldlevel > 0 && match(zflags, 'O') >= 0
      try | norm zO
      catch /E490/ " No fold found
      endtry
   endif
   if match(zflags, 'z') >= 0
      norm zz
   endif
   return isopen
endfunc

" Display a file/buffer in the preview window and jump to line. Unfold the
" line to make it visible.
"
" filenameOrBufnr
"        file name or number of the buffer to display
"        "%" for current file
function! vxlib#cmd#PreviewLine(filenameOrBufnr, line)
   let lnn = a:line
   if lnn < 1
      let lnn = 1
   endif
   let fname = a:filenameOrBufnr
   if type(fname) == type(0)
      let fname = bufname(fname)
   endif
   if fname == '%'
      let fname = bufname('%')
   endif
   if fname == '' 
      return
   endif
   exec 'pedit ' . '+' . a:line . ' ' . fname
   let pwnr=vxlib#win#GetPreviewWinNr()
   if pwnr > 0
      let wnr = winnr()
      exec pwnr . 'wincmd w'
      set cursorline
      call vxlib#cmd#EditLine('%', a:line, 1, 'zO')
      exec wnr . 'wincmd w'
   endif
endfunc

function! vxlib#cmd#ShowQFixPreview()  
   let idqf = line('.') - 1
   let pos = getqflist()[idqf]
   call vxlib#cmd#PreviewLine(pos.bufnr, pos.lnum)
endfunc

function! vxlib#cmd#PrepareQFixPreview()
   nnoremap <buffer><silent> <Space> :call vxlib#cmd#ShowQFixPreview()<CR>
   nnoremap <buffer><silent> p :call vxlib#cmd#ShowQFixPreview()<CR>
   nnoremap <buffer><silent> P :pclose<CR>
   nnoremap <buffer><silent> <CR> :pclose<CR><CR>
   " TODO: How to choose between cclose ande lclose? nnoremap <silent> <c-CR> :pclose<CR><CR>:cclose<CR>
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vxlib#quickfixpreview" require="windows&&quickfix">
   autocmd FileType qf call vxlib#cmd#PrepareQFixPreview()
" </VIMPLUGIN>

