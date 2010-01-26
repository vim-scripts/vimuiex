" vim:set fileencoding=utf-8 sw=3 ts=3 et:vim
"
" Author: Marko Mahnič
" Created: October 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#plugin#StopLoading('#au#vxlib#hist')
   finish
endif

function! s:Capture(aCommand, doSplit)
   redir => l:capture
   exec 'silent ' . a:aCommand
   redir END
   if a:doSplit
      return split(l:capture, '\n')
   endif
   return l:capture
endfunc

function! s:PrepareHistory()
   if exists('s:UserHistory') | return | endif
   let s:UserHistory = {}
   if exists('g:CUSTOM_HISTORIES')
      call s:RestoreHistories()
   endif
endfunc

function! s:SaveHistories()
   let saved = []
   for histname in keys(s:UserHistory)
      call add(saved, '>' . histname)
      for item in s:UserHistory[histname]
         let item = substitute(item, "\x01", "\x01\x02", 'g')
         let item = substitute(item, "\x0a", "\x01\x03", 'g')
         let item = substitute(item, "\x0d", "\x01\x04", 'g')
         call add(saved, '.' . item)
      endfor
   endfor
   let g:CUSTOM_HISTORIES = join(saved, "\n")
endfunc

function! s:RestoreHistories()
   let saved = split(g:CUSTOM_HISTORIES, "\n")
   let histname = ''
   for item in saved
      let item = substitute(item, "\x01\x03", "\x0a", 'g')
      let item = substitute(item, "\x01\x04", "\x0d", 'g')
      let item = substitute(item, "\x01\x02", "\x01", 'g')
      let type = item[0]
      let text = item[1:]
      if type == '>'
         let s:UserHistory[text] = []
         let histname = text
      elseif type == '.' && histname != ''
         call add(s:UserHistory[histname], text)
      endif
   endfor
   unlet g:CUSTOM_HISTORIES
endfunc

function! s:IsVimHistory(name)
   for hn in [':', '/', '=', '@', 'cmd', 'search', 'expr', 'input']
      if hn==a:name | return 1 | endif
   endfor
   return 0
endfunc

function! vxlib#hist#GetHistory(name)
   if s:IsVimHistory(a:name)
      let l:hist = s:Capture('history ' . a:name, 1)
      " remove order; 2 spaces between order and string
      call map(l:hist, 'matchstr(v:val, ''^>\?\s*\d\+  \zs.*$'')')
   else
      if has_key(s:UserHistory, a:name)
         let l:hist = s:UserHistory[a:name]
      else
         let l:hist = []
      endif
   endif
   return l:hist
endfunc

function! vxlib#hist#SetHistory(name, list)
   if s:IsVimHistory(a:name)
      call histdel(a:name)
      " TODO: use only last items if list too long
      for l:item in a:list
         call histadd(a:name, l:item)
      endfor
   else
      " Remember only the number of items set in the &history setting!
      let l:ilast = len(a:list) - &history - 1
      if l:ilast > 0 | call remove(a:list, 0, l:ilast) | endif
      let s:UserHistory[a:name] = a:list
   endif
endfunc

function! vxlib#hist#CopyHistory(nameFrom, nameTo)
   let l:from = vxlib#hist#GetHistory(a:nameFrom)
   call vxlib#hist#SetHistory(a:nameTo, l:from)
endfunc

function! vxlib#hist#ClearUserHistory(name)
   if has_key(s:UserHistory, a:name)
      call remove(s:UserHistory, a:name)
   endif
endfunc

function! vxlib#hist#AddHistory(name, item)
   if s:IsVimHistory(a:name)
      call histadd(a:name, a:item)
   else
      if has_key(s:UserHistory, a:name)
         let hlist = s:UserHistory[a:name]
         let iit = index(hlist, a:item)
         if iit >= 0 | call remove(hlist, iit) | endif
         call add(hlist, a:item)
         let ilast = len(hlist) - &history - 1
         if ilast > 0 | call remove(hlist, 0, ilast) | endif
         let s:UserHistory[a:name] = hlist
      else
         let s:UserHistory[a:name] = [a:item]
      endif
   endif
endfunc

" =============================================================================
" Initialization/Termination
"    - UserHistory will be restored from g:CUSTOM_HISTORIES the first time
"    vxlib#hist# is used
"    - at the same time VimLeavePre event will be created and the history
"    will be saved to viminfo on exit
"    - if vxlib#hist# isn't used in a session, g:CUSTOM_HISTORIES remains
"    unchanged (as read from viminfo)
" =============================================================================
call s:PrepareHistory()
" VimLeavePre * will run at most once if current buffer-name matches *.
autocmd VimLeavePre * call s:SaveHistories()

