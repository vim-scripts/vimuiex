" vim:set fileencoding=utf-8 sw=3 ts=3 et:vim
" 
" Author: Marko Mahnič
" Created: October 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#plugin#StopLoading('#au#vxlib#dlg')
   finish
endif

function! s:CompareNoCase(a, b)
   let a=tolower(a:a)
   let b=tolower(a:b)
   return a==b ? 0 : a<b ? -1 : 1
endfunc

function! s:DescribeFlags(flags, validFlags)
   let l:descr = ""
   for key in sort(keys(a:validFlags), 's:CompareNoCase')
      if match(a:flags, '\C' . key) >= 0
         let l:descr = l:descr . ' (' . key . ')' . a:validFlags[key]
      endif
   endfor
   return l:descr
endfunc

" Toggle the flags and display the current state with flag descriptions.
" @param flags - initial flags
" @param validFlags - dictionary key=flag, value=description
" @param exclusive - list of strings, each string contains a group of exclusive flags
" @param prompt - the text to display
" @param notifyEscape - if 0, the initial flags will be returend on <Esc>; otherwise
"       the string "**" will be returned.
" @returns - new flags; "**" or initial flags if <Esc> was pressed
"       (see notifyEscape)
function! vxlib#dlg#EditFlags(flags, validFlags, exclusive, prompt, notifyEscape)
   let l:good = 1
   let l:flags = a:flags
   let l:nch = 0
   let l:prompt = a:prompt
   let l:valid = join(sort(keys(a:validFlags), 's:CompareNoCase'), '')
   let l:prompt = a:prompt . ' [' . l:valid . ']:'
   while l:good && l:nch != 13
      redraw | echo l:prompt . s:DescribeFlags(l:flags, a:validFlags)
      let l:nch = getchar()
      let l:cch = nr2char(l:nch)
      if l:nch == 27 | let l:good = 0
      elseif l:nch>32 && l:nch<128 && has_key(a:validFlags, l:cch)
         let l:grpatt = ""
         for grp in a:exclusive
            let l:pos = match(grp, '\C' . l:cch)
            if l:pos >= 0 | let l:grpatt = '\C[' . grp . ']' | endif
         endfor
         let l:pos = match(l:flags, '\C' . l:cch)
         if l:pos < 0 
            " Remove other flags from exclusive group
            if l:grpatt != ""
               let l:flags = substitute(l:flags, l:grpatt, '', 'g')
            endif
            let l:flags = l:flags . l:cch " Add
         else
            let l:flags = substitute(l:flags, '\C' . l:cch, '', 'g') " Remove
         endif
      endif
   endwhile
   if l:good | return l:flags
   else | return '**'
   endif
endfunc

