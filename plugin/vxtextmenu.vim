" vim: set fileencoding=utf-8 sw=3 ts=8 et
" vxtextmenu.vim - display menus in text mode
"
" Author: Marko Mahnič
" Created: April 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; works only in terminal; using curses)

if exists("g:vxtextmenu_loaded") && g:vxtextmenu_loaded
   finish
endif
let g:vxtextmenu_loaded = 1

function! s:getMenu()
   " TODO: select the correct menu depending on current mode
   redir => mns
   exec 'silent nmenu'
   redir END
   let lmns = split(mns, '\n')
   let themenu = []
   for line in lmns
      let text = ""
      let cmd = ""
      let mtitle = matchstr(line, '^\s*\d\+\s\+.\+') | " space digit space any
      if mtitle != ""
         call add(themenu, mtitle)
      endif
   endfor
   unlet lmns
   return themenu
endfunc

map <SID>xx <SID>xx
let s:SID = substitute(maparg('<SID>xx'), '<SNR>\(\d\+_\)xx$', '\1', '')
unmap <SID>xx

" TODO: Remove some top-level entries from the menu (Toolbar, Popup)
" TODO: Implement a pop-up context menu for textmode
function! VxTextMenu()
   call modpython#prepare()

exec 'python VIM_SNR_VXTEXTMENU="<SNR>' . s:SID .'"'
python << EOF
import vim
import vimuiex.textmenu as menu
Menu = menu.CTextMenu(align="TL", autosize="VH")
Menu.loadMenuItems("%sgetMenu()" % VIM_SNR_VXTEXTMENU)
# Menu.cmdAccept = "call ...({{i}})" # No effect for menus
Menu.process(curindex=0)
Menu=None
EOF

endfunc

