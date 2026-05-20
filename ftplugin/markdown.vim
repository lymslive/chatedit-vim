" vim/ftplugin/markdown.vim
" Filetype plugin for Markdown chat editing (chatedit format)
"
" Insert-mode abbreviations for chat role headings:
"   #s  →  ## system >>
"   #u  →  ## user >>
"   #a  →  ## assistant >>
"
" Normal-mode mappings (heading lines only):
"   >>  →  increase heading level (add one '#', max level 6)
"   <<  →  decrease heading level (remove one '#', min level 1)
"   Non-heading lines fall through to the default >> / << behaviour.

if exists('b:did_chatedit_ftplugin')
    finish
endif
let b:did_chatedit_ftplugin = 1

iabbrev <buffer> #s ## system >>
iabbrev <buffer> #u ## user >>
iabbrev <buffer> #a ## assistant >>

nnoremap <buffer> >> :call chatedit#HeadingIndent('increase')<CR>
nnoremap <buffer> << :call chatedit#HeadingIndent('decrease')<CR>
