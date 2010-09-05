" vim: set fileencoding=utf-8 sw=3 ts=8 et :vim
" vxoccur_defaults.vim - custom 'routine' definitions for various filetypes
"
" Author: Marko Mahnič
" Created: November 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

" TODO: move vxoccur_defaults to ftplugins (bib/, html/, slice/, ...)

if vxlib#plugin#StopLoading('#au#vimuiex#vxoccur_defaults')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
function! vimuiex#vxoccur_defaults#Init()
endfunc

function! s:ReWords(words, delim)
   let w = split(a:words, a:delim)
   return '\%(' . join(w, '\|') . '\)'
endfunc

function! s:DefRoutines(ftype, regexp, call)
   if has_key(g:vxoccur_routine_def, a:ftype) == 0
      let g:vxoccur_routine_def[a:ftype] = { 'regexp': a:regexp }
      if len(a:call) > 0
         let g:vxoccur_routine_def[a:ftype]['call'] = a:call
      endif
   endif
endfunc

call s:DefRoutines('html', '\c\%(\%(<h\d>\s*\S\+\)\|\%(<div\s\+id=\)\)', '')
call s:DefRoutines('apache',
   \ '^\s*<' 
   \     . s:ReWords('Directory\%(Match\)\?|Files\%(Match\)\?|Location\%(Match\)\?|VirtualHost', '|')
   \     . '\W'
   \     . '\|^\s*' . '\(\%(WSGI\)\?Script\)\?Alias\%(Match\)\?' . '\W',
   \ '')
call s:DefRoutines('python', '^\s*' . s:ReWords('class def', ' ') . '\W', '')
call s:DefRoutines('slice',
   \ '\(^\s*' . s:ReWords('class|interface|struct|enum|sequence|module', '|') . '\W\)', '')
call s:DefRoutines('vim', '\(^\s*\(s:\)\?' . s:ReWords('func|function', '|') . '!\?\W\)', '')
call s:DefRoutines('xhtml', g:vxoccur_routine_def['html'], '')


"================================================================= 
" LATEX
"================================================================= 
call s:DefRoutines('tex', '^\s*\\\%(title\|\%(sub\)*section\){', 'vimuiex#vxoccur_defaults#ExtractLatex')
function! vimuiex#vxoccur_defaults#ExtractLatex()
   let ln = getline('.')
   if match(ln, '^\s*\\title{') >= 0
      let text = matchstr(ln, '^\s*\\title{\s*\zs[^}]*\ze')
   elseif match(ln, '^\s*\\\%(sub\)*section{') >= 0
      let level_text = substitute(ln, '^\s*\\\(\%(sub\)*\)section{\s*\([^}]*\).*$', '\1}\2', '')
      let [level, text] = split(level_text, '}', 1)
      let ll = len(level) / 3
      let text = printf('%*s%s', ll, '', text)
   else 
      let text = '?'
   endif
   return text
endfunc

"================================================================= 
" BIBTEX
"================================================================= 
call s:DefRoutines('bib', '^@\w\+\zs{.*$', 'vimuiex#vxoccur_defaults#ExtractBib')
function! vimuiex#vxoccur_defaults#ExtractBib()
   let lnstart = line('.')
   let bibtype = matchstr(getline(lnstart), '\zs@\w\+\ze{')
   if tolower(bibtype) == '@comment' | return "" | endif
   let bibitem = matchstr(getline(lnstart), '@\w\+{\zs[^,]\+\ze\(,\|$\)')
   norm 0f{
   let [lnend, ecol] = searchpairpos('{', '', '}', 'W')
   if lnend < lnstart
      return '(' . bibitem . ') [warning: unmatched braces in bibitem]'
   endif

   let title = s:BibExtractField('title', lnstart, lnend)
   let author = s:BibExtractField('author', lnstart, lnend)
   let author = substitute(author, '\s\+and\s\+', '; ', 'g')
   let author = substitute(author, '\\.{\(\w\)}', '\1', 'g')
   let author = substitute(author, '\\.{\\\(\w\)}', '\1', 'g')
   let author = substitute(author, '{\\.}', '', 'g')
   let author = substitute(author, '\\', '', 'g')

   return author . ': ' . title . ' (' . bibitem . ')'
endfunc

function! s:BibExtractField(fldname, lnstart, lnend)
   " lnstart, lnend - start and end of bibitem
   exec 'norm ' . a:lnstart . 'gg'
   let [ln1, col1] = searchpos('^\s*' . a:fldname . '\s*=\s*\zs{', 'W', a:lnend)
   if ln1 < 1
      return ''
   else
      let [ln2, col2] = searchpairpos('{', '', '}', 'W')
      if ln2 < 1
         return getline(ln1)
      else
         let lines = getline(ln1, ln2)
         let n = len(lines) - 1
         let lines[n] = strpart(lines[n], 0, col2-1)
         let lines[0] = strpart(lines[0], col1)
         return join(lines, " ")
      endif
   endif
endfunc

"================================================================= 
" D
"================================================================= 
let s:dclass = '^\s*\%(class\|struct\)\s'
let s:dfunc = '^\s*\%(\w\S*\)\%(\_s\w\S*\)*\_s*(\_[^)]*)\_s*{'
let s:dkwds = s:ReWords('if|for|foreach|while|catch|do', '|')
call s:DefRoutines('d', '\m^\s*\%(\%(' . s:dclass . '\)\|\%(' . s:dfunc . '\)\)',
      \ 'vimuiex#vxoccur_defaults#ExtractD')
function! vimuiex#vxoccur_defaults#ExtractD()
   let lnstart = line('.')
   let line = getline(lnstart)
   if line =~ s:dclass | return line | endif
   if line =~ '^\s*\%(' . s:dkwds . '\)' | return '' | endif
   return line
endfunc

"================================================================= 
" Cleanup
delfunc s:ReWords
delfunc s:DefRoutines

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <FTPLUGIN id="vxoccur#routine-defaults" filetype="html,xthml,tex,bib,vim,python,slice,apache">
   call vimuiex#vxoccur_defaults#Init()
" </FTPLUGIN>
