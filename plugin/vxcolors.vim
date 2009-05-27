" vim: fileencoding=utf-8
" vxcolours.vim - default colors for popup list
"
" Author: Marko Mahnič
" Created: May 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if exists("g:vxcolor_loaded") && g:vxcolor_loaded
	finish
endif
let g:vxcolor_loaded = 1

hi def VxNormal term=reverse cterm=reverse guibg=DarkGrey
hi def VxSelected term=NONE cterm=NONE guifg=White guibg=Black
hi def VxQuickChar term=reverse,standout cterm=reverse ctermbg=1 guibg=DarkGrey guifg=White

