" vim: fileencoding=utf-8
" modpython.vim - Prepare vim/python to use loadable modules
"
" Author: Marko Mahnič
" Created: April 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" Intended use:
" function ExampleUsesPythonModule()
"    call modpython#prepare()
"    python << EOF
"    import my_vim_module   # my_vim_module.py installed in ~/.vim/modpython
"    ...
"    EOF
" endfunc

if exists("g:modpythonscript_loaded") && g:modpythonscript_loaded
   finish
endif
let g:modpythonscript_loaded = 1

" Add ~/.vim/modpython to python search path.
" Vim-python modules should be installed in ~/.vim/modpython
" TODO: maybe add system-wide modules
function! modpython#prepare()
   if has('python') && !exists("s:pypath")
      let s:pypath = globpath(&runtimepath, "modpython")
      python import sys
      exec "python sys.path.append(r'" . s:pypath . "')"
   endif
endfunc

