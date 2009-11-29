" vim: set fileencoding=utf-8 sw=3 ts=8 et
" vxtextmenu.vim - display menus in text mode
"
" Author: Marko Mahnič
" Created: April 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; works only in terminal; using curses)

if vxlib#plugin#StopLoading("#au#vimuiex#vxtextmenu")
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
map <SID>xx <SID>xx
let s:SID = substitute(maparg('<SID>xx'), '<SNR>\(\d\+_\)xx$', '\1', '')
unmap <SID>xx
" =========================================================================== 

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

" TODO: Remove some top-level entries from the menu (Toolbar, Popup)
" TODO: Implement a pop-up context menu for textmode
function! vimuiex#vxtextmenu#VxTextMenu()
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

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxtextmenu" require="python&&(!gui_running||python_screen)">
   command VxTextMenu call vimuiex#vxtextmenu#VxTextMenu()
" </VIMPLUGIN>
