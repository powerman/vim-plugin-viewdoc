" Syntax file for output of GNU info, inspired by
" http://www.vim.org/scripts/script.php?script_id=21
"
" Author: pawel.wiecek@tieto.com

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case match
syn match infoTopNav /^File: .*\.info,  Node: [^,]*,.*$/ contains=infoNavLink
syn match infoMenuTitle  /^\* Menu:/hs=s+2,he=e-1
syn match infoTitle  /^[A-Z][0-9A-Za-z `',/&]\{,43}\([a-z']\|[A-Z]\{2}\)$/
syn match infoTitle  /^[-=*]\{,45}$/
syn match infoString  /`[^`']*'/
syn match infoLinkMenu /^\* [^:]*::/hs=s+2
syn match infoLinkDir /^\* [^:]*: ([^)]*)[^.]*\./hs=s+2,he=e-1 contains=infoDirTarget
syn match infoLinkIndex /^\* [^:]*:\s*[^.]*\.[ \t\n]*(line\s\+[0-9]\+)$/hs=s+2 contains=infoIndexTarget,infoIndexLine
syn region infoLinkNote start=/\*[Nn]ote/ end=/\(::\|[.,]\)/ contains=infoNoteNote
syn match infoNavLink contained /\(Prev\|Next\|Up\): \zs[^,]*/
syn match infoDirTarget contained /: ([^)]*)[^.]*\./hs=s+1,he=e-1
syn match infoIndexTarget contained /:\s*.\+\./hs=s+1,he=e-1
syn region infoIndexLine contained start=/(line/ end=/)$/
syn match infoNoteNote contained /\*[Nn]ote/hs=s+1

hi def link infoMenuTitle Title
hi def link infoTitle Comment
hi def link infoNavLink Directory
hi def link infoLinkMenu Directory
hi def link infoLinkDir Directory
hi def link infoLinkIndex Directory
hi def link infoLinkNote Directory
hi def link infoString String
hi def link infoDirTarget Keyword
hi def link infoIndexTarget Keyword
hi def link infoIndexLine Identifier
hi def link infoNoteNote Keyword

let b:current_syntax = "info"
