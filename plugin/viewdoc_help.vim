" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for vim help files

if exists('g:loaded_viewdoc_help') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_help = 1


""" Interface
" - command
command -bar -bang -nargs=1 -complete=help ViewDocHelp
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'help')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cabbrev <expr> help     getcmdtype()==':' && getcmdline()=='help' ? 'ViewDocHelp' : 'help'
endif

""" Handlers

function g:ViewDoc_help(topic, ...)
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

let g:ViewDoc_vim = function('g:ViewDoc_help')

function g:ViewDoc_help_custom(topic, ...)
	for p in split(globpath(&runtimepath, 'ftdoc/css'))
		execute 'setlocal runtimepath^=' . p
	endfor
	return g:ViewDoc_help(a:topic)
endfunction

let g:ViewDoc_css = function('g:ViewDoc_help_custom')

