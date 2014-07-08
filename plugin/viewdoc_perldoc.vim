" Maintainer:		see in viewdoc.vim
" Version:		see in viewdoc.vim
" Last Modified:	see in viewdoc.vim
" License:		see in viewdoc.vim
" URL:			see in viewdoc.vim
" Description: ViewDoc handler for perldoc

if exists('g:loaded_viewdoc_perldoc') || &cp || version < 700
	finish
endif
let g:loaded_viewdoc_perldoc = 1


""" Options
if !exists('g:viewdoc_perldoc_format')
	let g:viewdoc_perldoc_format='text'     " user may want 'ansi'
endif

""" Interface
" - command
command -bar -bang -nargs=1 -complete=custom,s:CompletePerl ViewDocPerl
	\ call ViewDoc('<bang>'=='' ? 'new' : 'doc', <f-args>, 'perl')
" - abbrev
if !exists('g:no_plugin_abbrev') && !exists('g:no_viewdoc_abbrev')
	cnoreabbrev <expr> perldoc  getcmdtype()==':' && getcmdline()=='perldoc'  ? 'ViewDocPerl'  : 'perldoc'
	cnoreabbrev <expr> perldoc! getcmdtype()==':' && getcmdline()=='perldoc!' ? 'ViewDocPerl'  : 'perldoc!'
endif

""" Handlers

function s:ViewDoc_perldoc(topic, filetype, synid, ctx)
	let h = { 'ft':		'perldoc_' . g:viewdoc_perldoc_format,
		\ 'topic':	a:topic,
		\ }
	if a:ctx && a:filetype == 'perldoc_ansi'
		" remove tail of concealed ANSI sequence before <cword>
		let h.topic = substitute(h.topic, '^[0-9]\+m', '', '')
	endif
	let synname = a:ctx ? synIDattr(a:synid,'name') : ''
	if synname =~# 'SharpBang'
		let h.topic = 'perlrun'
	elseif synname =~# 'StatementFiles' && len(h.topic) == 1
		let h.topic = '-X'
	elseif synname =~# 'Conditional\|Repeat\|Label'
		let h.topic = 'perlsyn'
	elseif synname =~# 'SubPrototype\|SubAttribute'
		let h.topic = 'perlsub'
	elseif h.topic ==# 'AUTOLOAD'
		let h.topic = 'perlsub'
		let h.search= '^\s*Autoloading\>'
	elseif h.topic ==# 'DESTROY'
		let h.topic = 'perlobj'
		let h.search= '^\s*Destructors\>'
	elseif h.topic =~# '^__[A-Z]\+__$'
		let h.topic = 'perldata'
		let h.search= '^\s*Special\s\+Literals'
	elseif h.topic ==# 'tr' || h.topic ==# 'y'
		let h.topic = 'perlop'
		let h.search= '^\s*tr\/'
	elseif h.topic =~# '^q[qxw]\?$'
		let h.search= '^\s*' . h.topic . '\/'
		let h.topic = 'perlop'
	elseif synname =~# 'StringStartEnd\|perlQQ'
		let h.topic = 'perlop'
		let h.search= '^\s*Quote\s\+and\s\+Quote-[Ll]ike\s\+Operators\s*$'
	elseif h.topic =~# '^\(BEGIN\|UNITCHECK\|CHECK\|INIT\|END\)$'
		let h.topic = 'perlmod'
		let h.search= '^\s*BEGIN,'
	elseif synname =~# '^pod[A-Z]\|POD' || h.topic =~# '^=[a-z]' || h.topic =~# '^[A-Z]<'
		let h.topic = 'perlpod'
	elseif synname =~# 'Match'
		let h.topic = 'perlre'
	elseif synname =~# 'Var'
		" search for position where current var's name begin (starting with [$@%])
		let col = searchpos('[$@%]{\?\^\?\k*\%#\|\%#[$@%]', 'n')[1]
		" from that position took full var name (plus extra [ or { after it, if any)
		let var = col == 0 ? '' : matchstr(getline('.'), '^[$@%]{\?^\?.\k*}\?[{\[]\?', col-1)
		" $a[ -> @a,  $a{ -> %a,  @a{ -> %a,  drop [ or { at end
		let var = substitute(var, '^$\(.*\)\[$', '@\1', '')
		let var = substitute(var, '^$\(.*\){$',  '%\1', '')
		let var = substitute(var, '^@\(.*\){$',  '%\1', '')
		let var = substitute(var, '[\[{]$',      '',    '')
		" ${a} -> $a,  ${^a} -> $^a,  but not ${^aa}
		let var = substitute(var, '^\([$@%]\){\([^^].*\|\^.\)}$', '\1\2', '')
		let h.topic = var == '' ? h.topic : var
	endif
	let t = shellescape(h.topic,1)
	let h.cmd = printf('perldoc -o %s -w width={{winwidth}} -- %s || perldoc -o %s -w width={{winwidth}} -f %s || perldoc -o %s -w width={{winwidth}} -v %s',
		\ g:viewdoc_perldoc_format, t, g:viewdoc_perldoc_format, t, g:viewdoc_perldoc_format, t)
	return h
endfunction

" use function(s:SID().'Foo') instead of function('s:Foo') for
" compatibility with Vim-7.3.x (7.3.762 at least)
function s:SID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction
let g:ViewDoc_perl    = function(s:SID().'ViewDoc_perldoc')
let g:ViewDoc_perldoc = function(s:SID().'ViewDoc_perldoc')
let g:ViewDoc_perldoc_text = function(s:SID().'ViewDoc_perldoc')
let g:ViewDoc_perldoc_ansi = function(s:SID().'ViewDoc_perldoc')


""" Internal

function s:CompletePerl(ArgLead, CmdLine, CursorPos)
	if exists('s:complete')
		return s:complete
	endif
	call ViewDoc_SetShellToBash()
	let data= "__FILE__\n__LINE__\n__PACKAGE__\n__DATA__\n__END__\n"
	let mod = "BEGIN\nUNITCHECK\nCHECK\nINIT\nEND\n"
	let pod = system('grep "^=item C<[=A-Z]" $(perl -e "print for grep{-f}map{qq{\$_/pod/perlpod.pod}}@INC") | sed "s/^=item C<//;s/E<.*/</;s/[ >].*//;s/</<>/" | sort -u')
	let var = system('grep -E "^=item [\$@%][^ ]*\$|=item [A-Z]+\$" $(perl -e "print for grep{-f}map{qq{\$_/pod/perlvar.pod}}@INC") | sed "s/^=item //" | sort -u')
	let func= "-X\n".system('grep "^=item [[:lower:]]" $(perl -e "print for grep{-f}map{qq{\$_/pod/perlfunc.pod}}@INC") | sed "s/^=item //" | grep -v " [[:lower:]]" | sed "s/ .*//;s/(\$//" | sort -u')
	let pkg = system('find $(perl -le "\$s{q{.}}=1;print for grep{(\$a=\$_)=~s{/[^/]*\z}{};-d && !\$s{\$_}++ && !\$s{\$a}}sort@INC") -name "*.pm" -printf "%P\n" | sed "s,^[0-9.]\+/,,;s,^"$(perl -MConfig -e "print \$Config{myarchname}")"/,,;s,.pm$,,;s,/,::,g" | sort -u')
	let s:complete = data.mod.pod.var.func.pkg
	call ViewDoc_RestoreShell()
	return s:complete
endfunction

