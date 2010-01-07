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
map <SID>xx <SID>xx
let s:SID = substitute(maparg('<SID>xx'), '<SNR>\(\d\+_\)xx$', '\1', '')
unmap <SID>xx

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
   let s:capMatch = s:capWord
   let s:capture = [bufname('%')]
   let l:curpos = getpos('.')
   norm! gg
   silent execute 'g/' . s:capMatch . '/call s:AddOccurenceLine()'
   call setpos(".", l:curpos)
   if len(s:capture) < 2
      echo 'No occurences of "' . s:capWord . '" were found.'
      return
   endif
   call s:VxShowCapture()
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
   call s:VxShowCapture()
endfunc

function! vimuiex#vxoccur#VxOccurRoutines()
   let l:dict = g:vxoccur_routine_def
   if has_key(l:dict, &ft) != 1
      echom 'Routine regexp not defined for ft=' . &ft
   else
      let s:capture = [bufname('%')]
      let s:capWord = 'Routines, ft=' . &ft
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
      call s:VxShowCapture()
   endif
endfunc

function! vimuiex#vxoccur#VxOccurTags()
   let s:capture = [bufname('%')]
   let s:capWord = 'Tags'
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
   call s:VxShowCapture()
endfunc

function! vimuiex#vxoccur#VxSourceTasks()
   if len(g:vxoccur_task_words) < 1
      echo 'List of task words is empty. You need to set g:vxoccur_task_words.'
      return
   endif
   let s:capture = [bufname('%')]
   let s:capWord = 'Tasks in Source'
   let s:capMatch = join(g:vxoccur_task_words, '\|')
   let curpos = getpos('.')
   norm! gg
   silent execute 'g/' . s:capMatch . '/call s:AddOccurenceLine()'
   call setpos('.', curpos)
   call s:VxShowCapture()
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
      exec 'norm ' . a:pos
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

" TODO: VxShowCapture: parameterer optid for each type of occur
function! s:VxShowCapture()
exec 'python VIM_SNR_VXOCCUR="<SNR>' . s:SID .'"'
exec 'python VIM_VXOCUR_WORD="""' . escape(s:capWord, '"\'). '"""'

let s:preview_on = 0
python << EOF
import vim
import vimuiex.popuplist as lister
List = lister.CList(title="'%s'" % VIM_VXOCUR_WORD, optid="VxOccur")
List.loadVimItems("%sGetOccurCapture()" % VIM_SNR_VXOCCUR)
List.cmdAccept = "%sSelectItem_cb({{i}})" % VIM_SNR_VXOCCUR
List.keymapNorm.setKey(r"v", "vim:%sPreviewItem_cb({{i}})" % VIM_SNR_VXOCCUR)
List.process(curindex=1)
List=None
EOF
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

