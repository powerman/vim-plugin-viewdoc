" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for perldoc
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
	if synname =~# 'SharpBang'
		let h.topic = 'perlrun'
	elseif synname =~# 'StatementFiles' && len(h.topic) == 1
		let h.topic = '-X'
	elseif synname =~# 'Conditional\|Repeat\|Label'
		let h.topic = 'perlsyn'
	elseif synname =~# 'SubPrototype\|SubAttribute'
		let h.topic = 'perlsub'
	elseif h.topic ==# 'AUTOLOAD'
		let h.topic = 'perlsub'
		let h.search= '^\s*Autoloading\>'
	elseif h.topic ==# 'DESTROY'
		let h.topic = 'perlobj'
		let h.search= '^\s*Destructors\>'
	elseif h.topic =~# '^__[A-Z]\+__$'
		let h.topic = 'perldata'
		let h.search= '^\s*Special\s\+Literals'
	elseif h.topic ==# 'tr' || h.topic ==# 'y'
		let h.topic = 'perlop'
		let h.search= '^\s*tr\/'
	elseif h.topic =~# '^q[qxw]\?$'
		let h.search= '^\s*' . h.topic . '\/'
		let h.topic = 'perlop'
	elseif synname =~# 'StringStartEnd\|perlQQ'
		let h.topic = 'perlop'
		let h.search= '^\s*Quote\s\+and\s\+Quote-[Ll]ike\s\+Operators\s*$'
	elseif synname =~# 'perlControl'
		let h.topic = 'perlmod'
		let h.search= '^\s*BEGIN,'
	elseif synname =~# '^pod[A-Z]\|POD'
		let h.topic = 'perlpod'
	elseif synname =~# 'Match'
		let h.topic = 'perlre'
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
	endif
	let t = shellescape(h.topic,1)
	let h.cmd = printf('perldoc -- %s || perldoc -f %s || perldoc -v %s',t,t,t)
	return h
endfunction

let g:ViewDoc_perl = function('g:ViewDoc_perldoc')

