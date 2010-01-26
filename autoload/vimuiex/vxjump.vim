" vim: set fileencoding=utf-8 sw=3 ts=8 et:vim
" jump.vim - quick jumping around
"
" Author: Marko Mahnič
" Created: June 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; requires python_screen vim patch)

if vxlib#plugin#StopLoading('#au#vimuiex#vxjump')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
" exec vxlib#plugin#MakeSID()
" =========================================================================== 

function! vimuiex#vxjump#VxLineJump()
" exec 'python VIM_SNR_VXTEXTMENU="' . s:SNR .'"'

python << EOF
import vim
import vimuiex.jumping as vxjmp
Jump = vxjmp.CLineJump()
Jump.process()
Jump=None
EOF

endfunc

function! vimuiex#vxjump#VxWindowJump()
" exec 'python VIM_SNR_VXTEXTMENU="' . s:SNR .'"'

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

" <VIMPLUGIN id="vimuiex#vxjump" require="python&&python_screen">
   command VxLineJump call vimuiex#vxjump#VxLineJump()
   command VxWindowJump call vimuiex#vxjump#VxWindowJump()
" </VIMPLUGIN>

