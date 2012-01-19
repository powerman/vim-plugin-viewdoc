" Maintainer: Alex Efros <powerman-asdf@ya.ru>
" Version: 1.0
" Last Modified: Jan 19, 2012
" License: This file is placed in the public domain.
" URL: http://www.vim.org/scripts/script.php?script_id=3893
" Description: Flexible viewer for any documentation (help/man/perldoc/etc.)
" TODO Add option to not switch to opened documentation window.

if exists('g:loaded_viewdoc') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc = 1


""" Constants
let s:bufname = '[Doc]'

""" Options
if !exists('g:viewdoc_open')
	let g:viewdoc_open='tabnew'
endif
if !exists('g:viewdoc_only')
	let g:viewdoc_only=0
endif
if !exists('g:viewdoc_prevtabonclose')
	let g:viewdoc_prevtabonclose=1
endif
if !exists('g:viewdoc_openempty')
	let g:viewdoc_openempty=1
endif

""" Interface
" - command
command -bar -bang -nargs=+ ViewDoc
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>)
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cabbrev <expr> doc      getcmdtype()==':' && getcmdline()=='doc'  ? 'ViewDoc'	  : 'doc'
	cabbrev <expr> doc!     getcmdtype()==':' && getcmdline()=='doc!' ? 'ViewDoc!'	  : 'doc!'
endif
" - map
if !exists('g:no_plugin_maps') && !exists('g:no_viewdoc_maps')
	imap <unique> <F1>	<C-O>:call ViewDoc('new', '<cword>')<CR>
	nmap <unique> <F1>	:call ViewDoc('new', '<cword>')<CR>
	nmap <unique> K		:call ViewDoc('doc', '<cword>')<CR>
endif
" - function
" call ViewDoc('new', '<cword>')		auto-detect context/syntax and file type
" call ViewDoc('doc', 'bash')			auto-detect only file type
" call ViewDoc('new', ':execute', 'help')	no auto-detect
function ViewDoc(target, topic, ...)
	let h = s:GetHandle(a:topic, a:0 > 0 ? a:1 : &ft)

	if a:target != 'inplace'
		call s:OpenBuf(a:target)
		let b:stack = 0
	endif

	setlocal modifiable
	silent 1,$d
	if exists('h.cmd')
		execute 'silent 0r ! ( ' . h.cmd . ' ) 2>/dev/null'
		silent $d
		execute 'normal ' . (exists('h.line') ? h.line : 1) . 'G'
		execute 'normal ' . (exists('h.col')  ? h.col  : 1) . '|'
		normal zt
	endif
	setlocal nomodifiable nomodified

	execute 'setlocal ft=' . h.ft
	if exists('h.tags')
		execute 'setlocal tags^=' . h.tags
	endif
	if exists('h.docft')
		let b:docft = h.docft
	endif

	inoremap <silent> <buffer> q		<C-O>:call <SID>CloseBuf()<CR>
	nnoremap <silent> <buffer> q		:call <SID>CloseBuf()<CR>
	vnoremap <silent> <buffer> q		<Esc>:call <SID>CloseBuf()<CR>
	inoremap <silent> <buffer> <C-]>	<C-O>:call <SID>Next()<CR>
	inoremap <silent> <buffer> <C-T>	<C-O>:call <SID>Prev()<CR>
	nnoremap <silent> <buffer> <C-]>	:call <SID>Next()<CR>
	nnoremap <silent> <buffer> <C-T>	:call <SID>Prev()<CR>
	imap <silent> <buffer> <CR>		<C-O><C-]>
	imap <silent> <buffer> <BS>		<C-O><C-T>
	nmap <silent> <buffer> <CR>		<C-]>
	nmap <silent> <buffer> <BS>		<C-T>

	if line('$') == 1 && col('$') == 1
		if !g:viewdoc_openempty
			normal q
		endif
		redraw | echohl ErrorMsg | echo 'Sorry, no doc for' h.topic | echohl None
	endif
endfunction


""" Internal

" let h = s:GetHandle('<cword>', 'perl')	auto-detect syntax
" let h = s:GetHandle('query', 'perl')		no auto-detect
" Return: {
"	'topic':	'query',		ALWAYS
"	'ft':		'perldoc',		ALWAYS
"	'cmd':		'cat /path/to/file',	OPTIONAL
"	'line':		1,			OPTIONAL
"	'col':		1,			OPTIONAL
"	'tags':		'/path/to/tags',	OPTIONAL
"	'docft':	'perl',			OPTIONAL
" }
function s:GetHandle(topic, ft)
	let cword = a:topic == '<cword>'
	let topic = cword ? expand('<cword>')		: a:topic
	let synid = cword ? synID(line('.'),col('.'),1)	: 0

	let handler = exists('*g:ViewDoc_{a:ft}') ? a:ft : 'DEFAULT'
	let h = g:ViewDoc_{handler}(topic, a:ft, synid, cword)

	let h.topic	= exists('h.topic')	? h.topic	: topic
	let h.ft	= exists('h.ft')	? h.ft		: a:ft
	return h
endfunction

" Emulate doc stack a-la tag stack (<C-]> and <C-T>)
function s:Next()
	let b:stack = exists('b:stack') ? b:stack + 1	: 1
	let docft   = exists('b:docft') ? b:docft	: &ft
	normal msHmt`s
	call ViewDoc('inplace', '<cword>', docft)
endfunction

function s:Prev()
	if exists('b:stack') && b:stack
		let b:stack -= 1
		setlocal modifiable
		undo
		setlocal nomodifiable
		normal 'tzt`s
	endif
endfunction

" call s:OpenBuf('doc')		open existing '[Doc]' buffer (create if not exists)
" call s:OpenBuf('new')		create and open new '[Scratch]' buffer
function s:OpenBuf(target)
	let bufname = escape(s:bufname, '[]\')
	let [tabnr, winnr, bufnr] = s:FindBuf(bufname)

	if a:target == 'new'
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

