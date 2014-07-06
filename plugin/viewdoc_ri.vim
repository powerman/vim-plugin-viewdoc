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
	let g:viewdoc_ri_cmd='ri --no-pager --format=rdoc'
endif


""" Interface
" - command
command -bar -bang -nargs=1 ViewDocRi
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'ri')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> vri    getcmdtype()==':' && getcmdline()=='vri'  ? 'ViewDocRi'  : 'vri'
	cnoreabbrev <expr> vri!   getcmdtype()==':' && getcmdline()=='vri!' ? 'ViewDocRi'  : 'vri!'
endif


""" Handlers

function s:ViewDoc_ri(topic, ...)
	return {	'cmd':	printf('%s %s | grep -v "no Ruby documentation found"', g:viewdoc_ri_cmd, shellescape(a:topic,1)),
		\	'ft':	'rdoc',
		\	}
endfunction

" use function(s:SID().'Foo') instead of function('s:Foo') for
" compatibility with Vim-7.3.x (7.3.762 at least)
function s:SID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction
let g:ViewDoc_ri = function(s:SID().'ViewDoc_ri')
let g:ViewDoc_rdoc = function(s:SID().'ViewDoc_ri')
let g:ViewDoc_ruby = function(s:SID().'ViewDoc_ri')
