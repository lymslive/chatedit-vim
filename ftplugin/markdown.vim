" vim/ftplugin/markdown.vim
" Filetype plugin for Markdown chat editing (chatedit format)
"
" Insert-mode abbreviations for chat role headings:
"   #s  →  ## system >>
"   #u  →  ## user >>
"   #a  →  ## assistant >>

if exists('b:did_chatedit_ftplugin')
    finish
endif
let b:did_chatedit_ftplugin = 1

iabbrev <buffer> #s ## system >>
iabbrev <buffer> #u ## user >>
iabbrev <buffer> #a ## assistant >>
