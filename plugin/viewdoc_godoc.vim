" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for godoc

if exists('g:loaded_viewdoc_godoc') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_godoc = 1


""" Options
if !exists('g:viewdoc_godoc_cmd')
	let g:viewdoc_godoc_cmd='godoc'
endif

""" Interface
" - command
command -bar -bang -nargs=1 -complete=customlist,go#package#Complete ViewDocGo
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'go')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> godoc    getcmdtype()==':' && getcmdline()=='godoc'	? 'ViewDocGo'  : 'godoc'
	cnoreabbrev <expr> godoc!   getcmdtype()==':' && getcmdline()=='godoc!' ? 'ViewDocGo'  : 'godoc!'
endif

""" Handlers

" let h = ViewDoc_go('fmt')
" let h = ViewDoc_go('fmt Println')
function s:ViewDoc_go(topic, filetype, synid, ctx)
	let h = { 'ft':		'godoc',
		\ }
	
	" This implementation based on code from vim-go plugin: Copyright 2011 The Go Authors.
	if a:ctx
		let oldiskeyword = &iskeyword
		setlocal iskeyword+=.
		let word = expand('<cword>')
		let &iskeyword = oldiskeyword
		let word = substitute(word, '[^a-zA-Z0-9\\/._~-]', '', 'g')
		let words = split(word, '\.\ze[^./]\+$')
		if len(words) == 1
			let synname = synIDattr(a:synid,'name')
			if synname =~# 'goBoolean\|goBuiltins\|goType\|goSignedInts\|goUnsignedInts\|goFloats\|goComplexes'
				let words = ['builtin', words[0]]
			endif
		endif
	else
		let words = split(a:topic, '\s\+')
	endif

	if !len(words)
		let pkg = ""
		let exported_name = ""
	elseif len(words) == 1
		let pkg = words[0]
		let exported_name = ""
	else
		let pkg = words[0]
		let exported_name = words[1]
	endif

	let packages = go#tool#Imports()
	if has_key(packages, pkg)
		let pkg = packages[pkg]
	endif

	if exported_name != ""
		let h.search = '^func '.exported_name.'(\|^type '.exported_name.'\|\%(const\|var\|type\|\s\+\) '.pkg.'\s\+=\s'
	else
		let h.search = '\%(const\|var\|type\|\s\+\) '.pkg.'\s\+=\s'
	endif
	let h.topic = pkg
	let h.cmd = printf('%s %s', g:viewdoc_godoc_cmd, shellescape(pkg,1))
	return h
endfunction

function s:ViewDoc_godoc(topic, filetype, synid, ctx)
	return  { 'ft':		'go',
		\ 'topic':      b:topic,
		\ 'cmd':        printf('%s -src %s', g:viewdoc_godoc_cmd, shellescape(b:topic,1)),
		\ 'search':     '^func '.a:topic.'(\|^type '.a:topic.'\|\%(const\|var\|type\|\s\+\) '.a:topic.'\s\+=\s',
		\ }
endfunction

" use function(s:SID().'Foo') instead of function('s:Foo') for
" compatibility with Vim-7.3.x (7.3.762 at least)
function s:SID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction
let g:ViewDoc_go = function(s:SID().'ViewDoc_go')
let g:ViewDoc_godoc = function(s:SID().'ViewDoc_godoc')

