" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for php man pages

if exists('g:loaded_viewdoc_pman') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_pman = 1

""" Constants
let s:re_mansect = '\([0-9]\)'

""" Options
if !exists('g:viewdoc_pman_cmd')
	let g:viewdoc_pman_cmd='pman'
endif

""" Interface
" - command
command -bar -bang -nargs=1 -complete=custom,s:CompleteMan ViewDocPman
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'pman')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> pman     getcmdtype()==':' && getcmdline()=='pman'  ? 'ViewDocPman'  : 'pman'
	cnoreabbrev <expr> pman!    getcmdtype()==':' && getcmdline()=='pman!' ? 'ViewDocPman'  : 'pman!'
endif

""" Handlers

" let h = ViewDoc_pman('error_reporting')
" let h = ViewDoc_pman('error_reporting(3)')
" let h = ViewDoc_pman('2 error_reporting')
function s:ViewDoc_pman(topic, ...)
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
	return	{ 'cmd':	printf('%s %s %s | sed "s/ \xB7 / * /" | col -b', g:viewdoc_pman_cmd, sect, shellescape(name,1)),
		\ 'ft':		'pman',
		\ }
endfunction

" use function(s:SID().'Foo') instead of function('s:Foo') for
" compatibility with Vim-7.3.x (7.3.762 at least)
function s:SID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction
let g:ViewDoc_pman = function(s:SID().'ViewDoc_pman')
let g:ViewDoc_php  = function(s:SID().'ViewDoc_pman')


""" Internal

" Autocomplete section:			time(	ti.*(
" Autocomplete command:			tim	ti.*e
" Autocomplete command in section:	2 tim	2 ti.*e
function s:CompleteMan(ArgLead, CmdLine, CursorPos)
	call ViewDoc_SetShellToBash()
	let manpath = substitute(system(printf('%s --path', g:viewdoc_pman_cmd)),'\n$','','')
	if manpath =~ ':'
		let manpath = '{'.join(map(split(manpath,':'),'shellescape(v:val,1)'),',').'}'
	else
		let manpath = shellescape(manpath,1)
	endif
	if strpart(a:CmdLine, a:CursorPos - 1) == '('
		let m = matchlist(a:CmdLine, '\s\(\S\+\)($')
		if !len(m)
			call ViewDoc_RestoreShell()
			return ''
		endif
		let res = system(printf('find %s/man* -type f -regex ".*/"%s"\.[0-9]\(\.bz2\|\.gz\)?" -printf "%%f\n" 2>/dev/null | sed "s/\.bz2$\|\.gz$//;s/.*\///;s/\.\([^.]\+\)$/(\1)/"',
			\ manpath, shellescape(m[1],1)))
	else
		let m = matchlist(a:CmdLine, '\s'.s:re_mansect.'\s')
		let sect = len(m) ? m[1] : '*'
		let res = system(printf('find %s/man%s -type f -printf "%%f\n" 2>/dev/null | sed "s/\.bz2$\|\.gz$//;s/\.[^.]*$//" | sort -u',
			\ manpath, sect))
	endif
	call ViewDoc_RestoreShell()
	return res
endfunction

