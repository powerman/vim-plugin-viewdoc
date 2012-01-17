" Maintainer: Alex Efros <powerman-asdf@ya.ru>
" Version: 0.9
" Last Modified: Jan 17, 2012
" License: This file is placed in the public domain.
" URL: TODO
" Description: Flexible viewer for any documentation (help/man/perldoc/etc.)
" TODO Rethink handlers architecture.
" TODO Add documentation, including this example:
"	function man() { local p=($2 $1); vi -c "ViewDoc ${p[0]}(${p[1]})" -c tabonly; }

if exists('g:loaded_viewdoc') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc = 1

if !exists('g:viewdoc_open')
	let g:viewdoc_open='tabnew'	" 'topleft new', 'belowright vnew', 'tabnew', etc.
endif
if !exists('g:viewdoc_only')
	let g:viewdoc_only=0
endif
if !exists('g:viewdoc_prevtabonclose')
	let g:viewdoc_prevtabonclose=1
endif
if !exists('g:viewdoc_handlers')
	let g:viewdoc_handlers = []	" see default handlers at end of this file
endif
if !exists('g:no_plugin_maps') && !exists('g:no_viewdoc_maps')
	imap <unique> <F1>	<C-O>:call ViewDoc(expand("<cword>"))<CR>
	nmap <unique> <F1>	:call ViewDoc(expand("<cword>"))<CR>
	nmap <unique> K		:call ViewDocMain(expand("<cword>"))<CR>
endif

command -bang -nargs=+ -bar ViewDoc
	\ if '<bang>'=='!' | call ViewDocMain(<f-args>) | else | call ViewDoc(<f-args>) | endif
command -bang -nargs=1 -bar -complete=help ViewDocVim
	\ if '<bang>'=='!' | call ViewDocMain(<f-args>,'vim') | else | call ViewDoc(<f-args>,'vim') | endif

let s:bufname	= '[Doc]'
let s:target	= { 'main': 0, 'scratch': 1, 'inplace': 2 }



function ViewDoc(topic, ...)
	call call('s:View', [ s:target.scratch, a:topic ] + a:000)
endfunction

function ViewDocMain(topic, ...)
	call call('s:View', [ s:target.main, a:topic ] + a:000)
endfunction

function ViewDocInplace(topic, ...)
	call call('s:View', [ s:target.inplace, a:topic ] + a:000)
endfunction

function ViewDocHandleMan(topic)
	let m = matchlist(a:topic, '(\([0-9a-zA-Z]\+\))')
	let sect = len(m) ? m[1] : ''
	let name = substitute(a:topic, '(.*$', '', '')
	return	{ 'cmd':	'man ' . sect . ' ' . shellescape(name) . ' | col -b 2>/dev/null',
		\ 'ft':		'man',
		\ }
endfunction

function ViewDocHandleHelp(topic)
	let h = {}
	try
		let savetabnr	= tabpagenr()
		execute 'tab help ' . a:topic
		let helpfile	= bufname(bufnr(''))
		let h.cmd	= 'cat ' . shellescape(helpfile)
		let h.line	= line('.')
		let h.col	= col('.')
		let h.ft	= 'help'
		let h.iskeyword = '!-~,^*,^\|,^\",192-255'
		let h.tags	= substitute(helpfile, '/[^/]*$', '/tags', '')
		tabclose
		execute 'tabnext ' . savetabnr
	catch
		let h.cmd	= 'echo Sorry, no help for ' . shellescape(a:topic)
		let h.ft	= 'txt'
	endtry
	return h
endfunction

function ViewDocHandleFtHelp(topic)
	for p in split(globpath(&runtimepath, 'ftdoc/css'))
		execute 'setlocal runtimepath^=' . p
	endfor
	return ViewDocHandleHelp(a:topic)
endfunction

function ViewDocHandlePerl(topic)
	let cmd = '	perldoc '	. shellescape(a:topic) . ' 2>/dev/null'
	let cmd .= ' || perldoc -f '	. shellescape(a:topic) . ' 2>/dev/null'
	let cmd .= ' || perldoc -v '	. shellescape(a:topic)
	return	{ 'cmd':	cmd,
		\ 'ft':		'perldoc',
		\ }
endfunction

function ViewDocHandlePython(topic)
	return	{ 'cmd':	'pydoc ' . shellescape(a:topic),
		\ 'ft':		'pydoc',
		\ }
endfunction



let g:viewdoc_handlers += [
	\ ['vim',	'',	function('ViewDocHandleHelp')],
	\ ['help',	'',	function('ViewDocHandleHelp')],
	\ ['perl',	'',	function('ViewDocHandlePerl')],
	\ ['python',	'',	function('ViewDocHandlePython')],
	\ ['css',	'',	function('ViewDocHandleFtHelp')],
	\ ]



" Emulate tag stack for <C-]> and <C-T>
function s:Next()
	let b:stack = exists('b:stack') ? b:stack + 1 : 1
	normal ma
	call ViewDocInplace(expand("<cword>"))
endfunction

function s:Prev()
	if exists('b:stack') && b:stack
		let b:stack -= 1
		setlocal modifiable
		undo
		setlocal nomodifiable
		normal `a
	endif
endfunction

" call View(s:target.main,	 'bash')
" call View(s:target.scratch, ':execute', 'vim')
" call View(s:target.inplace, 'BufRead',  'vim', 'vimAutoEvent')
function s:View(target, topic, ...)
	let Fun = call('s:GetHandler', a:000)
	let h	= Fun(a:topic)

	if a:target != s:target.inplace
		call s:OpenBuf(a:target)
	endif

	setlocal modifiable
	silent 1,$d
	execute 'silent 0r !' . h.cmd
	silent $d
	execute 'normal ' . (exists('h.line') ? h.line : 1) . 'G'
	execute 'normal ' . (exists('h.col')  ? h.col  : 1) . '|'
	setlocal nomodifiable nomodified

	execute 'setlocal ft=' . h.ft
	if exists('h.tags')
		execute 'setlocal tags+=' . h.tags
	endif
	if exists('h.iskeyword')
		execute 'setlocal iskeyword=' . h.iskeyword
	endif

	inoremap <silent> <buffer> q		<C-O>:call <SID>CloseBuf()<CR>
	nnoremap <silent> <buffer> q		:call <SID>CloseBuf()<CR>
	vnoremap <silent> <buffer> q		<Esc>:call <SID>CloseBuf()<CR>
	nnoremap <silent> <buffer> <C-]>	:call <SID>Next()<CR>
	nnoremap <silent> <buffer> <C-T>	:call <SID>Prev()<CR>
endfunction

" let Fun = s:GetHandler()			auto-detect filetype and syntax
" let Fun = s:GetHandler('filetype')		auto-detect only syntax
" let Fun = s:GetHandler('filetype', 'Syntax')	no auto-detect
" Return: Funcref to best handler for given filetype and syntax.
function s:GetHandler(...)
	let ft	= a:0 > 0 ? a:1 : &ft
	let syn = a:0 > 1 ? a:2 : synIDattr(synID(line('.'),col('.'),0) ,'name')

	for [filetype,synregex,Fun] in g:viewdoc_handlers
		if ft == filetype && syn =~? synregex
			return Fun
		endif
	endfor
	return function('ViewDocHandleMan')
endfunction

" call s:OpenBuf(0)	open existing '[Doc]' buffer (create if not exists)
" call s:OpenBuf(1)	create and open new '[Scratch]' buffer
function s:OpenBuf(target)
	let bufname = escape(s:bufname, '[]\')
	let [tabnr, winnr, bufnr] = s:FindBuf(bufname)

	if a:target == s:target.scratch
		execute g:viewdoc_open
	elseif tabnr == -1
		execute g:viewdoc_open . ' ' . bufname
	else
		execute 'tabnext ' . tabnr
		execute winnr . 'wincmd w'
	endif
	if g:viewdoc_only
		only!
	endif
	setlocal noswapfile buflisted buftype=nofile bufhidden=hide
endfunction

" Close buffer with doc, and optionally move to previous tab.
" Quit if closing last buffer.
function s:CloseBuf()
	if len(filter( range(1,bufnr('$')), 'buflisted(v:val)' )) == 1
		q
	elseif winnr('$') > 1 || !g:viewdoc_prevtabonclose
		bwipeout
	else
		let tabnr = tabpagenr()
		bwipeout
		if tabnr == tabpagenr()
			tabprevious
		endif
	endif
endfunction

" let [tabnr, winnr, bufnr] = s:FindBuf(bufname)
" Return:
"	[-1, -1, -1] if buf not exists
"	[-1, -1,  Z] if buf not visible
"	[ X,  Y,  Z] if buf visible
function s:FindBuf(bufname)
	let bufnr = bufnr('^' . a:bufname . '$')
	if bufnr == -1
		return [-1, -1, -1]
	endif

	let tabnr = -1
	for t in range(1, tabpagenr('$'))
		for nr in tabpagebuflist(t)
			if nr == bufnr
				let tabnr = t
				break
			endif
		endfor
		if tabnr != -1
			break
		endif
	endfor
	if tabnr == -1
		return [-1, -1, bufnr]
	endif

	let savetabnr = tabpagenr()
	execute 'tabnext ' . tabnr
	let winnr = bufwinnr(bufnr)
	execute 'tabnext ' . savetabnr
	return [tabnr, winnr, bufnr]
endfunction

