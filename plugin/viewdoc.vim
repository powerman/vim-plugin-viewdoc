" Maintainer: Alex Efros <powerman-asdf@ya.ru>
" Version: 1.3
" Last Modified: May 11, 2012
" License: This file is placed in the public domain.
" URL: http://www.vim.org/scripts/script.php?script_id=3893
" Description: Flexible viewer for any documentation (help/man/perldoc/etc.)

if exists('g:loaded_viewdoc') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc = 1


""" Constants
let s:bufname = '[Doc]'

""" Variables
let s:bufid = 0

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
if !exists('g:viewdoc_dontswitch')
	let g:viewdoc_dontswitch=0
endif
if !exists('g:viewdoc_copy_to_search_reg')
	let g:viewdoc_copy_to_search_reg=0
endif
if !exists('g:viewdoc_winwidth_max')
	let g:viewdoc_winwidth_max=0
endif

""" Interface
" - command
command -bar -bang -nargs=+ ViewDoc
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>)
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> doc  getcmdtype()==':' && getcmdline()=='doc'  ? 'ViewDoc'  : 'doc'
	cnoreabbrev <expr> doc! getcmdtype()==':' && getcmdline()=='doc!' ? 'ViewDoc!' : 'doc!'
endif
" - map
if !exists('g:no_plugin_maps') && !exists('g:no_viewdoc_maps')
	if g:viewdoc_copy_to_search_reg
		inoremap <unique> <F1>  <C-O>:let @/ = '\<'.expand('<cword>').'\>'<CR><C-O>:call ViewDoc('new', '<cword>')<CR>
		nnoremap <unique> <F1>  :let @/ = '\<'.expand('<cword>').'\>'<CR>:call ViewDoc('new', '<cword>')<CR>
		nnoremap <unique> K     :let @/ = '\<'.expand('<cword>').'\>'<CR>:call ViewDoc('doc', '<cword>')<CR>
	else
		inoremap <unique> <F1>  <C-O>:call ViewDoc('new', '<cword>')<CR>
		nnoremap <unique> <F1>  :call ViewDoc('new', '<cword>')<CR>
		nnoremap <unique> K     :call ViewDoc('doc', '<cword>')<CR>
	endif
endif
" - function
" call ViewDoc('new', '<cword>')		auto-detect context/syntax and file type
" call ViewDoc('doc', 'bash')			auto-detect only file type
" call ViewDoc('new', ':execute', 'help')	no auto-detect
function ViewDoc(target, topic, ...)
	let hh = s:GetHandles(a:topic, a:0 > 0 ? a:1 : &ft)

	if a:target != 'inplace'
		let prev_tabpagenr = tabpagenr()
		call s:OpenBuf(a:target)
		let b:stack = 0
	endif

	" Force same settings as :help does
	" https://bitbucket.org/ZyX_I/vim/src/8d8a30a648f05a91c3c433f0e01343649449ca3c/src/ex_cmds.c#cl-3523
	setlocal tabstop=8
	setlocal nolist
	setlocal nobinary
	setlocal nonumber
	if exists('&relativenumber')
		setlocal norelativenumber
	endif
	if has('arabic')
		setlocal noarabic
	endif
	if has('rightleft')
		setlocal norightleft
	endif
	if has('folding')
		setlocal nofoldenable
	endif
	if has('diff')
		setlocal nodiff
	endif
	if has('spell')
		setlocal nospell
	endif

	setlocal modifiable
	silent 1,$d
	for h in hh
		if exists('h.cmd')
			call ViewDoc_SetShellToBash()
			let winwidth = g:viewdoc_winwidth_max > 0 ? min([winwidth('.'), g:viewdoc_winwidth_max]) : winwidth('.')
			let h.cmd = substitute(h.cmd, '{{winwidth}}', winwidth, 'g')
			execute 'silent 0r ! ( ' . h.cmd . ' ) 2>/dev/null'
			call ViewDoc_RestoreShell()
			silent $d
			execute 'normal! ' . (exists('h.line') ? h.line : 1) . 'G'
			execute 'normal! ' . (exists('h.col')  ? h.col  : 1) . '|'
			if exists('h.search')
				call search(h.search)
			endif
			normal! zt
		endif

		let is_empty = line('$') == 1 && col('$') == 1
		if !is_empty
			break
		endif
	endfor
	setlocal nomodifiable nomodified

	execute 'setlocal ft=' . h.ft
	let b:topic = h.topic
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
	imap	 <silent> <buffer> <CR>		<C-O><C-]>
	imap	 <silent> <buffer> <BS>		<C-O><C-T>
	nmap	 <silent> <buffer> <CR>		<C-]>
	nmap	 <silent> <buffer> <BS>		<C-T>

	if is_empty && !g:viewdoc_openempty
		if a:target == 'inplace'
			call s:Prev()
		else
			call s:CloseBuf()
			unlet! prev_tabpagenr
		endif
	endif

	if g:viewdoc_dontswitch && exists('prev_tabpagenr')
		if prev_tabpagenr != tabpagenr()
			execute 'tabnext ' . prev_tabpagenr
		elseif winnr('$') > 1
			wincmd p
		else
			execute "normal! \<C-^>"
		endif
	endif

	if is_empty
		redraw | echohl ErrorMsg | echo 'Sorry, no doc for' h.topic | echohl None
	endif
endfunction

function ViewDoc_SetShellToBash()
	let s:_shell=&shell
	let s:_shellcmdflag=&shellcmdflag
	let s:_shellpipe=&shellpipe
	let s:_shellredir=&shellredir
	if !has('win16') && !has('win32') && !has('win64')
		setlocal shell=/bin/sh
		setlocal shellcmdflag=-c
		setlocal shellpipe=2>&1\|\ tee
		setlocal shellredir=>%s\ 2>&1
	endif
endfunction

function ViewDoc_RestoreShell()
	execute 'setlocal shell='.escape(s:_shell,'| ')
	execute 'setlocal shellcmdflag='.escape(s:_shellcmdflag,'| ')
	execute 'setlocal shellpipe='.escape(s:_shellpipe,'| ')
	execute 'setlocal shellredir='.escape(s:_shellredir,'| ')
endfunction

""" Internal

" let hh = s:GetHandles('<cword>', 'perl')	auto-detect syntax
" let hh = s:GetHandles('query', 'perl')	no auto-detect
" Return: [{
"	'topic':	'query',		ALWAYS
"	'ft':		'perldoc',		ALWAYS
"	'cmd':		'cat /path/to/file',	OPTIONAL
"	'line':		1,			OPTIONAL
"	'col':		1,			OPTIONAL
"	'tags':		'/path/to/tags',	OPTIONAL
"	'search':	'regex',		OPTIONAL
"	'docft':	'perl',			OPTIONAL
" },…]
function s:GetHandles(topic, ft)
	let cword = a:topic == '<cword>'
	let topic = cword ? expand('<cword>')		: a:topic
	let synid = cword ? synID(line('.'),col('.'),1)	: 0

	let h_type = exists('g:ViewDoc_{a:ft}') ? a:ft : 'DEFAULT'
	if type(g:ViewDoc_{h_type}) == type([])
		if len(g:ViewDoc_{h_type}) == 0
			let handlers = [ g:ViewDoc_DEFAULT ]
		else
			let handlers = g:ViewDoc_{h_type}
		endif
	else
		let handlers = [ g:ViewDoc_{h_type} ]
	endif

	let hh = []
	for Handler in handlers
		if type(Handler) == type("")
			let name = Handler
			if name !~# '^g:'
				let name = 'g:' . name
			endif
			unlet Handler
			if exists('{name}') && type({name}) == type(function("tr"))
				let Handler = {name}
			else
				echohl ErrorMsg | echo 'No such function:' name | echohl None | sleep 2
			endif
		endif
		let h = exists('Handler') ? Handler(topic, a:ft, synid, cword) : {}
		let h.topic	= exists('h.topic')	? h.topic	: topic
		let h.ft	= exists('h.ft')	? h.ft		: a:ft
		call add(hh, h)
		unlet Handler
	endfor
	return hh
endfunction

" Emulate doc stack a-la tag stack (<C-]> and <C-T>)
function s:Next()
	let b:stack = exists('b:stack') ? b:stack + 1	: 1
	let docft   = exists('b:docft') ? b:docft	: &ft
	if !exists('b:topic_stack')
		let b:topic_stack = []
	endif
	call add(b:topic_stack, b:topic)
	normal! msHmt`s
	call ViewDoc('inplace', '<cword>', docft)
endfunction

function s:Prev()
	if exists('b:stack') && b:stack
		let b:stack -= 1
		let b:topic = remove(b:topic_stack, -1)
		setlocal modifiable
		undo
		setlocal nomodifiable
		normal! 'tzt`s
	endif
endfunction

" call s:OpenBuf('doc')		open existing '[Doc]' buffer (create if not exists)
" call s:OpenBuf('new')		create and open new '[DocN]' buffer
function s:OpenBuf(target)
	let bufname = escape(s:bufname, '[]\')
	let [tabnr, winnr, bufnr] = s:FindBuf(bufname)

	if a:target == 'new'
		let s:bufid = s:bufid + 1
		let bufname = substitute(bufname, '\(\]\?\)$', s:bufid . '\1', '')
		execute g:viewdoc_open . ' ' . bufname
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
	let cond = g:viewdoc_only ? 'buflisted(v:val)' : 'buflisted(v:val) && bufloaded(v:val)'
	if len(filter( range(1,bufnr('$')), cond )) == 1
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

