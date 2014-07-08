" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for man pages (default handler)

if exists('g:loaded_viewdoc_man') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_man = 1

""" Constants
let s:re_mansect = '\([0-9a-z]\+\)'

""" Options
if !exists('g:viewdoc_man_cmd')
	let g:viewdoc_man_cmd='man'	        " user may want 'LANG=en man'
endif

""" Interface
" - command
command -bar -bang -nargs=1 -complete=custom,s:CompleteMan ViewDocMan
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'man')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> man      getcmdtype()==':' && getcmdline()=='man'  ? 'ViewDocMan'  : 'man'
	cnoreabbrev <expr> man!     getcmdtype()==':' && getcmdline()=='man!' ? 'ViewDocMan'  : 'man!'
endif

""" Handlers

" let h = ViewDoc_man('time')
" let h = ViewDoc_man('time(2)')
" let h = ViewDoc_man('2 time')
function s:ViewDoc_man(topic, ...)
	let sect = ''
	let name = a:topic
	let m = matchlist(name, '('.s:re_mansect.')\.\?$')
	if (len(m))
		let sect = '-S '.m[1]
		let name = substitute(name, '('.s:re_mansect.')\.\?$', '', '')
	endif
	let m = matchlist(name, '^'.s:re_mansect.'\s\+')
	if (len(m))
		let sect = '-S '.m[1]
		let name = substitute(name, '^'.s:re_mansect.'\s\+', '', '')
	endif
	return	{ 'cmd':	printf('MANWIDTH={{winwidth}} %s %s %s | sed "s/ \xB7 / * /" | col -b', g:viewdoc_man_cmd, sect, shellescape(name,1)),
		\ 'ft':		'man',
		\ }
endfunction

" use function(s:SID().'Foo') instead of function('s:Foo') for
" compatibility with Vim-7.3.x (7.3.762 at least)
function s:SID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction
let g:ViewDoc_man = function(s:SID().'ViewDoc_man')
if !exists('g:ViewDoc_DEFAULT')
	let g:ViewDoc_DEFAULT = g:ViewDoc_man
endif


""" Internal

" Autocomplete section:			time(	ti.*(
" Autocomplete command:			tim	ti.*e
" Autocomplete command in section:	2 tim	2 ti.*e
function s:CompleteMan(ArgLead, CmdLine, CursorPos)
	call ViewDoc_SetShellToBash()
	if strpart(a:CmdLine, a:CursorPos - 1) == '('
		let m = matchlist(a:CmdLine, '\s\(\S\+\)($')
		if !len(m)
			call ViewDoc_RestoreShell()
			return ''
		endif
		let res = system(printf('find $(manpath 2>/dev/null | sed "s/:/ /g") -type f -iregex ".*/man[0-9a-z][0-9a-z]*/"%s"\..*" 2>/dev/null | sed "s/.*\/man\([^/]*\/\)/\1/; s/\.bz2$//; s/\.gz$//; s/\(.*\)\/\(.*\)\.[^.]*$/\2(\1)/" | sort -u', shellescape(m[1],1)))
	else
		let m = matchlist(a:CmdLine, '\s'.s:re_mansect.'\s')
		let sect = len(m) ? m[1] : '*'
		let res = system(printf('find $(manpath 2>/dev/null | sed "s/:/ /g") -type f -path "*/man%s/*" 2>/dev/null | sed "s/.*\///; s/\.bz2$//; s/\.gz$//; s/\.[^.]*$//" | sort -u', sect))
	endif
	call ViewDoc_RestoreShell()
	return res
endfunction

