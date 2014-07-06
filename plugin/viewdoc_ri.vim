" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for ri

if exists('g:loaded_viewdoc_ri') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_ri = 1


""" Options
if !exists('g:viewdoc_ri_cmd')
	let g:viewdoc_ri_cmd='ri'               " user may want 'ri20'
endif
if !exists('g:viewdoc_ri_format')
	let g:viewdoc_ri_format='markdown'      " user may want 'rdoc'
endif

""" Interface
" - command
command -bar -bang -nargs=1 ViewDocRi
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'ri')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> rdoc   getcmdtype()==':' && getcmdline()=='rdoc'  ? 'ViewDocRi'  : 'rdoc'
	cnoreabbrev <expr> rdoc!  getcmdtype()==':' && getcmdline()=='rdoc!' ? 'ViewDocRi'  : 'rdoc!'
endif

""" Handlers

function s:ViewDoc_ri(topic, ...)
	return {  'cmd':	printf('%s --format=%s %s | grep -v "Nothing known about"', g:viewdoc_ri_cmd, g:viewdoc_ri_format, shellescape(a:topic,1)),
		\ 'ft': 	'ri_'.g:viewdoc_ri_format,
		\ }
endfunction

" use function(s:SID().'Foo') instead of function('s:Foo') for
" compatibility with Vim-7.3.x (7.3.762 at least)
function s:SID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction
let g:ViewDoc_ri = function(s:SID().'ViewDoc_ri')
let g:ViewDoc_ruby = function(s:SID().'ViewDoc_ri')
let g:ViewDoc_ri_bs = function(s:SID().'ViewDoc_ri')
let g:ViewDoc_ri_ansi = function(s:SID().'ViewDoc_ri')
let g:ViewDoc_ri_rdoc = function(s:SID().'ViewDoc_ri')
let g:ViewDoc_ri_markdown = function(s:SID().'ViewDoc_ri')
