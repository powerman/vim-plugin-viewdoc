" Author:               pawel.wiecek@tieto.com
" Maintainer:           john.ch.fr@gmail.com
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
"  - with one or more parameters, should behave identically to GNU Info.
command -bar -bang -nargs=* -complete=customlist,s:CompleteInfo ViewDocInfo
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
		if synIDattr(a:synid, 'name') == 'infoNavLink'
			" links in the top navigation line
			let nav_match = matchlist(getline('.')[:col('.')], '^File:.*\(Prev\|Next\|Up\): \(.\)')
			let nav = nav_match[1]
			if nav_match[2] == '('
				let pattern = '^File: .*' . nav . ': \([^,]*\)\(\)\(\)'
			else
				let pattern = '^File: .*' . nav . ': \(\)\([^,]*\)\(\)'
			endif
		elseif synIDattr(a:synid, 'name') == 'infoLinkDir' ||
		\      synIDattr(a:synid, 'name') == 'infoDirTarget'
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
			if match(current_line, '\*[Nn]ote') < 0
				let prev_line = getline(line('.') - 1)
				let current_line = prev_line[match(prev_line, '.*\zs\*[Nn]ote'):].' '.current_line
			else
				let current_line = current_line.' '.getline(line('.') + 1)
			endif
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
		let file = same_file
		if link[1] != ''
			let file = s:FixNodeName(link[1])
		endif
		let node = link[2] != '' ? link[2] : 'Top'
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
	let nothing = { 'ft': 'info', 'cmd': 'false', 'topic': a:topic }
	let h = { 'ft': 'info',
		\ 'topic': s:FixNodeName(a:topic) }
	let h.cmd = printf('%s %s -o-', g:viewdoc_info_cmd, shellescape(h.topic, 1))
	if h.topic == ''
		return nothing
	endif
	return h
endfunction


""" Internal

" Converts :ViewDocInfo parameters to info node name to pass to ViewInfo as a
" topic
function s:ParamsToNode(...)
	if a:0 == 0
		return '(dir)Top'
	else
		let args = copy(a:000)
		if args[0][0] == '('
			let args[0] = s:FixNodeName(args[0])
		endif
		let sh_args =  join(map(args, 'shellescape(v:val)'), ' ')
		return system(printf('%s %s -o- | head -n 2', g:viewdoc_info_cmd, sh_args) .
		\             ' | sed -n ''s/^File: \(.*\)\.info.*,  Node: \([^,]*\),.*/(\1)\2/p''')
	endif
endfunction

" Helper to fix (file) parts where manuals have versioned filenames
function s:FixNodeName(node)
	let file = substitute(a:node, '^(\([^)]\+\)).*', '\1', '')
	if globpath(g:viewdoc_info_path, file.'.info*') == ''
		let filenames = split(globpath(g:viewdoc_info_path, file.'-*.info*'))
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
	let line = join(split(a:CmdLine[0:a:CursorPos])[1:], ' ')
	let lead = substitute(a:ArgLead, '\\', '', 'g')
	let trail = split(line[:-len(a:ArgLead)-1], '[^\\]\zs ')
	let base_cmd = g:viewdoc_info_cmd . " '(dir)Top' -o- 2>/dev/null"
	let keys_pipe = ' | sed -n ''s/\* \([^:]*\): (.*/\1/p'''
	if len(trail) == 0
		if len(lead) == 0
			return split(escape(system(base_cmd . keys_pipe), ' '), "\n")
		endif
		let pipe = keys_pipe
		if lead[0] == '('
			let pipe = ' | sed -n ''s/\* [^:]*: \(([^.]*\)\..*/\1/p'' | sort | uniq'
		endif
	else
		let pipe = ' | sed -e ''/^\* Menu:/,$ !d'' -n -e ''s/^\* \([^:]*\)::.*/\1/ p'''
		let args = join(map(trail, 'shellescape(v:val)'), ' ')
		let base_cmd = substitute(base_cmd, "'(dir)Top'", args, '')
	endif
	return split(escape(system(base_cmd . pipe . " | sed -n " . shellescape("/^" . lead . "/Ip")), ' '), "\n")
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

