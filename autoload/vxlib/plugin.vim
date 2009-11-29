" vim:set fileencoding=utf-8 sw=3 ts=3 et:vim
"
" Author: Marko Mahnič
" Created: October 2009
" License: GPL (http://www.gnu.org/copyleft/gpl.html)
" This program comes with ABSOLUTELY NO WARRANTY.

if exists("s:vxlib_plugin_loaded")
   finish
endif
let s:vxlib_plugin_loaded = 1

" Check if the variable 'name' exists. Create it with the value 'default' if
" it doesn't.
" @param name - string, the name of the global variable ("g:...")
" @param default - string, a vim expression that will give the initial value
" @returns - nothing
function! vxlib#plugin#CheckSetting(name, default)
   if !exists(a:name)
      exec "let " . a:name . "=" . a:default
   endif
endfunc

call vxlib#plugin#CheckSetting("g:VxPlugins", "{}")
call vxlib#plugin#CheckSetting("g:VxPluginEnabledDefault", "1")
call vxlib#plugin#CheckSetting("g:VxPluginVar", "{}")
call vxlib#plugin#CheckSetting("g:VxPluginLoaded", "{}")
call vxlib#plugin#CheckSetting("g:VxPluginMissFeatures", "{}")
call vxlib#plugin#CheckSetting("g:VxPluginErrors", "{}")

" Something to autoload this module from .vimrc
function! vxlib#plugin#Init()
endfunc

" Check if the plugin 'idPlugin' is enabled
function! vxlib#plugin#IsEnabled(idPlugin)
   return get(g:VxPlugins, a:idPlugin, g:VxPluginEnabledDefault)
endfunc

function! vxlib#plugin#SetEnabled(idPlugin, value)
   let g:VxPlugins[a:idPlugin] = a:value
endfunc

function! vxlib#plugin#Enable(idPlugin)
   let g:VxPlugins[a:idPlugin] = 1
endfunc

function! vxlib#plugin#Disable(idPlugin)
   let g:VxPlugins[a:idPlugin] = 0
endfunc

" @returns the plugin-loaded status for the plugin 'idPlugin'.
" Status:
"    1 - loaded
"    0 - not loaded, probably unknown
"    negative: could not (completely) load
"    -1 - disabled
"    -2 - missing vim features
"    -3 - TODO: missing plugins. The script is given this status on pass 1 when
"         one of the required plugins is missing. The file with the plugin is
"         added to the queue of files to be reloaded. On pass 2 only the
"         plugins with this status are processed (StopLoading shoud return 0).
"         If the plugin is successfully loaded on pass 2, its status is set to
"         1, otherwise the list of missing plugins is created for the plugin.
"    -9 - errors in plugin code
function! vxlib#plugin#GetLoadStatus(idPlugin)
   return get(g:VxPluginLoaded, a:idPlugin, 0)
endfunc

" Return true if the plugin was loaded without problems.
function! vxlib#plugin#IsLoaded(idPlugin)
   return get(g:VxPluginLoaded, a:idPlugin, 0) > 0
endfunc

" Set the plugin's loaded state.
function! vxlib#plugin#SetLoaded(idPlugin, markLoaded)
   let g:VxPluginLoaded[a:idPlugin] = a:markLoaded
endfunc

" Check if the plugin 'idPlugin' is loaded.
" If the plugin isn't marked as loaded, it will be marked as such.
function! s:CheckAndSetLoaded(idPlugin, value)
   let loaded = get(g:VxPluginLoaded, a:idPlugin, 0)
   if ! loaded
      let g:VxPluginLoaded[a:idPlugin] = a:value
   endif
   return loaded
endfunc

" Check if the plugin 'idPlugin' is loaded.
" If the plugin isn't marked as loaded, it will be marked as such.
"
" Used as a script loading guard: if StopLoading(id) | finish | endif
"
function! vxlib#plugin#StopLoading(idPlugin)
   return s:CheckAndSetLoaded(a:idPlugin, 1)
endfunc

" List all known plugins
function! vxlib#plugin#List()
   let loaded = []
   let disabled = []
   let missing = []
   let errors = []
   let allmet = keys(g:VxPluginLoaded)
   call sort(allmet)
   for k in allmet
      let state = g:VxPluginLoaded[k]
      if state > 0 | call add(loaded, k)
      else
         if state == -1 | call add(disabled, k)
         elseif state == -2 | call add(missing, k)
         else | call add(errors. k)
         endif
      endif
   endfor
   if len(loaded) > 0 | echo "Loaded:"
      for k in loaded
         echo "   " . g:VxPluginLoaded[k] . " " . k
      endfor
   endif
   if len(disabled) > 0 | echo "Disabled:"
      for k in disabled
         echo "   " . g:VxPluginLoaded[k] . " " . k
      endfor
   endif
   if len(missing) > 0 | echo "Reuqired features not available:"
      for k in missing
         echo "   " . g:VxPluginLoaded[k] . " " . k . "\t" . get(g:VxPluginMissFeatures, k, "?")
      endfor
   endif
   if len(errors) > 0 | echo "Failed to load:"
      for k in errors
         echo "   " . g:VxPluginLoaded[k] . " " . k . "\t" . get(g:VxPluginErrors, k, "?")
      endfor
   endif
   let enabled = keys(g:VxPlugins)
   call sort(enabled)
   if len(enabled) > 0 | echo "Explicitly Enabled/Disabled:"
      for k in enabled
         echo "   " . g:VxPlugins[k] . " " . k
      endfor
   endif

   " Doesn't work with VxCmd: double call to #Capture! --> redir
   "let loaded = vxlib#cmd#Capture(":let", 1)
   "call filter(loaded, 'v:val =~ "^loaded_"')
   "if len(loaded) > 0 | echo "Other plugins:"
   "   call map(loaded, 'matchstr(v:val, "^loaded_\\zs.*$")')
   "   for line in loaded
   "      echo "   " . line
   "   endfor
   "endif
endfunc

" Special case: can't use #StopLoading before it is created.
call vxlib#plugin#SetLoaded("#au#vxlib#plugin", 1)
