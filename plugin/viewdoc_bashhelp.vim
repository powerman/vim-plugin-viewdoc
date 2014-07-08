" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for shell scripts

if exists('g:loaded_viewdoc_bash') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_bash = 1

""" Interface
" - command
command -bar -bang -nargs=1 ViewDocBashHelp
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'bashhelp')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> bashhelp     getcmdtype()==':' && getcmdline()=='bashhelp'  ? 'ViewDocBashHelp'  : 'bashhelp'
	cnoreabbrev <expr> bashhelp!    getcmdtype()==':' && getcmdline()=='bashhelp!' ? 'ViewDocBashHelp'  : 'bashhelp!'
endif

""" Handlers

" let h = ViewDoc_bashhelp('echo')
function s:ViewDoc_bashhelp(topic, ...)
  return  { 'cmd': printf('bash -c "help -m %s" 2>/dev/null', shellescape(a:topic,1)),
          \ 'ft':  'man',
          \ }
endfunction

" use function(s:SID().'Foo') instead of function('s:Foo') for
" compatibility with Vim-7.3.x (7.3.762 at least)
function s:SID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction
let g:ViewDoc_bashhelp = function(s:SID().'ViewDoc_bashhelp')
let g:ViewDoc_sh = [ g:ViewDoc_bashhelp, 'ViewDoc_man' ]

