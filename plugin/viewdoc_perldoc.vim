" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for perldoc

if exists('g:loaded_viewdoc_perldoc') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_perldoc = 1


""" Handlers

function g:ViewDoc_perldoc(topic, ...)
	let t = shellescape(a:topic,1)
	return	{ 'cmd':	printf('perldoc %s || perldoc -f %s || perldoc -v %s',t,t,t),
		\ 'ft':		'perldoc',
		\ }
endfunction

let g:ViewDoc_perl = function('g:ViewDoc_perldoc')

