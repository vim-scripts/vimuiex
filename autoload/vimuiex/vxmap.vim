" vim:set fileencoding=utf-8 sw=3 ts=8 et
" vxmap.vim - change mappings on a set of keys for quick reuse
"
" Author: Marko Mahnič
" Created: May 2010
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

" Example:
"   Ctrl-F5 shows a menu:
"    cprev/cnext
"    lprev/lnext
"    VxCPrev/VxCNext
"    ...
"  
"   User selects. The commands are mapped to keys F5/F6/F7
"
" More than two keys can be mapped. User-defined set of keys. User-defined
" menu activation key. Additional entries can be added to menu. Multiple sets
" of keys, multiple sets of commands.

if vxlib#plugin#StopLoading('#au#vimuiex#vxmap')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
exec vxlib#plugin#MakeSID()
" =========================================================================== 

let s:QuickKeys = { 'default': ['<F5>', '<F6>', '<F7>'] }
let s:QuickCommands = { 'default': [
         \ [ '&Buffer prev/next', [':bprev<cr>', ':bnext<cr>']],
         \ [ '&Tab prev/next', [':tabprev<cr>', ':tabnext<cr>']],
         \ [ '&cprev/cnext', [':cprev<cr>', ':cnext<cr>']],
         \ [ '&lprev/lnext', [':lprev<cr>', ':lnext<cr>']],
         \ [ '&VxCPrev/VxCNext', [':VxCPrev<cr>', ':VxCNext<cr>', ':VxOccurSelectHist<cr>']]
         \ ]}

" Add new settings to a dictionary of settings (merge two dictionaries).
" If a key is present in oldd and newd, the items from the newd entry
" will be merged into the oldd entry. If a key in newd ends with '!',
" the entry in oldd will be replaced by the entry in newd.
function! s:MergeSettings(oldd, newd)
   for key in keys(a:newd)
      let replace = 0
      let oldkey = key
      if key =~ '!$'
         let replace = 1
         let oldkey = substitute(key, '!$', '', '')
      endif
      if replace || !has_key(a:oldd, oldkey)
         let a:oldd[oldkey] = a:newd[key]
      else
         for item in a:newd[key]
            call add(a:oldd[oldkey], item)
         endfor
      endif
   endfor
endfunc

function! s:CheckExtraSettings()
   if exists('g:vxmap_quick_keys') 
      if !empty(g:vxmap_quick_keys)
         call s:MergeSettings(s:QuickKeys, g:vxmap_quick_keys)
      endif
      unlet g:vxmap_quick_keys
   endif
   if exists('g:vxmap_quick_commands')
      if !empty(g:vxmap_quick_commands)
         call s:MergeSettings(s:QuickCommands, g:vxmap_quick_commands)
      endif
      unlet g:vxmap_quick_commands
   endif
endfunc

function! s:DoInstall(keyset, commandset, index)
   let keys = s:QuickKeys[a:keyset]
   let cmds = s:QuickCommands[a:commandset][a:index][1]
   let i = 0
   for cmd in cmds
      if i >= len(keys) | break | endif
      exec 'nmap <silent>' . keys[i] . ' ' . cmd
      exec 'imap <silent>' . keys[i] . ' <Esc>' . cmd
      exec 'vmap <silent>' . keys[i] . ' <Esc>' . cmd
      let i = i + 1
   endfor
endfunc

function! vimuiex#vxmap#InstallKeys(keyset, commandset)
   if !has('menu') | return | endif

   call s:CheckExtraSettings()
   let cmds = s:QuickCommands[a:commandset]

   let name = ']InstallKeys'

   try | exec 'nunmenu ' . name
   catch /.*/
   endtry

   let i = 0
   let params = "'" . a:keyset . "','" . a:commandset . "',"
   for cmd in cmds
      exec 'nmenu <silent> ' . name . '.' . escape(cmd[0], ' \') 
               \ . ' :call ' . s:SNR . 'DoInstall(' . params . i . ')<cr>'
      let i = i + 1
   endfor

   call vxlib#menu#DoVimMenu(name, g:vxmap_quick_menu)
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxmap#quickkeys" require="menu">
   " use 'default' to append; use 'default!' to replace
   " each list item is: ['key', 'key', ...]
   call s:CheckSetting('g:vxmap_quick_keys', "{'default!': ['<F5>', '<F6>', '<F7>']}")

   " dictionary of lists; use 'default' to append; use 'default!' to replace
   " each list item is: ['menu entry', ['command', 'command', ...]]
   call s:CheckSetting('g:vxmap_quick_commands', "{'default': []}")

   " vimuiex/popup(/choice, not yet)
   call s:CheckSetting('g:vxmap_quick_menu', "'vimuiex'")

   nmap <silent><unique> <Plug>VxMapDefaultKeys :call vimuiex#vxmap#InstallKeys('default','default')<cr>
   imap <silent><unique> <Plug>VxMapDefaultKeys <Esc>:call vimuiex#vxmap#InstallKeys('default','default')<cr>
   vmap <silent><unique> <Plug>VxMapDefaultKeys <Esc>:call vimuiex#vxmap#InstallKeys('default','default')<cr>
" </VIMPLUGIN>

