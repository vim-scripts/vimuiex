" vim:set fileencoding=utf-8 sw=3 ts=3 et
" vxgrep.vim - a vimgrep extension
"
" Author: Marko Mahnič
" Created: January 2010
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python)
"
" This is only a proof of concept.

function! s:Complete_Pattern(ArgLead, CmdLine, CursorPos)
endfunc

function! s:Complete(ArgLead, CmdLine, CursorPos)
   let aarg = a:ArgLead
   if len(aarg) < 0 | return [aarg] | endif
   if aarg[0] == '+'
      let opts = ['b', 'B', 'd', 'D', 'w', 'W', 'P']
      " TODO: popuplist position must be above the status line, at a:CursorPos, aligned at the bottom
      let [idopt, marked] = vimuiex#vxlist#VxPopup(opts, 'VGrep Scope',
         \ { 'prompt': ':' . a:CmdLine }
         \ )
      if len(marked) > 0
         for idopt in marked
            let aarg = aarg . opts[idopt]
         endfor
      elseif idopt >= 0
         let aarg = aarg . opts[idopt]
      endif
   elseif aarg[0] == '/'
      let lshist = vxlib#hist#GetHistory('/')
      call filter(lshist, 'v:val != ""')
      let lsexp = []
      for eexp in ['<cword>', '<cWORD>', '<cfile>:t', '<cfile>:e', '<cfile>', '%:t', '%:e', '%']
         try
            let aw = expand(eexp)
            if aw != "" && index(lsexp, aw) < 0 | call add(lsexp, aw) | endif
         catch /.*/
            continue
         endtry
      endfor
      let strs = lsexp + lshist
      if len(strs) > 0
         let [idopt, marked] = vimuiex#vxlist#VxPopup(strs, 'VGrep Expression',
            \ { 'prompt': ':' . a:CmdLine }
            \ )
         if idopt >= 0
            let aarg = aarg . strs[idopt]
         endif
      endif
   endif
   return [aarg]
endfunc

function! vimuiex#vxgrep#Test()
   command -nargs=* -complete=customlist,s:Complete Vgrep echo "Done"
endfunc
