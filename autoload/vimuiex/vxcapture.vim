" vim: set fileencoding=utf-8 sw=3 ts=8 et:vim
" vxcapture.vim - capture output from various commands and display in list
"
" Author: Marko Mahnič
" Created: October 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; works only in terminal; using curses)

if vxlib#plugin#StopLoading('#au#vimuiex#vxcapture')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
exec vxlib#plugin#MakeSID()
let s:captured = []
" =========================================================================== 

function! s:ArgvList(skipLast)
   let i = 0
   let args = []
   while i < argc()-a:skipLast
      call add(args, argv(i))
      let i = i + 1
   endwhile
   return args
endfunc

" ------------ Any command ---------------
function! s:GetCaptured()
   return s:captured
endfunc

function! vimuiex#vxcapture#VxCmd(cmd)
   let t1 = []
   if has('gui_running') != 0
      let t1 = vxlib#cmd#Capture(a:cmd, 1)
   else
      if a:cmd =~ '^\s*!'
         let t1 = vxlib#cmd#CaptureShell(a:cmd)
      else
         let t1 = vxlib#cmd#Capture(a:cmd, 1)
      endif
   endif
   let s:captured = []
   for line in t1
      call add(s:captured, vxlib#cmd#ReplaceCtrlChars(line))
   endfor
   call vimuiex#vxlist#VxPopup(s:GetCaptured(), 'Command')
endfunc

function! vimuiex#vxcapture#VxCmd_QArgs(cmd)
   let args = s:ArgvList(1) " skip last one - the file name
   call vimuiex#vxcapture#VxCmd(a:cmd . ' ' . join(args, ' '))
endfunc

" ------------ Marks ---------------
function! s:GetMarkList()
   let mrks = vxlib#cmd#Capture('marks', 1)
   call filter(mrks, 'v:val =~ "^ [^ ] " ')
   let s:captured = map(copy(mrks),  'matchstr(v:val, ''.\zs.\ze'')')
   return mrks
endfunc

function! s:SelectItem_marks(index)
   let mrk = s:captured[a:index]
   exec "norm '" . mrk
endfunc

function! vimuiex#vxcapture#VxMarks()
   call vimuiex#vxlist#VxPopup(s:GetMarkList(), 'Marks',
      \ { 'callback': s:SNR . 'SelectItem_marks({{i}})' }
      \ )
endfunc

" ------------ Registers ---------------
function! s:GetRegisterList()
   let regs = vxlib#cmd#Capture('display', 1)
   call filter(regs, 'v:val =~ "^\"" ')
   call map(regs, 'substitute(v:val, "[ \t]\\+", " ", "g")')
   let s:captured = map(copy(regs),  'matchstr(v:val, ''.\zs.\ze'')')
   return regs
endfunc

function! s:SelectItem_regs(index)
   let nreg = s:captured[a:index]
   exec 'norm "' . nreg . 'p'
endfunc

function! s:RunRegMacro_cb(index)
   let nreg = s:captured[a:index]
   exec 'norm @' . nreg
   return 'q'
endfunc

"function! s:InitRegistersList(pyListName)
"   exec 'python ' . a:pyListName . '.keymapNorm.setKey(r"@", "vim:' . s:SNR . 'RunRegMacro_cb({{i}})")'
"endfunc
" 'init': s:SNR . 'InitRegistersList',

function! vimuiex#vxcapture#VxDisplay()
   call vimuiex#vxlist#VxPopup(s:GetRegisterList(), 'Registers', {
      \ 'callback': s:SNR . 'SelectItem_regs({{i}})',
      \ 'keymap': [
         \ ['@', 'vim:' . s:SNR . 'RunRegMacro_cb({{i}})']
      \  ]
      \ })
endfunc

" ------------ Man pages ---------------
"  Use MANWIDTH to set the width of the output
function! vimuiex#vxcapture#VxMan(kwd)
   let mw = &columns - 20
   if mw < 20 | let mw = 20 | endif
   if mw > &columns | let mw = &columns | endif
   call vimuiex#vxcapture#VxCmd('!MANWIDTH=' . mw . ' man -P cat ' . a:kwd . ' | col -b')
endfunc

function! vimuiex#vxcapture#VxMan_QArgs(first)
   let args = s:ArgvList(1) " skip last one - the file name
   call vimuiex#vxcapture#VxMan(a:first . ' ' . join(args, ' '))
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxcapture" require="python&&(!gui_running||python_screen)">
   command -nargs=+ -complete=command VxCmd call vimuiex#vxcapture#VxCmd_QArgs(<q-args>)
   command VxMarks call vimuiex#vxcapture#VxMarks()
   command VxDisplay call vimuiex#vxcapture#VxDisplay()
   command -nargs=+ VxMan call vimuiex#vxcapture#VxMan_QArgs(<q-args>)
   nmap <silent><unique> <Plug>VxMarks :VxMarks<cr>
   imap <silent><unique> <Plug>VxMarks <Esc>:VxMarks<cr>
   vmap <silent><unique> <Plug>VxMarks :<c-u>VxMarks<cr>
   nmap <silent><unique> <Plug>VxDisplay :VxDisplay<cr>
   imap <silent><unique> <Plug>VxDisplay <Esc>:VxDisplay<cr>
   vmap <silent><unique> <Plug>VxDisplay :<c-u>VxDisplay<cr>
" </VIMPLUGIN>

