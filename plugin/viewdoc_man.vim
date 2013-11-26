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
let s:re_mansect = '\([0-9]p\?\|[mnlp]\|tcl\)'

""" Options
if !exists('g:viewdoc_sed_cmd')
	let g:viewdoc_sed_cmd='/bin/sed'	" path to gnu sed '/usr/local/bin/gsed' for *BSD
endif
if !exists('g:viewdoc_man_cmd')
	let g:viewdoc_man_cmd='/usr/bin/man'	" user may want 'LANG=en /usr/bin/man'
endif
if !exists('g:viewdoc_manpath_cmd')
	let g:viewdoc_manpath_cmd='/usr/bin/manpath'	" command used to get list of directories in which to look for man pages
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
function ViewDoc_man(topic, ...)
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
	return	{ 'cmd':	printf('%s %s %s | sed "s/ \xB7 / * /" | col -b', g:viewdoc_man_cmd, sect, shellescape(name,1)),
		\ 'ft':		'man',
		\ }
endfunction

let g:ViewDoc_man = function('ViewDoc_man')
if !exists('g:ViewDoc_DEFAULT')
	let g:ViewDoc_DEFAULT = function('ViewDoc_man')
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
		let res = system(printf('find $(%s|sed "s/:/ /g") -type f -iregex .\*man.\*/%s\..\* -print 2>/dev/null | %s -e "s/.*\///g" -e "s/\(.*\)\.\(.*\)\..*/\1(\2)/g" | sort -u', g:viewdoc_manpath_cmd, shellescape(m[1],1), g:viewdoc_sed_cmd))
	else
		let m = matchlist(a:CmdLine, '\s'.s:re_mansect.'\s')
		let sect = len(m) ? m[1] : '*'
		let res = system(printf('find $(%s|sed "s/:/ /g") -type f -ipath \*/man%s/\* -print 2>/dev/null | %s -e "s/.*\///g" -e "s/\.[^.]*\(\.bz2\|\.gz\)\{0,1\}$//" | sort -u', g:viewdoc_manpath_cmd, sect, g:viewdoc_sed_cmd))
	endif
	call ViewDoc_RestoreShell()
	return res
endfunction

