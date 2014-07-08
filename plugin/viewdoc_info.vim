" Author:               pawel.wiecek@tieto.com
" Maintainer:           pawel.wiecek@tieto.com
" Version:              see in viewdoc.vim
" Last Modified:        see in viewdoc.vim
" License:              see in viewdoc.vim
" URL:                  see in viewdoc.vim
" Description: ViewDoc handler for GNU info

if exists('g:loaded_viewdoc_info') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_info = 1

""" Options
" path of "info" program (original standalone info viewer)
if !exists('g:viewdoc_info_cmd')
	let g:viewdoc_info_cmd = 'info'
endif
" directories containing info files
if !exists('g:viewdoc_info_path')
	let g:viewdoc_info_path = '/usr/share/info'
endif

""" Interface
" - command
" Can be called:
"  - with no parameters, will load info directory
"  - with one parameter, will load named node (if in (file)node format) or top
"    page for named manual
"  - with two or more parameters, will use first parameter as manual name
"    (parentheses are optional) and all other parameters as node name
" eg. :ViewDocInfo gawk Getting Started   will load "(gawk)Getting Started"
command -bar -bang -nargs=* -complete=custom,s:CompleteInfo ViewDocInfo
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', s:ParamsToNode(<f-args>), 'infocmd')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> info  getcmdtype()==':' && getcmdline()=='info'  ? 'ViewDocInfo' : 'info'
	cnoreabbrev <expr> info! getcmdtype()==':' && getcmdline()=='info!' ? 'ViewDocInfo' : 'info!'
endif

""" Handlers

" Handler for navigation inside info file.
" Parsing logic does draw some inspiration from
" http://www.vim.org/scripts/script.php?script_id=21
" (especially in "note" links handling)
function s:ViewDoc_info(topic, filetype, synid, ctx)
	let h = { 'ft': 'info' }
	let nothing = { 'ft': 'info', 'cmd': 'false' }
	if a:ctx
		let current_line = getline('.')
		let same_file = matchstr(b:topic, '(.*)')
		" patterns below contain some empty groups \(\), this is intentional,
		" because we want to have link parts in the same groups, no matte whet
		" format the link has
		if synIDattr(a:synid, 'name') == 'infoLinkDir' ||
		\  synIDattr(a:synid, 'name') == 'infoDirTarget'
			" links in main directory
			let pattern = '^\* [^:]\+: \(([^)]\+)\)\([^.]*\)\.\(\)'
		elseif synIDattr(a:synid, 'name') == 'infoLinkMenu'
			" links in standard menu
			let pattern = '^\* \(\)\([^:]*\)::\(\)'
		elseif synIDattr(a:synid, 'name') == 'infoLinkIndex' ||
		\      synIDattr(a:synid, 'name') == 'infoIndexTarget' ||
		\      synIDattr(a:synid, 'name') == 'infoIndexLine'
			" links in index page -- sometimes line number is wrapped to next line,
			" so we concatenate it if current line alone doesn't match
			let pattern = '^\* [^:]\+:\s*\(\)\([^.]\+\)\.\s*(line\s\+\([0-9]\+\))$'
			if matchstr(current_line, pattern) == ''
				let current_line = current_line.' '.getline(line('.') + 1)
			endif
		elseif synIDattr(a:synid, 'name') == 'infoLinkNote'
			" "note" links inside pages, these can span multiple lines
			let current_line = current_line.' '.getline(line('.') + 1)
			let pattern = '\*[Nn]ote [^:.]\+: \([^.,]\+\)\%([,.]\|$\)'
			let link = matchlist(current_line, pattern)
			if link == []
				let pattern = '\*[Nn]ote \([^:]\+\)\%(::\)'
				let link = matchlist(current_line, pattern)
			endif
			let current_line = link[1]
			let pattern = '^\(([^)]\+)\)\=\s*\(.*\)\(\)'
		else
			" not inside a link -- not supported
			return nothing
		endif
		let link = matchlist(current_line, pattern)
		let file = link[1] !='' ? link[1] : same_file
		let node = link[2] !='' ? link[2] : 'Top'
		let h.topic = file . node
		if link[3] != ''
			let h.line = str2nr(link[3])
		endif
	else
		" not inside a link -- not supported
		return nothing
	endif
	let h.cmd = printf('%s %s -o-', g:viewdoc_info_cmd, shellescape(h.topic, 1))
	return h
endfunction

" Handler for keyword searching (needs to have g:ViewDocInfoIndex_{ft}
" defined, pointing to info node name (or list of names) of index
function s:ViewDoc_info_search(topic, filetype, synid, ctx)
	let nothing = { 'ft': 'info', 'cmd': 'false' }
	if exists('g:ViewDocInfoIndex_{a:filetype}')
		if type(g:ViewDocInfoIndex_{a:filetype}) == type([])
			let indices = g:ViewDocInfoIndex_{a:filetype}
		else
			let indices = [g:ViewDocInfoIndex_{a:filetype}]
		endif
	else
		return nothing
	endif
	let pattern = '^\* [^:]\+:\s*\(\)\([^.]\+\)\.\s*(line\s\+\([0-9]\+\))$'
	" open a temporary buffer and load indices
	let savetabnr = tabpagenr()
	silent noautocmd tabnew
	setlocal bufhidden=delete
	setlocal buftype=nofile
	setlocal noswapfile
	setlocal nobuflisted
	for idx in indices
		execute 'silent $r !' . g:viewdoc_info_cmd . ' ' . shellescape(s:FixNodeName(idx), 1)
	endfor
	1
	" search for a first matching index entry
	if search('^\* ' . a:topic . '\W')
		let current_line = getline('.')
		if matchstr(current_line, pattern) == ''
			let current_line = current_line.' '.getline(line('.') + 1)
		endif
	else
		let current_line = ''
	endif
	noautocmd tabclose!
	execute 'noautocmd tabnext ' . savetabnr
	if current_line == ''
		" not found
		return nothing
	endif
	" parse found link
	let link = matchlist(current_line, pattern)
	let file = link[1] !='' ? link[1] : matchstr(s:FixNodeName(indices[0]), '(.*)')
	let node = link[2] !='' ? link[2] : 'Top'
	let h = { 'ft': 'info',
		\ 'topic': file . node }
	if link[3] != ''
		let h.line = str2nr(link[3])
	endif
	let h.cmd = printf('%s %s -o-', g:viewdoc_info_cmd, shellescape(h.topic, 1))
	return h
endfunction

" Handler for command line commands
function s:ViewDoc_info_cmd(topic, ...)
	let h = { 'ft': 'info',
        	\ 'topic': s:FixNodeName(a:topic) }
	let h.cmd = printf('%s %s -o-', g:viewdoc_info_cmd, shellescape(h.topic, 1))
	return h
endfunction


""" Internal

" Converts :ViewDocInfo parameters to info node name to pass to ViewInfo as a
" topic
function s:ParamsToNode(...)
	if a:0 == 0
		return '(dir)Top'
	elseif a:0 == 1
		if a:1 =~ '^(.\+)'
			return a:1
		else
			return printf('(%s)Top', a:1)
		endif
	else
		if a:1 =~ '^(.\+)'
			return join(a:000, ' ')
		else
			return printf('(%s)%s', a:1, join(a:000[1:], ' '))
		endif
	endif
endfunction

" Helper to fix (file) parts where manuals have versioned filenames
function s:FixNodeName(node)
	let file = substitute(a:node, '^(\([^)]\+\)).*', '\1', '')
	if globpath('/usr/share/info', file.'.info*') == ''
		let filenames = split(globpath('/usr/share/info', file.'-*.info*'))
		let candidates = []
		for fn in filenames
			call add(candidates, substitute(fn, '^.*/\([^/]\+\)\.info.*$', '\1', ''))
		endfor
		if candidates != []
			return substitute(a:node, '('.file.')', '('.sort(candidates)[-1].')', '')
		endif
	endif
	return a:node
endfunction

" Completion generator
" Completes: manual names when invoked for 1st parameter,
" node names from manual, whose name is param1 when invoked for any other
" parameter
function s:CompleteInfo(ArgLead, CmdLine, CursorPos)
	let parts = split(strpart(a:CmdLine, 0, a:CursorPos).'|')
	if len(parts)>2
		let heads = system(g:viewdoc_info_cmd . ' --subnodes ' .
		\           shellescape(parts[1], 1) . " | grep '^File: .*,  Node:'")
		return substitute(heads, 'File: [^\n]*,  Node: \([^,]*\),  [^\n]*', '\1', 'g')
	else
		return substitute(substitute(globpath(g:viewdoc_info_path, '*.info*'),
		\                            '[^\n]*/\([^/]\+\).info[^\n]*', '\1', 'g'),
		\                 '\([^\n]*\n\)\1*', '\1', 'g')
  endif
endfunction


""" Per-type public settings

" per type exported configuration for (main) viewdoc
function s:SID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction
let g:ViewDoc_info      = function(s:SID().'ViewDoc_info')
let g:ViewDoc_infocmd   = function(s:SID().'ViewDoc_info_cmd')
let g:ViewDoc_search    = function(s:SID().'ViewDoc_info_search')
let g:ViewDoc_awk       = function(s:SID().'ViewDoc_info_search')
let g:ViewDoc_make      = function(s:SID().'ViewDoc_info_search')
let g:ViewDoc_m4        = function(s:SID().'ViewDoc_info_search')
let g:ViewDoc_automake  = function(s:SID().'ViewDoc_info_search')

" per type index node configuration
let g:ViewDocInfoIndex_awk = '(gawk)Index'
let g:ViewDocInfoIndex_make = '(make)Name Index'
let g:ViewDocInfoIndex_m4 = '(m4)Macro index'
let g:ViewDocInfoIndex_automake = ['(automake)Macro Index', '(automake)Variable Index']

