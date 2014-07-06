" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for pydoc

if exists('g:loaded_viewdoc_pydoc') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_pydoc = 1


""" Options
if !exists('g:viewdoc_pydoc_cmd')
	let g:viewdoc_pydoc_cmd='pydoc'	                " user may want 'pydoc3.2'
endif

""" Interface
" - command
command -bar -bang -nargs=1 -complete=custom,s:CompletePydoc ViewDocPydoc
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'pydoc')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> pydoc    getcmdtype()==':' && getcmdline()=='pydoc'  ? 'ViewDocPydoc'  : 'pydoc'
	cnoreabbrev <expr> pydoc!   getcmdtype()==':' && getcmdline()=='pydoc!' ? 'ViewDocPydoc'  : 'pydoc!'
endif

""" Handlers

function s:ViewDoc_pydoc(topic, ...)
	return	{ 'cmd':	printf('%s %s | grep -v "no Python documentation found"', g:viewdoc_pydoc_cmd, shellescape(a:topic,1)),
		\ 'ft':		'pydoc',
		\ }
endfunction

" use function(s:SID().'Foo') instead of function('s:Foo') for
" compatibility with Vim-7.3.x (7.3.762 at least)
function s:SID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction
let g:ViewDoc_pydoc  = function(s:SID().'ViewDoc_pydoc')
let g:ViewDoc_python = function(s:SID().'ViewDoc_pydoc')


""" Internal

" Autocomplete topics, keywords and modules.
function s:CompletePydoc(ArgLead, CmdLine, CursorPos)
	if(!exists('s:complete_cache'))
		call ViewDoc_SetShellToBash()
		let s:complete_cache = system('echo $(for x in topics keywords modules; do echo $(pydoc $x 2>/dev/null | sed ''s/^$/\a/'') | cut -d $''\a'' -f 3; done) | sed ''s/ /\n/g''')
		call ViewDoc_RestoreShell()
	endif
	return s:complete_cache
endfunction

