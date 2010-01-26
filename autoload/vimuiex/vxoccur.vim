" vim: set fileencoding=utf-8 sw=3 ts=8 et :vim
" vxoccur.vim- display the occurences of a search pattern in a popup list
"
" Author: Marko Mahnič
" Created: September 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#plugin#StopLoading('#au#vimuiex#vxoccur')
   finish
endif

" =========================================================================== 
" Local Initialization - on autoload
" =========================================================================== 
call vxlib#python#prepare()
exec vxlib#plugin#MakeSID()
call vimuiex#vxoccur_defaults#Init()
" =========================================================================== 

let s:capture = []
let s:capWord = ""
let s:capMatch = ""
function! s:GetOccurCapture()
   return s:capture
endfunc

function! s:InitTr()
   let s:trFrom = ''
   let s:trTo = ''
   for i in range(32)
      if i == 0 || i == 8 | continue | endif
      let s:trFrom = s:trFrom . nr2char(i)
      let s:trTo = s:trTo . ' '
   endfor
endfunc
call s:InitTr()

function! s:AddOccurenceLine()
   let n = len(s:capture)
   let trline = tr(getline('.'), s:trFrom, s:trTo)
   let s:capture += [printf(' %2d: %3d %s', n, line('.'), trline)]
endfunc

function! s:AddOccurenceLineF(funcname)
   " echom 'Adding'
   exec 'let txt = ' . a:funcname . '()'
   if txt == '' | return | endif
   let n = len(s:capture)
   let pos = line('.')
   let trline = tr(txt, s:trFrom, s:trTo)
   let s:capture += [printf(' %2d: %3d %s', n, pos, trline)]
endfunc

" Asks the user to define a search range:
"   -b - current buffer
"   -d [filemask, ...] - current buffer directory
"   -D [filemask, ...] - current buffer directory and subdirectories
"   -w [filemask, ...] - working directory
"   -W [filemask, ...] - working directory and subdirectories
"   TODO: .B - listed buffers
"
" NOTES:
" Entries may start with '-'. To use the previous search range (displayed in
" []), enter '-' (default value). The prefix '-' is used because input() can't
" distinguish between an empty string and a cancelled input.
function! s:GetSearchRange()
   call inputsave()
   let hinp = vxlib#hist#GetHistory('input')
   call vxlib#hist#CopyHistory('occurrange', 'input')
   let default = histget('input', -1)
   if default == '' | let default = 'b' | endif
   if len(default) < 12 | let disp = default
   else | let disp = default[:11] . ' ...'
   endif
 
   " range: b buffer, d ... buffer directory, w ... working directory, ...
   let range = input('Range (bdDwW)[' . disp . ']: ', '-')
   call vxlib#hist#SetHistory('input', hinp)
   call inputrestore()

   if range == '' | return '' | endif
   if match(range, '^\s*-\s*$') >= 0 | let range = default
   endif
   let range = matchstr(range, '^\s*-*\zs.*$')

   call vxlib#hist#AddHistory('occurrange', '-' . range)
   return range
endfunc

" Prepares and executes a vimgrep command
" Stores search results in s:capture (copied from QuickFix list)
" TODO: shoud it use location list and clean it aferwards?
function! s:VimGrepFiles(word, range)
   let type = a:range[0]
   let filter = split(a:range[1:])
   if len(filter) < 1 | let filter = ['*'] | endif

   let saveic=&ignorecase
   set noignorecase
   if type == 'd' || type == 'D' | let dir = '%:p:h'
   elseif type == 'w' || type == 'W' | let dir = getcwd()
   else | let dir = '.'
   endif
   if type == 'W' || type == 'D' | let dirsep = '/**/'
   else | let dirsep = '/' | endif
   let &ignorecase = saveic

   let vgexpr = '1000vimgrep /' . a:word . '/j'
   for af in filter
      " TODO: d+../.. - additional base path defined with type; completion;
      "       d=absolute path; completion
      let vgexpr = vgexpr . ' ' . dir . dirsep . af
   endfor

   try
      exec vgexpr
   catch /E480/
   endtry
   let [dummy, s:capture] = vimuiex#vxquickfix#TransformQfItems(getqflist())
endfunc

function! vimuiex#vxoccur#VxOccur()
   call inputsave()
   let l:hinp = vxlib#hist#GetHistory('input')
   call vxlib#hist#CopyHistory('search', 'input')
   let s:capWord = expand("<cword>")
   if s:capWord != ''
      call histadd('input', s:capWord)
   endif
   let s:capWord = input('Find occurences:/') " , getreg('/')
   call vxlib#hist#SetHistory('input', l:hinp)
   call inputrestore()
   if s:capWord != '' 
      call histadd('search', s:capWord)
   else
      return
   endif

   let range = s:GetSearchRange()
   if range == '' | return | endif

   if match(range[0], '\C[dDwW]') >= 0
      call s:VimGrepFiles(s:capWord, range)
      let title = 'Vimgrep: ' . s:capWord
   else
      let s:capMatch = s:capWord
      let s:capture = [bufname('%')]
      let l:curpos = getpos('.')
      norm! gg
      silent execute 'g/' . s:capMatch . '/call s:AddOccurenceLine()'
      call setpos('.', l:curpos)
      let title = 'Buffer search: ' . s:capWord
   endif
   if len(s:capture) < 2
      echo 'No occurences of "' . s:capWord . '" were found.'
      return
   endif

   call s:VxShowCapture('VxOccur', title)
endfunc

function! vimuiex#vxoccur#VxOccurCurrent()
   try
      let s:capture = vxlib#cmd#Capture('norm! [I', 1)
      let s:capWord = expand('<cword>')
      let s:capMatch = '\c\<' . s:capWord . '\>'
   catch /^Vim\%((\a\+)\)\=:E349/
      let s:capture = ['Error: No identifier under cursor.']
      let s:capWord = '<>'
      let s:capMatch = '^$'
   endtry
   call s:VxShowCapture('VxOccurCurrent', 'Tag search: ' . s:capWord)
endfunc

function! vimuiex#vxoccur#VxOccurRoutines()
   let l:dict = g:vxoccur_routine_def
   if has_key(l:dict, &ft) != 1
      echom 'Routine regexp not defined for ft=' . &ft
   else
      let s:capture = [bufname('%')]
      let title = 'Routines, ft=' . &ft
      let s:capMatch = l:dict[&ft].regexp
      let gcmd = 'call s:AddOccurenceLine()'
      if has_key(l:dict[&ft], 'call') == 0
         let gcmd = 'call s:AddOccurenceLine()'
      else
         let gcmd = l:dict[&ft]['call']
         if exists('*' . gcmd)
            let gcmd = "call s:AddOccurenceLineF('" . gcmd . "')"
            " echom "VxOccurRoutines: callback=" . gcmd
         else
            echom "VxOccurRoutines: Undefined callback '" . gcmd . "'"
            let gcmd = 'call s:AddOccurenceLine()'
         endif
      endif
      let curpos = getpos('.')
      norm! gg
      silent execute 'g/' . s:capMatch . '/' . gcmd
      call setpos('.', curpos)
      call s:VxShowCapture('VxOccurRoutines', title)
   endif
endfunc

function! vimuiex#vxoccur#VxOccurTags()
   let s:capture = [bufname('%')]
   let title = 'Tags'
   let s:capMatch = ''
   let cmd = 'ctags -f - --format=2 --excmd=pattern --fields=nks --sort=no'
   let filename = fnamemodify(bufname('%'), ':p')
   let cmdout = system(cmd . ' ' . filename)
   let taglist = split(cmdout, "\n")
   let l:n = len(s:capture)
   for line in taglist
      let text = matchstr(line, '\t/^\zs.\+\ze$/;"\t')
      let lnum = matchstr(line, '\tline:\zs\d\+\ze')
      if text != "" && line != ''
         let trtext = tr(text, s:trFrom, s:trTo)
         let s:capture += [printf(' %2d: %3d %s', l:n, lnum + 0, trtext)]
         let l:n += 1
      endif
   endfor
   call s:VxShowCapture('VxOccurTags', title)
endfunc

function! vimuiex#vxoccur#VxSourceTasks()
   if len(g:vxoccur_task_words) < 1
      echo 'List of task words is empty. You need to set g:vxoccur_task_words.'
      return
   endif

   let range = s:GetSearchRange()
   if range == '' | return | endif

   if match(range[0], '\C[dDwW]') >= 0
      call s:VimGrepFiles('\C' . join(g:vxoccur_task_words, '\|'), range)
      let title = 'Tasks in Source (vimgrep)'
   else
      let s:capture = [bufname('%')]
      let s:capMatch = '\C' . join(g:vxoccur_task_words, '\|')
      let curpos = getpos('.')
      norm! gg
      silent execute 'g/' . s:capMatch . '/call s:AddOccurenceLine()'
      call setpos('.', curpos)
      let title = 'Tasks in Source'
   endif

   if len(s:capture) < 2
      echo 'No source tasks were found.'
      return
   endif

   call s:VxShowCapture('VxSourceTasks', title)
endfunc

function! s:ExtractItemPos(index)
   let item = s:capture[a:index]
   let lnn = matchstr(item, '^\s*\d\+:\s*\zs\d\+\ze\s')
   if lnn == ''
      return ['', -1, -1]
   endif
   let prfx = strlen(matchstr(item, '^\s*\d\+:\s*\d\+\ze'))
   let cln = match(item, s:capMatch, prfx)
   let cln -= prfx
   if cln < 0 | let cln = 0 | endif
   let fn = '' | let i = a:index
   while fn == '' && i > 0
      let i -= 1
      if '' != matchstr(s:capture[i], '^\S')
         let fn = s:capture[i]
         break
      endif
   endwhile
   return [fn, lnn, cln]
endfunc

function! s:DisplayLine(itempos)
   let fname=a:itempos[0]
   let lnn=a:itempos[1]
   let coln=a:itempos[2]
   call vxlib#cmd#EditLine(fname, lnn, coln, 'zO')
endfunc

function! s:OpenPreview(pos, size)
   pclose | split
   if match(a:pos, '^[HJKL]$') >= 0
      exec 'norm \<c-w>' . a:pos
   endif
   set previewwindow cursorline
   if match(a:pos, '^[HL]$') >= 0
      exec 'vertical resize ' . a:size
   else
      exec 'resize ' . a:size
   endif
   let s:preview_on = 1
endfunc

function! s:ClosePreview()
   if s:preview_on
      pclose
      let s:preview_on = 0
   endif
endfunc

let s:preview_on = 0 " nonzero if preview was activated from listbox
function! s:SelectItem_cb(index)
   let itempos = s:ExtractItemPos(a:index)
   if itempos[1] < 0
      return
   endif
   call s:ClosePreview()
   call s:DisplayLine(itempos)
endfunc

function! s:PreviewItem_cb(index)
   let itempos = s:ExtractItemPos(a:index)
   if itempos[1] < 0
      return
   endif
   call s:OpenPreview('K', 16)
   call s:DisplayLine(itempos)
   return ''
endfunc

function! s:VxShowCapture(occurType, title)
   let s:preview_on = 0
   call vimuiex#vxlist#VxPopup(s:GetOccurCapture(), a:title, {
      \ 'optid': a:occurType,
      \ 'current': 1,
      \ 'callback': s:SNR . 'SelectItem_cb({{i}})',
      \ 'keymap': [
         \ ['v', 'vim:' . s:SNR . 'PreviewItem_cb({{i}})']
      \  ]
      \ })
   if s:preview_on
      call s:ClosePreview()
      norm zz
   endif
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxoccur" require="python&&(!gui_running||python_screen)">
   call s:CheckSetting('g:vxoccur_routine_def', '{}')
   call s:CheckSetting('g:vxoccur_task_words', "['COMBAK', 'TODO', 'FIXME', 'XXX']")
   command VxOccur call vimuiex#vxoccur#VxOccur()
   command VxOccurCurrent call vimuiex#vxoccur#VxOccurCurrent()
   command VxOccurRoutines call vimuiex#vxoccur#VxOccurRoutines()
   command VxOccurTags call vimuiex#vxoccur#VxOccurTags()
   command VxSourceTasks call vimuiex#vxoccur#VxSourceTasks()
" </VIMPLUGIN>

