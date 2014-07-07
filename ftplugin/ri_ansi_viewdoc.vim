if exists('b:did_ftplugin_viewdoc')
	finish
endif
let b:did_ftplugin_viewdoc = 1


if exists(':AnsiEsc')
	if exists('b:ansiesc')
		AnsiEsc
	endif
	AnsiEsc
	let b:ansiesc = 1
else
	echomsg 'Require Improved AnsiEsc http://www.vim.org/scripts/script.php?script_id=4979'
endif


let b:undo_ftplugin = exists('b:undo_ftplugin') ? b:undo_ftplugin . '|' : ''
let b:undo_ftplugin .= ''
	\ . '|unlet b:did_ftplugin_viewdoc'
