" vim: set fileencoding=utf-8 sw=3 ts=8 et:vim
" vxlist.vim - a generic popup list implementation
"
" Author: Marko Mahnič
" Created: October 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.
"
" (requires python; works only in terminal; using curses)

if vxlib#plugin#StopLoading('#au#vimuiex#vxlist')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
exec vxlib#plugin#MakeSID()
let s:_VxPopupList_DefaultPos = 'position=c autosize=vh minsize=20,4 size=0.5,0.5'
" =========================================================================== 

let s:items = []
let s:SelectedIndex = -1
let s:MarkedItems = []

function! s:GetItems()
   return s:items
endfunc

" TODO: instead of multiple variables, SelectItem could recieve a dictionary:
"     "s": selected ...,  "M": markded ..., etc.
"     The contnents of the dictionary would depend on the optional variable
"     "returns" that is passed to VxPopup() and then to CList (expandVimCommand)
"     eg: "returns": "s,M,pwd"
function! s:SelectItem(index)
   let s:SelectedIndex = a:index
   " let s:MarkedItems = a:marked
endfunc

function! s:CreateKeymaps(listvar, params)
   let kkey = '' | let kfunc = '' | let keymap = []
   let modes = {
      \ 'keymap': 'keymapNorm', 'keymap/': 'keymapFilter',
      \ 'keymap#': 'keymapNumSelect', 'keymap&': 'keymapQuickChar' }

   for param in keys(a:params)
      if param !~ 'keymap' | continue | endif
      if ! has_key(modes, param) | continue | endif
      try
         let keymap = a:params[param]
      catch /.*/
         echom 'Error: parameter must be a list: ' . param
         continue
      endtry
      let kmode = modes[param]
      let kvar = a:listvar . '.' . kmode
      let i = 0
      for kdef in keymap
         let i += 1
         try
            let [kkey, kfunc] = kdef
         catch /.*/
            echom 'Error: in key definition (' . param . ')-' . i
            continue
         endtry
         try
            exec 'python ' . kvar . '.setKey("' . escape(kkey, '"\') . '", "' . escape(kfunc, '"\') . '")'
         catch /.*/
            echom 'Error: defining key (' . param . ') "' . escape(kkey, '"\') . '" in python'
            continue
         endtry
      endfor
   endfor
endfunc

" Optional parameters in dictionary a:1
"     a:1['optid'] -> options for listbox positioning
"     a:1['init'] - initialization function name: function cb(pyListName);
"           called just before process()
"     a:1['callback'] - callback expression for the 'accept' action
"     a:1['callback_cancel'] - callback expression for the 'cancel' action
"     a:1['prompt'] - the prompt to be displayed in the command line
"     a:1['current'] - index of initially selected item
"     a:1['marked'] - list of initially marked items indices;
"           TODO: CList.setMarkedItems()
"     a:1['columns'] -> number of aligned columns (currently max 1)
"     a:1['keymap*'] -> define (additional) keymap for mode *; list of key mappings
"           '*' is one of '', '/', '&', '#'
"           A key mapping is a list [keyname, popup-command]
"           See also CreateKeymaps.
" TODO: a:1['returns'] -> 's,M,pwd' etc.; valid when callback isn't defined
" TODO: a:1['position'] -> overrides optid
function! vimuiex#vxlist#VxPopup(items, title, ...)
   let s:items = a:items
   let s:SelectedIndex = -1
   let s:MarkedItems = []
   let default_callback = s:SNR . 'SelectItem({{i}})'
   let callback = default_callback
   let cbcancel = ''
   let cbinit = ''
   let prompt = ''
   let returns = 's'
   let optid = ''
   let current = 0
   let columns = 0
   if a:0 > 0
      if has_key(a:1, 'optid') | let optid = a:1['optid'] | endif
      if has_key(a:1, 'init') 
         try
            let cbinit = a:1['init']
            if ! exists('*' . cbinit) | let cbinit = '' | endif
         catch /.*/
            let cbinit = ''
         endtry
      endif
      if has_key(a:1, 'callback') 
         try
            let cbexpr = a:1['callback']
            let cbname = matchstr(cbexpr, '^\s*\zs[^(]\+\ze\((\|$\)') " extract cb name till ( or $
            if exists('*' . cbname) | let callback = cbexpr | endif
         catch /.*/
            echom 'VxPopup ('. optid . '): callback does not exist.'
         endtry
      endif
      if has_key(a:1, 'callback_cancel') 
         try
            let cbexpr = a:1['callback_cancel']
            let cbname = matchstr(cbexpr, '^\s*\zs[^(]\+\ze\((\|$\)') " extract cb name till ( or $
            if exists('*' . cbname) | let cbcancel = cbexpr | endif
         catch /.*/
            echom 'VxPopup ('. optid . '): callback does not exist.'
         endtry
      endif
      if has_key(a:1, 'prompt') | let prompt = a:1['prompt'] | endif
      if has_key(a:1, 'current') | let current = a:1['current'] | endif
      if has_key(a:1, 'columns') | let columns = a:1['columns'] | endif
      " TODO if has_key(a:1, 'marked') 
      " TODO if has_key(a:1, 'returns') | let returns = a:1['returns'] | endif
   endif
   if optid == ''
      let optid = substitute(a:title, '[^a-zA-Z0-9_]', '_', 'g')
      let optid = 'VxPopup-'
   else
      let optid = substitute(optid, '[^a-zA-Z0-9_]', '_', 'g')
   endif
   let optid = substitute(optid, '_\+', '_', 'g')

   python import vim, vimuiex.popuplist as lister

   exec 'python List = lister.CList(title="'. escape(a:title, '"\') .'", optid=r"' . optid . '")'
   if prompt != ''
      exec 'python List.prompt="' . escape(prompt, '"\') . '"'
   endif

   if a:0 > 0
      call s:CreateKeymaps('List', a:1)
   endif

   exec 'python def SNR(s): return s.replace("$SNR$", "' . s:SNR . '")'
   python List.loadVimItems(SNR("$SNR$GetItems()"))
   exec 'python List.cmdAccept="' . escape(callback, '"\') . '"'
   exec 'python List.cmdCancel="' . escape(cbcancel, '"\') . '"'
   if columns > 0
      python List._firstColumnAlign = True
   endif
   if cbinit != ''
      exec 'call ' . cbinit . '("List")'
   endif
   exec 'python List.process(curindex=' . current . ')'
   python List=None

   let s:items = []
   if callback == default_callback
      return [s:SelectedIndex, s:MarkedItems]
   else
      return []
   endif
endfunc

" Plugin Box Position settings
"   VxPopupListPos - user settings in .vimrc
"   _VxPopupListPosDefault - plugin settings in code
"
" Each setting is a dictionary entry formatted like a :set command.
" Flagged settings can be modified with += / -=. Other settings can only be
" replaced with =.
"
" Options are parsed in python. Settings are merged in this order:
"   1. s:_VxPopupList_DefaultPos
"   2. g:VxPopupListPos["default"]
"   3. g:_VxPopupListPosDefault["plugin-id"]
"   4. g:VxPopupListPos["plugin-id"]

function! vimuiex#vxlist#GetPosOptions(optid)
   let opts = [s:_VxPopupList_DefaultPos]
   if exists('g:VxPopupListPos') && has_key(g:VxPopupListPos, 'default')
      call add(opts, g:VxPopupListPos['default'])
   endif
   if exists('g:_VxPopupListPosDefault') && has_key(g:_VxPopupListPosDefault, a:optid)
      call add(opts, g:_VxPopupListPosDefault[a:optid])
   endif
   if exists('g:VxPopupListPos') && has_key(g:VxPopupListPos, a:optid)
      call add(opts, g:VxPopupListPos[a:optid])
   endif
   return join(opts, ' ')
endfunc

function! s:MakeGui(bg, fg)
   return " guibg=" . a:bg . " guifg=" . a:fg
endfunc
function! s:MakeCTerm(bg, fg)
   return " ctermbg=" . a:bg . " ctermfg=" . a:fg
endfunc

function! vimuiex#vxlist#CheckHilightItems()
   let bg0 = "DarkGray"
   let bg1 = "Black"
   let bt0 = "LightGray"
   let bt1 = "Black"
   exec "hi def VxNormal term=reverse" . s:MakeCTerm(bt0, "Black") . s:MakeGui(bg0, "Black")
   exec "hi def VxSelected term=NONE" . s:MakeCTerm(bt1, "LightGray") . s:MakeGui(bg1, "White")
   exec "hi def VxQuickChar term=reverse,standout" . s:MakeCTerm(bt0, "DarkRed") . s:MakeGui(bg0, "White")
   exec "hi def VxMarked term=reverse,standout" . s:MakeCTerm(bt0, "DarkRed") . s:MakeGui(bg0, "Yellow")
   exec "hi def VxSelMarked term=NONE" . s:MakeCTerm(bt1, "DarkRed") . s:MakeGui(bg1, "Yellow")
   exec "hi def VxTitle term=reverse" . s:MakeCTerm(bt0, "DarkBlue") . s:MakeGui(bg0, "Blue")
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxlist#init">
   call s:CheckSetting('g:VxPopupListPos', '{}')
   call s:CheckSetting('g:_VxPopupListPosDefault', '{}')
" </VIMPLUGIN>
