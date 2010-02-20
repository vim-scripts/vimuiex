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
   return '\(' . join(w, '\|') . '\)'
endfunc

function! s:DefRoutines(ftype, regexp, call)
   if has_key(g:vxoccur_routine_def, a:ftype) == 0
      let g:vxoccur_routine_def[a:ftype] = { 'regexp': a:regexp }
      if len(a:call) > 0
         let g:vxoccur_routine_def[a:ftype]['call'] = a:call
      endif
   endif
endfunc

call s:DefRoutines('html', '\c\(\(<h\d>\s*\S\+\)\|\(<div\s\+id=\)\)', '')
call s:DefRoutines('apache',
   \ '^\s*<' 
   \     . s:ReWords('Directory\(Match\)\?|Files\(Match\)\?|Location\(Match\)\?|VirtualHost', '|')
   \     . '\W'
   \     . '\|^\s*' . '\(\(WSGI\)\?Script\)\?Alias\(Match\)\?' . '\W',
   \ '')
call s:DefRoutines('python', '^\s*\(' . s:ReWords('class def', ' ') . '\)\W', '')
call s:DefRoutines('slice',
   \ '\(^\s*\(' . s:ReWords('class|interface|struct|enum|sequence|module', '|') . '\)\W\)', '')
call s:DefRoutines('vim', '\(^\s*\(s:\)\?' . s:ReWords('func|function', '|') . '!\?\W\)', '')
call s:DefRoutines('xhtml', g:vxoccur_routine_def['html'], '')

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
" Cleanup
delfunc s:ReWords
delfunc s:DefRoutines
