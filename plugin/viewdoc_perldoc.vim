" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for perldoc
" TODO Add more auto-detection based on context/syntax.
" TODO Add command 'perldoc' with auto-complete.

if exists('g:loaded_viewdoc_perldoc') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_perldoc = 1


""" Handlers

function g:ViewDoc_perldoc(topic, filetype, synid, ctx)
	let h = { 'ft':		'perldoc',
		\ 'topic':	a:topic,
		\ }
	let synname = a:ctx ? synIDattr(a:synid,'name') : ''
	if h.topic == 'X'
		let h.topic = '-X'
	elseif synname =~# 'Var'
		" search for position where current var's name begin (starting with [$@%])
		let col = searchpos('[$@%]{\?\^\?\k*\%#\|\%#[$@%]', 'n')[1]
		" from that position took full var name (plus extra [ or { after it, if any)
		let var = col == 0 ? '' : matchstr(getline('.'), '^[$@%]{\?^\?.\k*}\?[{\[]\?', col-1)
		" $a[ -> @a,  $a{ -> %a,  @a{ -> %a,  drop [ or { at end
		let var = substitute(var, '^$\(.*\)\[$', '@\1', '')
		let var = substitute(var, '^$\(.*\){$',  '%\1', '')
		let var = substitute(var, '^@\(.*\){$',  '%\1', '')
		let var = substitute(var, '[\[{]$',      '',    '')
		" ${a} -> $a,  ${^a} -> $^a,  but not ${^aa}
		let var = substitute(var, '^\([$@%]\){\([^^].*\|\^.\)}$', '\1\2', '')
		let h.topic = var == '' ? h.topic : var
	elseif synname =~# 'SharpBang'
		let h.topic = 'perlrun'
	endif
	let t = shellescape(h.topic,1)
	let h.cmd = printf('perldoc -- %s || perldoc -f %s || perldoc -v %s',t,t,t)
	return h
endfunction

let g:ViewDoc_perl = function('g:ViewDoc_perldoc')

