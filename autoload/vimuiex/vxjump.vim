" vim: set fileencoding=utf-8 sw=3 ts=8 et:vim
" jump.vim - quick jumping around
"
" Author: Marko Mahnič
" Created: June 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; works only in terminal; using curses)

if vxlib#plugin#StopLoading("#au#vimuiex#vxjump")
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
"map <SID>xx <SID>xx
"let s:SID = substitute(maparg('<SID>xx'), '<SNR>\(\d\+_\)xx$', '\1', '')
"unmap <SID>xx
" =========================================================================== 

function! vimuiex#vxjump#VxLineJump()
" exec 'python VIM_SNR_VXTEXTMENU="<SNR>' . s:SID .'"'

python << EOF
import vim
import vimuiex.jumping as vxjmp
Jump = vxjmp.CLineJump()
Jump.process()
Jump=None
EOF

endfunc

function! vimuiex#vxjump#VxWindowJump()
" exec 'python VIM_SNR_VXTEXTMENU="<SNR>' . s:SID .'"'

python << EOF
import vim
import vimuiex.jumping as vxjmp
Jump = vxjmp.CWindowJump()
Jump.process()
Jump=None
EOF

endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxjump" require="python&&(!gui_running||python_screen)">
   command VxLineJump call vimuiex#vxjump#VxLineJump()
   command VxWindowJump call vimuiex#vxjump#VxWindowJump()
" </VIMPLUGIN>

