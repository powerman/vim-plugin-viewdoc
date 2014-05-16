" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for OS Inferno man pages

if exists('g:loaded_viewdoc_infman') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_infman = 1

""" Constants
let s:re_mansect = '\([1-9]\|10\)'

""" Options
if !exists('g:viewdoc_infman_cmd')
	let g:viewdoc_infman_cmd='bash -c ''emu-g sh -c "run /lib/sh/profile; $*; shutdown -h"'' --'
endif

""" Interface
" - command
command -bar -bang -nargs=1 -complete=custom,s:CompleteInfman ViewDocInfman
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'infman')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> infman   getcmdtype()==':' && getcmdline()=='infman'  ? 'ViewDocInfman'  : 'infman'
	cnoreabbrev <expr> infman!  getcmdtype()==':' && getcmdline()=='infman!' ? 'ViewDocInfman'  : 'infman!'
endif

""" Handlers

" let h = ViewDoc_infman('time')
" let h = ViewDoc_infman('time(2)')
" let h = ViewDoc_infman('2 time')
function s:ViewDoc_infman(topic, ...)
	let sect = ''
	let name = a:topic
	let m = matchlist(name, '('.s:re_mansect.')\.\?$')
	if (len(m))
		let sect = m[1]
		let name = substitute(name, '('.s:re_mansect.')\.\?$', '', '')
	endif
	let m = matchlist(name, '^'.s:re_mansect.'\s\+')
	if (len(m))
		let sect = m[1]
		let name = substitute(name, '^'.s:re_mansect.'\s\+', '', '')
	endif
	return	{ 'cmd':	printf('%s man %s %s',
		\			g:viewdoc_infman_cmd, sect, shellescape(name,1)),
		\ 'ft':		'infman',
		\ }
endfunction

" use function(s:SID().'Foo') instead of function('s:Foo') for
" compatibility with Vim-7.3.x (7.3.762 at least)
function s:SID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction
let g:ViewDoc_infman = function(s:SID().'ViewDoc_infman')
let g:ViewDoc_limbo  = function(s:SID().'ViewDoc_infman')


""" Internal

" Autocomplete section:			time(	ti.*(
" Autocomplete command:			tim	ti.*e
" Autocomplete command in section:	2 tim	2 ti.*e
function s:CompleteInfman(ArgLead, CmdLine, CursorPos)
	call ViewDoc_SetShellToBash()
	if strpart(a:CmdLine, a:CursorPos - 1) == '('
		let m = matchlist(a:CmdLine, '\s\(\S\+\)($')
		if !len(m)
			call ViewDoc_RestoreShell()
			return ''
		endif
		let res = system(printf('%s man -w %s | sed ''s/\/man\/\([0-9]\+\)\/\(.*\)/\2(\1)/''',
			\ g:viewdoc_infman_cmd, shellescape(m[1],1)))
	else
		let m = matchlist(a:CmdLine, '\s'.s:re_mansect.'\s')
		let sect = len(m) ? m[1] : '*'
		let res = system(printf('%s cat /man/%s/INDEX | sed "s/ .*//" | sort -u',
			\ g:viewdoc_infman_cmd, sect))
	endif
	call ViewDoc_RestoreShell()
	return res
endfunction

