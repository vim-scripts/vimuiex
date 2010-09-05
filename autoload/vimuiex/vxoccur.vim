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

" History of searches (keep data)
let s:OccurHistory = []
let s:activeHistItem = {} " used for navigation through the list
function! s:NewHistItem(type, title, items)
   let item = {'type': a:type, 'title': a:title, 'items': a:items,
            \  'current': 0, 'filter': ''}
   return item
endfunc

function! s:AddToHistory(histItem)
   if len(s:OccurHistory) > g:vxoccur_hist_size
      let s:OccurHistory = s:OccurHistory[:g:vxoccur_hist_size]
   endif
   call insert(s:OccurHistory, a:histItem, 0)
endfunc

function s:DescribePos(histItem)
   return (a:histItem.current + 1) . "/" . len(a:histItem.items)
endfunc

" Data for current operation
let s:curHistItem = {} " used while the popup is displayed, callbacks write into it
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
"   -B - all buffers accessible by :bnext
"   -d [filemask, ...] - current buffer directory
"   -D [filemask, ...] - current buffer directory and subdirectories
"   -w [filemask, ...] - working directory
"   -W [filemask, ...] - working directory and subdirectories
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

   let range = substitute(range, '^\([bdw]\)\1\+', '\U\1\E', '')
   return range
endfunc

" replace some character classes in pattern
function s:PattVim2Grep(pattern)
   let rpl = {
            \ 'a': '[[:alpha:]]',
            \ 'A': '[^[:alpha:]]',
            \ 'l': '[[:lower:]]',
            \ 'L': '[^[:lower:]]',
            \ 'u': '[[:upper:]]',
            \ 'U': '[^[:upper:]]',
            \ 'd': '[[:digit:]]',
            \ 'D': '[^[:digit:]]',
            \ 'x': '[0-9A-Fa-f]',
            \ 'X': '[^0-9A-Fa-f]',
            \ 'o': '[0-7]',
            \ 'O': '[^0-7]',
            \ 's': '[[:space:]]',
            \ 'S': '[^[:space:]]'}
   let rchars = join(keys(rpl), '')
   let rpatt = '\c\(\\\+\)\([' . rchars . ']\)'
   let saveic=&ignorecase
   set noignorecase

   let lastpos = 0
   let newpatt = []
   let pos = match(a:pattern, rpatt, lastpos) 
   while pos >= 0
      if pos > lastpos
         call add(newpatt, a:pattern[lastpos : pos-1])
         let lastpos = pos
      endif
      let parts = matchlist(a:pattern, rpatt, pos)
      let pos = pos + len(parts[0]) - 1 " last char of match
      if len(parts[1]) % 2 == 0
         call add(newpatt, a:pattern[lastpos : pos])
      else
         if pos-2 > lastpos
            call add(newpatt, a:pattern[lastpos : pos-2])
         endif
         if has_key(rpl, parts[2])
            call add(newpatt, rpl[parts[2]])
         else
            call add(newpatt, '\' . parts[2])
         endif
      endif
      let lastpos = pos + 1
      let pos = match(a:pattern, rpatt, lastpos) 
   endwhile
   if lastpos < len(a:pattern)
      call add(newpatt, a:pattern[lastpos : -1])
   endif
   let &ignorecase = saveic
   return join(newpatt, '')
endfunc

" Two possibilities:
"    grep -r -n -H -i -e "else" * --include=*.sh"
"    find . -name "*.sh" | xargs grep -n -H -i -e "else"
"    -> find-xargs-grep is a lot faster
function s:GrepFiles(word, range)
   let filter = split(a:range)
   let type = filter[0]
   let options = ['', '-s', '-n', '-i', '--with-filename', '--max-count=' . g:vxoccur_match_limit]
   let recurse = 0

   let saveic=&ignorecase
   set noignorecase
   let ftmp = filter[1:]
   let filter = []
   for af in ftmp
      if af == '' | continue | endif
      if af[0] == '-' 
         if af == '-E' || af == '-F' || af == '-P'
            let options[0] = af
         elseif af == '-G'
            let options[0] = ''
         elseif af == '-r' || af == '-R' || af == '--recursive'
            let recurse = 1
         else | call add(options, af)
         endif
      else | call add(filter, af)
      endif
   endfor
   if len(filter) < 1 | let filter = ['*'] | endif

   let pattern = a:word
   if pattern[:1] == '\C'
      let pattern = pattern[2:]
      call add(options, '-i')
   elseif pattern[:1] == '\c'
      let pattern = pattern[2:]
      while index(options, '-i') > 0
         call remove(options, index(options, '-i'))
      endwhile
   endif
   if options[0] == '-E' || options[0] == '-G' || options[0] == ''
      let pattern = s:PattVim2Grep(pattern)
   endif
   call add(options, '-e ' . shellescape(pattern))

   if type == 'd' || type == 'D' | let dir = expand('%:p:h')
   elseif type == 'w' || type == 'W' | let dir = getcwd()
   else | let dir = '.' " TODO: search globally? (extract directories from filters)
   endif
   if type == 'W' || type == 'D'
      let recurse = 1
   endif
   let &ignorecase = saveic

   let cmd = ''
   if g:vxoccur_grep_mode == 1 || (g:vxoccur_grep_mode == 2 && ! recurse)
      if recurse 
         call add(options, '-r')
         for af in filter
            if af != '*'
               call add(options, '--include=' . shellescape(af))
            endif
         endfor
         let filter = [dir . '/*'] 
      else
         let xf = []
         for af in filter
            call add(xf, dir . '/' . af)
         endfor
         let filter = xf
      endif
      let cmd = g:Grep_Path . ' ' . join(options, ' ') . ' ' . join(filter, ' ')
   elseif g:vxoccur_grep_mode == 2
      " precond: recurse = true, otherwise mode 1 is used
         let xf = []
         for af in filter
            call add(xf, '-name ' . shellescape(af))
         endfor
         let filter = xf
         let cmd = g:Grep_Find_Path . ' ' . dir . ' ' . join(filter, ' -o ') . ' | ' 
                  \ . g:Grep_Xargs_Path . ' ' . g:Grep_Path . ' ' . join(options, ' ')
   endif
   if len(cmd) > 0
      let cmd_out = system(cmd)
      cgetexpr cmd_out
      let [dummy, s:capture] = vimuiex#vxquickfix#TransformQfItems(getqflist())
   endif
endfunc

" Prepares and executes a vimgrep command
" Stores search results in s:capture (copied from QuickFix list)
function! s:VimGrepFiles(word, range)
   let filter = split(a:range)
   let type = filter[0]

   let filter = filter[1:]
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

   let vgexpr = g:vxoccur_match_limit . 'vimgrep /' . a:word . '/j'
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

function! s:VimGrepBuffers(word, range)
   let filter = split(a:range)
   let type = filter[0]

   let filter = filter[1:] " TODO: filter currently unused for buffers
   if len(filter) < 1 | let filter = ['*'] | endif
   let curbuf = bufnr('%')

   let s:capture = [expand('%:p')]
   let curpos = getpos('.')
   norm! gg
   silent execute 'g/' . a:word . '/call s:AddOccurenceLine()'
   call setpos('.', curpos)

   if type ==# 'B' || type ==? 'u'
      bnext
      let bufnr = bufnr('%')
      while bufnr != curbuf
         call add(s:capture, expand('%:p'))
         let curpos = getpos('.')
         norm! gg
         silent execute 'g/' . a:word . '/call s:AddOccurenceLine()'
         call setpos('.', curpos)
         bnext
         let bufnr = bufnr('%')
      endwhile
   endif
   
   silent exec "buffer " . curbuf
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
      if g:vxoccur_grep_mode == 0
         call s:VimGrepFiles(s:capWord, range)
      else
         call s:GrepFiles(s:capWord, range)
      endif
      let title = 'Vimgrep: ' . s:capWord
   else
      call s:VimGrepBuffers(s:capWord, range)
      if range[0] ==# 'b'
         let title = 'Find in buffer: ' . s:capWord . ', ' . expand('%:p:t')
      else
         let title = 'Find in buffers: ' . s:capWord
      endif
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
   call s:VxShowCapture('VxOccurCurrent', 'Tag search: ' . s:capWord) " 0: not added to history
endfunc

" TODO: could perform a search with range, like VxOccur
function! vimuiex#vxoccur#VxOccurRoutines()
   let l:dict = g:vxoccur_routine_def
   if has_key(l:dict, &ft) != 1
      echom 'Routine regexp not defined for ft=' . &ft
   else
      let s:capture = [bufname('%')]
      let title = 'Routines, ft=' . &ft . ', ' . expand('%:p:t')
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
      call s:VxShowCapture('VxOccurRoutines', title) " 0: not added to history
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
      echoe 'List of task words is empty. You need to set g:vxoccur_task_words.'
      return
   endif

   let range = s:GetSearchRange()
   if range == '' | return | endif

   if match(range[0], '\C[dDwW]') >= 0
      if g:vxoccur_grep_mode == 0
         call s:VimGrepFiles('\C' . join(g:vxoccur_task_words, '\|'), range)
      else
         call s:GrepFiles('\C' . join(g:vxoccur_task_words, '\|'), range)
      endif
      let title = 'Tasks in Source (vimgrep)'
   else
      let s:capMatch = '\C' . join(g:vxoccur_task_words, '\|')
      call s:VimGrepBuffers(s:capMatch, range)
      if range[0] ==# 'b'
         let title = 'Tasks in buffer ' . expand('%:p:t')
      else
         let title = 'Tasks in buffers'
      endif
   endif

   if len(s:capture) < 2
      echo 'No source tasks were found.'
      return
   endif

   call s:VxShowCapture('VxSourceTasks', title)
endfunc

function! s:ExtractItemPos(items, index)
   let item = a:items[a:index]
   let lnn = matchstr(item, '^\s*\d\+:\s*\zs\d\+\ze\s')
   if lnn == ''
      return ['', -1, -1]
   endif
   let prfx = strlen(matchstr(item, '^\s*\d\+:\s*\d\+\ze'))
   let cln = match(item, s:capMatch, prfx)
   let cln -= prfx
   if cln < 0 | let cln = 0 | endif
   let fn = '' | let i = a:index
   " Find title
   while fn == '' && i > 0
      let i -= 1
      if '' != matchstr(a:items[i], '^\S')
         let fn = a:items[i]
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
   if !empty(s:curHistItem)
      let s:curHistItem.current = a:index
      " TODO: extract filter from popup-list
   endif

   let itempos = s:ExtractItemPos(s:capture, a:index)
   if itempos[1] < 0
      return
   endif
   call s:ClosePreview()
   call s:DisplayLine(itempos)
endfunc

function! s:CancelSelection_cb(index)
   if !empty(s:curHistItem)
      let s:curHistItem.current = a:index
      " TODO: extract filter from popup-list
   endif
endfunc

function! s:PreviewItem_cb(index)
   let itempos = s:ExtractItemPos(s:capture, a:index)
   if itempos[1] < 0
      return
   endif
   call s:OpenPreview('K', 16)
   call s:DisplayLine(itempos)
   return ''
endfunc

function! s:InitVxShowCapture(pyListVar)
   " Items that start with number and colon are NOT title items; others are
   exec 'python ' . a:pyListVar . '.setTitleItems(r"^\s*\d+:", 0)'
   exec 'python ' . a:pyListVar . '.hasTitles = True'
endfunc

" occurType, title [, saveHistory, historyItem]
function! s:VxShowCapture(occurType, title, ...)
   let s:preview_on = 0
   let addToHist = 1

   if a:0 > 0 | let addToHist = a:1 | endif
   if a:0 > 1 
      let histItem = a:2
      let addToHist = 0
   else
      let histItem = {}
   endif

   if empty(histItem)
      let current = 1
      let filter = ''
   else
      let s:capture = histItem.items
      let current = histItem.current
      let filter = histItem.filter
   endif
   let items = s:GetOccurCapture()

   if addToHist
      let s:curHistItem = s:NewHistItem(a:occurType, a:title, items)
   elseif !empty(histItem)
      let s:curHistItem = histItem
   else
      let s:curHistItem = {} 
   endif

   call vimuiex#vxlist#VxPopup(items, a:title, {
      \ 'optid': a:occurType,
      \ 'init': s:SNR . 'InitVxShowCapture',
      \ 'current': current,
      \ 'callback': s:SNR . 'SelectItem_cb({{i}})',
      \ 'callback_cancel': s:SNR . 'CancelSelection_cb({{i}})',
      \ 'keymap': [
         \ ['v', 'vim:' . s:SNR . 'PreviewItem_cb({{i}})']
      \  ]
      \ })
   if s:preview_on
      call s:ClosePreview()
      norm zz
   endif

   if addToHist && !empty(s:curHistItem)
      call s:AddToHistory(s:curHistItem)
   endif
   let s:activeHistItem = s:curHistItem
   let s:curHistItem = {}
endfunc

" Show v:count-h list from OccurHistory
function! vimuiex#vxoccur#VxShowLastCapture(index)
   if len(s:OccurHistory) < 1 | return | endif
   let i = a:index
   if i >= len(s:OccurHistory)
      let i = len(s:OccurHistory) - 1
   endif
   let histItem = s:OccurHistory[i]
   call s:VxShowCapture(histItem.type, histItem.title, 0, histItem)
endfunc

" Jump to next/prev item in activeHistItem list
function! vimuiex#vxoccur#VxCNext(direction)
   if empty(s:activeHistItem)
      if len(s:OccurHistory) < 1
         echom "No searches stored."
         return
      endif
      let s:activeHistItem = s:OccurHistory[0]
   endif
   let hit = s:activeHistItem
   if a:direction > 0
      while 1 
         if hit.current >= len(hit.items) - 1
            echo "No more items, " . hit.title . " " . s:DescribePos(hit) . "."
            return
         else
            let hit.current += 1
         endif
         let itempos = s:ExtractItemPos(hit.items, hit.current)
         if itempos[1] < 0 | continue | endif 
         call s:DisplayLine(itempos)
         break
      endwhile
   else
      while 1 
         if hit.current < 1
            echo "No more items, " . hit.title . " " . s:DescribePos(hit) . "."
            return
         else
            let s:activeHistItem.current -= 1
         endif
         let itempos = s:ExtractItemPos(hit.items, hit.current)
         if itempos[1] < 0 | continue | endif 
         call s:DisplayLine(itempos)
         break
      endwhile
   endif
   echo hit.title . " " . s:DescribePos(hit) . "."
endfunc

let s:ShowHistoryItems = 0
function! s:SelectHistory_cb(index)
   if a:index > 0
      let oh = remove(s:OccurHistory, a:index)
      call insert(s:OccurHistory, oh, 0)
   endif
   let s:ShowHistoryItems = 1
   return 'q'
endfunc

function! vimuiex#vxoccur#VxSelectOccurHist()
   if len(s:OccurHistory) < 1
      return
   endif

   let items = []
   for oh in s:OccurHistory
      call add(items, oh.title . ' (' . oh.type . ", " . len(oh.items) . ')')
   endfor

   let s:ShowHistoryItems = 0
   call vimuiex#vxlist#VxPopup(items, "Activate results", {
      \ 'optid': 'VxSelectOccurHist',
      \ 'current': 0,
      \ 'callback': s:SNR . 'SelectHistory_cb({{i}})'
      \ })

   if s:ShowHistoryItems
      let histItem = s:OccurHistory[0]
      call s:VxShowCapture(histItem.type, histItem.title, 0, histItem)
      " call vimuiex#vxoccur#VxShowLastCapture(0)
   endif
endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxoccur" require="python&&(!gui_running||python_screen)">
   call s:CheckSetting('g:vxoccur_routine_def', '{}')
   call s:CheckSetting('g:vxoccur_task_words', "['COMBAK', 'TODO', 'FIXME', 'XXX']")
   call s:CheckSetting('g:vxoccur_hist_size', '10')
   call s:CheckSetting('g:vxoccur_match_limit', '1000')
   " grep mode: 0 - vimgrep, 1 - grep (-r), 2 - find - xargs - grep
   call s:CheckSetting('g:vxoccur_grep_mode', '0')
   " variables used by grep.vim
   call s:CheckSetting('g:Grep_Path', "'grep'")
   call s:CheckSetting('g:Grep_Find_Path', "'find'")
   call s:CheckSetting('g:Grep_Xargs_Path', "'xargs'")

   command VxOccur call vimuiex#vxoccur#VxOccur()
   command VxOccurCurrent call vimuiex#vxoccur#VxOccurCurrent()
   command VxOccurRoutines call vimuiex#vxoccur#VxOccurRoutines()
   command VxOccurTags call vimuiex#vxoccur#VxOccurTags()
   command VxSourceTasks call vimuiex#vxoccur#VxSourceTasks()
   command VxOccurHist call vimuiex#vxoccur#VxShowLastCapture(v:count)
   command VxOccurSelectHist call vimuiex#vxoccur#VxSelectOccurHist()
   command VxCNext call vimuiex#vxoccur#VxCNext(1)
   command VxCPrev call vimuiex#vxoccur#VxCNext(-1)

   function! s:F_vx_occur_map_plug_(vxcmd)
     silent exec 'nmap <unique> <Plug>' . a:vxcmd . ' :' . a:vxcmd . '<cr>'
     silent exec 'imap <unique> <Plug>' . a:vxcmd . ' <Esc>:' . a:vxcmd . '<cr>'
     silent exec 'vmap <unique> <Plug>' . a:vxcmd . ' :<c-u>' . a:vxcmd . '<cr>'
   endfunc
   call s:F_vx_occur_map_plug_('VxOccurCurrent')
   call s:F_vx_occur_map_plug_('VxOccurRoutines')
   call s:F_vx_occur_map_plug_('VxOccurTags')
   call s:F_vx_occur_map_plug_('VxSourceTasks')
   call s:F_vx_occur_map_plug_('VxCNext')
   call s:F_vx_occur_map_plug_('VxCPrev')
   call s:F_vx_occur_map_plug_('VxOccurSelectHist')
   delfunction s:F_vx_occur_map_plug_

   nmap <unique> <Plug>VxOccurHist :<c-u>VxOccurHist<cr>
   imap <unique> <Plug>VxOccurHist <Esc>:<c-u>VxOccurHist<cr>
   vmap <unique> <Plug>VxOccurHist :<c-u>VxOccurHist<cr>
   nmap <unique> <Plug>VxOccurRegex :<c-u>VxOccur<cr>
   imap <unique> <Plug>VxOccurRegex <Esc>:<c-u>VxOccur<cr>
   vmap <unique> <Plug>VxOccurRegex :<c-u>VxOccur<cr>
" </VIMPLUGIN>

