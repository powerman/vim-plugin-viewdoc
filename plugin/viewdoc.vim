" Maintainer: Alex Efros <powerman-asdf@ya.ru>
" Version: 0.9
" Last Modified: Jan 18, 2012
" License: This file is placed in the public domain.
" URL: TODO
" Description: Flexible viewer for any documentation (help/man/perldoc/etc.)
" TODO Check idea about using syntax for detecting doc source.
" TODO Check correct &ft value for perldoc and pydoc - if it 'txt', then
"	store original &ft (and syntax) in b:something and use it to
"	lookup next doc inside this 'txt'.
" TODO Rethink handlers architecture.
" TODO Move some things (like iskeyword for help) from ~/.vimrc to
"	ftplugin/ here).
" TODO Add documentation, including this example:
"	function man() { vi -c "ViewDocMan $*" -c tabonly; }

if exists('g:loaded_viewdoc') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc = 1


""" Constants
let s:bufname = '[Doc]'
let s:re_mansect = '\([0-9n]p\?\)'

""" Options
if !exists('g:viewdoc_open')
	let g:viewdoc_open='tabnew'		" 'topleft new', 'belowright vnew', 'tabnew', etc.
endif
if !exists('g:viewdoc_only')
	let g:viewdoc_only=0
endif
if !exists('g:viewdoc_prevtabonclose')
	let g:viewdoc_prevtabonclose=1
endif
if !exists('g:viewdoc_handlers')
	let g:viewdoc_handlers = []		" default handlers defined below
endif
if !exists('g:viewdoc_cmd_man')
	let g:viewdoc_cmd_man='/usr/bin/man'	" user may want 'LANG= /usr/bin/man'
endif

""" Interface
" - command
command -bar -bang -nargs=1 -complete=custom,s:CompleteMan ViewDocMan
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'man')
command -bar -bang -nargs=1 -complete=help ViewDocHelp
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'help')
command -bar -bang -nargs=+ ViewDoc
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>)
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cabbrev <expr> man      getcmdline()=='man'     ? 'ViewDocMan'  : 'man'
	cabbrev <expr> help     getcmdline()=='help'    ? 'ViewDocHelp' : 'help'
	cabbrev <expr> doc      getcmdline()=='doc'     ? 'ViewDoc'	: 'doc'
endif
" - map
if !exists('g:no_plugin_maps') && !exists('g:no_viewdoc_maps')
	imap <unique> <F1>	<C-O>:call ViewDoc('new', expand('<cword>'))<CR>
	nmap <unique> <F1>	:call ViewDoc('new', expand('<cword>'))<CR>
	nmap <unique> K		:call ViewDoc('doc', expand('<cword>'))<CR>
endif
" - function
" call ViewDoc('doc', 'bash')
" call ViewDoc('new', ':execute', 'help')
function ViewDoc(target, topic, ...)
	let Fun = call('s:GetHandler', a:000)
	let h	= Fun(a:topic)

	if a:target != 'inplace'
		call s:OpenBuf(a:target)
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
		execute 'setlocal tags+=' . h.tags
	endif

	if line('$') == 1 && col('$') == 1
		redraw | echohl ErrorMsg | echo 'Sorry, no doc for' a:topic | echohl None
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
endfunction


""" Handlers
" - man
" Autocomplete section:			time(	ti.*(
" Autocomplete command:			tim	ti.*e
" Autocomplete command in section:	2 tim	2 ti.*e
function s:CompleteMan(ArgLead, CmdLine, CursorPos)
	let manpath = substitute(system(printf('%s --path', g:viewdoc_cmd_man)),'\n$','','')
	if manpath =~ ':'
		let manpath = '{'.join(map(split(manpath,':'),'shellescape(v:val,1)'),',').'}'
	else
		let manpath = shellescape(manpath,1)
	endif
	if strpart(a:CmdLine, a:CursorPos - 1) == '('
		let m = matchlist(a:CmdLine, '\s\(\S\+\)($')
		if !len(m)
			return ''
		endif
		return system(printf('find %s/man* -type f -regex ".*/"%s"\.[0-9n]p?\(\.bz2\|\.gz\)?" -printf "%%f\n" 2>/dev/null | sed "s/\.bz2$\|\.gz$//;s/.*\///;s/\.\([^.]\+\)$/(\1)/"',
			\ manpath, shellescape(m[1],1)))
	else
		let m = matchlist(a:CmdLine, '\s'.s:re_mansect.'\s')
		let sect = len(m) ? m[1] : '*'
		return system(printf('find %s/man%s -type f -printf "%%f\n" 2>/dev/null | sed "s/\.bz2$\|\.gz$//;s/\.[^.]*$//" | sort -u',
			\ manpath, sect))
	endif
endfunction
" let h = ViewDocHandleMan('time')
" let h = ViewDocHandleMan('time(2)')
" let h = ViewDocHandleMan('2 time')
function ViewDocHandleMan(topic)
	let sect = ''
	let name = a:topic
	let m = matchlist(name, '('.s:re_mansect.')$')
	if (len(m))
		let sect = m[1]
		let name = substitute(name, '('.s:re_mansect.')$', '', '')
	endif
	let m = matchlist(name, '^'.s:re_mansect.'\s\+')
	if (len(m))
		let sect = m[1]
		let name = substitute(name, '^'.s:re_mansect.'\s\+', '', '')
	endif
	return	{ 'cmd':	printf('%s %s %s | col -b', g:viewdoc_cmd_man, sect, shellescape(name,1)),
		\ 'ft':		'man',
		\ }
endfunction
" - help
function ViewDocHandleHelp(topic)
	let h = { 'ft':		'help',
		\ }
	try
		let savetabnr	= tabpagenr()
		execute 'tab help ' . a:topic
		let helpfile	= bufname(bufnr(''))
		let h.cmd	= printf('cat %s', shellescape(helpfile,1))
		let h.line	= line('.')
		let h.col	= col('.')
		let h.tags	= substitute(helpfile, '/[^/]*$', '/tags', '')
		tabclose
		execute 'tabnext ' . savetabnr
	catch
	endtry
	return h
endfunction
function ViewDocHandleFtHelp(topic)
	for p in split(globpath(&runtimepath, 'ftdoc/css'))
		execute 'setlocal runtimepath^=' . p
	endfor
	return ViewDocHandleHelp(a:topic)
endfunction
" - perl
function ViewDocHandlePerl(topic)
	let t = shellescape(a:topic,1)
	return	{ 'cmd':	printf('perldoc %s || perldoc -f %s || perldoc -v %s',t,t,t),
		\ 'ft':		'perldoc',
		\ }
endfunction
" - python
function ViewDocHandlePython(topic)
	return	{ 'cmd':	printf('pydoc %s', shellescape(a:topic,1)),
		\ 'ft':		'pydoc',
		\ }
endfunction
" - setup handlers
let g:viewdoc_handlers += [
	\ ['man',	'',	function('ViewDocHandleMan')],
	\ ['help',	'',	function('ViewDocHandleHelp')],
	\ ['vim',	'',	function('ViewDocHandleHelp')],
	\ ['perl',	'',	function('ViewDocHandlePerl')],
	\ ['python',	'',	function('ViewDocHandlePython')],
	\ ['css',	'',	function('ViewDocHandleFtHelp')],
	\ ]
let g:ViewDocHandleDefault = function('ViewDocHandleMan')


"""
""" Internal
"""

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
	return g:ViewDocHandleDefault
endfunction

" Emulate doc stack a-la tag stack (<C-]> and <C-T>)
function s:Next()
	let b:stack = exists('b:stack') ? b:stack + 1 : 1
	normal msHmt`s
	call ViewDoc('inplace', expand('<cword>'))
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

