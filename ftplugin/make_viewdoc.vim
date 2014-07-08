if exists('b:did_ftplugin_viewdoc')
	finish
endif
let b:did_ftplugin_viewdoc = 1


setlocal iskeyword+=.,@-@,%,<,?,+,\|,*,^


let b:undo_ftplugin = exists('b:undo_ftplugin') ? b:undo_ftplugin . '|' : ''
let b:undo_ftplugin .= 'setlocal iskeyword<'
	\ . '|unlet b:did_ftplugin_viewdoc'
