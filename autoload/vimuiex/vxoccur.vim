" vim: set fileencoding=utf-8 sw=3 ts=8 et :vim
" vxoccur.vim- display the occurences of a search pattern in a popup list
"
" Author: Marko Mahnič
" Created: September 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if vxlib#plugin#StopLoading("#au#vimuiex#vxoccur")
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
function! s:getOccurCapture()
   return s:capture
endfunc

function! s:initTr()
   let s:trFrom = ""
   let s:trTo = ""
   for i in range(32)
      if i == 0 || i == 8 | continue | endif
      let s:trFrom = s:trFrom . nr2char(i)
      let s:trTo = s:trTo . " "
   endfor
endfunc
call s:initTr()

function! s:addOccurenceLine()
   let n = len(s:capture)
   let trline = tr(getline("."), s:trFrom, s:trTo)
   let s:capture += [printf(" %2d: %3d %s", n, line("."), trline)]
endfunc

function! s:AddOccurenceLineF(funcname)
   echom "Adding"
   let n = len(s:capture)
   let pos = line(".")
   exec "let txt = " . a:funcname . "()"
   let trline = tr(txt, s:trFrom, s:trTo)
   let s:capture += [printf(" %2d: %3d %s", n, pos, trline)]
endfunc

function! vimuiex#vxoccur#VxOccur()
   call inputsave()
   let l:hinp = vxlib#hist#GetHistory('input')
   call vxlib#hist#CopyHistory('search', 'input')
   let s:capWord = expand("<cword>")
   if s:capWord != ""
      call histadd('input', s:capWord)
   endif
   let s:capWord = input("Find occurences:/") " , getreg('/')
   call vxlib#hist#SetHistory('input', l:hinp)
   call inputrestore()
   if s:capWord != "" 
      call histadd('search', s:capWord)
   else
      return
   endif
   let s:capMatch = s:capWord
   let s:capture = [bufname("%")]
   let l:curpos = getpos(".")
   norm! gg
   silent execute "g/" . s:capMatch . "/call s:addOccurenceLine()"
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
      let s:capWord = expand("<cword>")
      let s:capMatch = '\c\<' . s:capWord . '\>'
   catch /^Vim\%((\a\+)\)\=:E349/
      let s:capture = ["Error: No identifier under cursor."]
      let s:capWord = "<>"
      let s:capMatch = '^$'
   endtry
   call s:VxShowCapture()
endfunc

function! vimuiex#vxoccur#VxOccurRoutines()
   let l:dict = g:vxoccur_routine_def
   if has_key(l:dict, &ft) != 1
      echom "Routine regexp not defined for ft=" . &ft
   else
      let s:capture = [bufname("%")]
      let s:capWord = "Routines, ft=" . &ft
      let s:capMatch = l:dict[&ft].regexp
      let gcmd = "call s:addOccurenceLine()"
      if has_key(l:dict[&ft], "call") != 0
         let gcmd = l:dict[&ft].call
         " if exists(gcmd) " BUG? 7.2.284: exists() can't find functions from autoload
            let gcmd = "call s:AddOccurenceLineF('" . gcmd . "')"
            " echom "VxOccurRoutines: callback=" . gcmd
         " else
            " echom "VxOccurRoutines: Undefined callback " . gcmd
            " let gcmd = "call s:addOccurenceLine()"
         " endif
      endif
      let curpos = getpos(".")
      norm! gg
      silent execute "g/" . s:capMatch . "/" . gcmd
      call setpos(".", curpos)
      call s:VxShowCapture()
   endif
endfunc

function! vimuiex#vxoccur#VxOccurTags()
   let s:capture = [bufname("%")]
   let s:capWord = "Tags"
   let s:capMatch = ""
   let cmd = "ctags -f - --format=2 --excmd=pattern --fields=nks --sort=no"
   let filename = fnamemodify(bufname('%'), ':p')
   let cmdout = system(cmd . " " . filename)
   let taglist = split(cmdout, "\n")
   let l:n = len(s:capture)
   for line in taglist
      let text = matchstr(line, '\t/^\zs.\+\ze$/;"\t')
      let lnum = matchstr(line, '\tline:\zs\d\+\ze')
      if text != "" && line != ""
         let trtext = tr(text, s:trFrom, s:trTo)
         let s:capture += [printf(" %2d: %3d %s", l:n, lnum + 0, trtext)]
         let l:n += 1
      endif
   endfor
   call s:VxShowCapture()
endfunc

function! vimuiex#vxoccur#VxSourceTasks()
   if len(g:vxoccur_task_words) < 1
      echo "List of task words is empty. You need to set g:vxoccur_task_words."
      return
   endif
   let s:capture = [bufname("%")]
   let s:capWord = "Tasks in Source"
   let s:capMatch = join(g:vxoccur_task_words, '\|')
   let l:curpos = getpos(".")
   norm! gg
   silent execute "g/" . s:capMatch . "/call s:addOccurenceLine()"
   call setpos(".", l:curpos)
   call s:VxShowCapture()
endfunc

function! s:selectItem_cb(index)
   let l:item = s:capture[a:index]
   let l:lnn = matchstr(l:item, '^\s*\d\+:\s*\zs\d\+\ze\s')
   if l:lnn == ""
      return
   endif
   let l:prfx = strlen(matchstr(l:item, '^\s*\d\+:\s*\d\+\ze'))
   let l:cln = match(l:item, s:capMatch, l:prfx)
   let l:cln -= l:prfx
   if l:cln < 0 | let l:cln = 0 | endif
   let l:fn = "" | let l:i = a:index
   while l:fn == "" && l:i > 0
      let l:i -= 1
      if "" != matchstr(s:capture[l:i], '^\S')
         let l:fn = s:capture[l:i]
         break
      endif
   endwhile
   if l:fn != ""
      call vxlib#cmd#Edit(l:fn)
   endif
   call setpos('.', [0, l:lnn, l:cln, 0])
endfunc

function! s:VxShowCapture()
exec 'python VIM_SNR_VXOCCUR="<SNR>' . s:SID .'"'
exec 'python VIM_VXOCUR_WORD="""' . escape(s:capWord, '"\'). '"""'

python << EOF
import vim
import vimuiex.popuplist as lister
List = lister.CList(title="'%s'" % VIM_VXOCUR_WORD, align="BL", autosize="VH")
List.loadVimItems("%sgetOccurCapture()" % VIM_SNR_VXOCCUR)
List.cmdAccept = "call %sselectItem_cb({{i}})" % VIM_SNR_VXOCCUR
List.process(curindex=1)
List=None
EOF

endfunc

" =========================================================================== 
" Global Initialization - Processed by Plugin Code Generator
" =========================================================================== 
finish

" <VIMPLUGIN id="vimuiex#vxoccur" require="python&&(!gui_running||python_screen)">
   call s:CheckSetting("g:vxoccur_routine_def", "{}")
   call s:CheckSetting("g:vxoccur_task_words", "['COMBAK', 'TODO', 'FIXME', 'XXX']")
   command VxOccur call vimuiex#vxoccur#VxOccur()
   command VxOccurCurrent call vimuiex#vxoccur#VxOccurCurrent()
   command VxOccurRoutines call vimuiex#vxoccur#VxOccurRoutines()
   command VxOccurTags call vimuiex#vxoccur#VxOccurTags()
   command VxSourceTasks call vimuiex#vxoccur#VxSourceTasks()
" </VIMPLUGIN>

