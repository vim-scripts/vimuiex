" vim: set fileencoding=utf-8 sw=3 ts=8 et
" vxtextmenu.vim - display menus in text mode
"
" Author: Marko Mahnič
" Created: April 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; works only in terminal; using curses)

if vxlib#plugin#StopLoading('#au#vimuiex#vxtextmenu')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
exec vxlib#plugin#MakeSID()
" In console the menu might not have been loaded
runtime! menu.vim
" =========================================================================== 

function! s:GetMenu(menuPath, vimmode)
   return vxlib#menu#GetMenuTitles(a:menuPath, a:vimmode)
endfunc

let s:LastVisual = ''
function! s:SelectMenu_cb(menupath, mode)
   " execute emenu for mode that was active before menu was activated
   if a:mode == 'i'
      exec "norm! i<c-o>emenu " . a:menupath
   elseif a:mode == 'v' && s:LastVisual != ''
      if s:LastVisual != ''
         exec "norm! `<" . s:LastVisual . "`>"
         let s:LastVisual = ''
      endif
      exec "norm! :`<,`>emenu " . a:menupath
   else
      exec 'emenu ' . a:menupath
   endif
   return 'q'
endfunc

" TODO: Remove some top-level entries from the menu (Toolbar, Popup)
" TODO: Implement a pop-up context menu for textmode
function! vimuiex#vxtextmenu#VxTextMenu(menu, mode, ...)
   exec 'python def SNR(s): return s.replace("$SNR$", "' . s:SNR . '")'
   if a:0 < 1 | let s:LastVisual = ''
   else | let s:LastVisual = a:1
   endif

python << EOF
import vim
import vimuiex.textmenu as menu
Menu = menu.CTextMenu(optid="VxTextMenu")
EOF
   exec 'python Menu.loadMenuItems(SNR("$SNR$GetMenu(''' . a:menu . ''',''' . a:mode . ''')"))'
   exec 'python Menu.cmdAccept = SNR("$SNR$SelectMenu_cb({{menupath}},''' . a:mode . ''')")'
python << EOF
Menu.process(curindex=0)
Menu=None
EOF

endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxtextmenu" require="python&&(!gui_running||python_screen)">
   command VxTextMenu call vimuiex#vxtextmenu#VxTextMenu('','n')
   nmap <silent><unique> <Plug>VxTextMenu :call vimuiex#vxtextmenu#VxTextMenu('','n')<cr>
   imap <silent><unique> <Plug>VxTextMenu <Esc>:call vimuiex#vxtextmenu#VxTextMenu('','i')<cr>
   vmap <silent><unique> <Plug>VxTextMenu :<c-u>call vimuiex#vxtextmenu#VxTextMenu('','v',visualmode())<cr>
" </VIMPLUGIN>
