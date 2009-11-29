" vim:set fileencoding=utf-8 sw=3 ts=3 et:vim
"
" Author: Marko Mahnič
" Created: October 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#plugin#StopLoading("#au#vxlib#cmd")
   finish
endif

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
   let l:capture = ""
   redir => l:capture
   exec 'silent ' . a:aCommand
   redir END
   if a:doSplit
      return split(l:capture, '\n')
   endif
   return l:capture
endfunc

function! s:initCtrlTr()
   let s:trFrom = ""
   let s:trTo = ""
   for i in range(32)
      if i == 0 || i == 9 | continue | endif
      let s:trFrom = s:trFrom . nr2char(i)
      let s:trTo = s:trTo . " "
   endfor
endfunc
call s:initCtrlTr()

function! vxlib#cmd#ReplaceCtrlChars(text)
   return tr(a:text, s:trFrom, s:trTo)
endfunc

function! vxlib#cmd#Edit(filename)
   " This code is copied from tmru#Edit
   let bn = bufnr(a:filename)
   if bn != -1 && buflisted(bn)
      exec 'buffer '. bn
   elseif filereadable(a:filename)
      try
         exec 'edit '. fnameescape(a:filename)
      catch
         echohl error
         echom v:errmsg
         echohl NONE
      endtry
   else
      echom "File not readable: ". a:filename
   endif
endfunc

