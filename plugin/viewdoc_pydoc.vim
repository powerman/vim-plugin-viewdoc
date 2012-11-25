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
	let g:viewdoc_pydoc_cmd='/usr/bin/pydoc'	" user may want '/usr/bin/pydoc3.2'
endif

""" Handlers

function ViewDoc_pydoc(topic, ...)
	return	{ 'cmd':	printf('%s %s', g:viewdoc_pydoc_cmd, shellescape(a:topic,1)),
		\ 'ft':		'pydoc',
		\ }
endfunction

let g:ViewDoc_pydoc = function('ViewDoc_pydoc')
let g:ViewDoc_python = function('ViewDoc_pydoc')

