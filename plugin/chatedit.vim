" vim/plugin/chatedit.vim
" Vim plugin for chatedit -- integrate ai-chat.pl with Vim
"
" Commands:
"   :AI          Send whole buffer as chat, append response to end
"   :'<,'>AI     Send selection as chat, insert response below
"   :AR          Send whole buffer in simple mode, replace with response
"   :'<,'>AR     Send selection in simple mode, replace with response

if exists('g:loaded_chatedit')
    finish
endif
let g:loaded_chatedit = 1

" Command used to call ai-chat.pl (override to use a custom path/name)
if !exists('g:chatedit_cmd')
    let g:chatedit_cmd = 'ai-chat.pl'
endif

" s:RunChat(line1, line2, mode)
"   line1, line2 : line range (from command -range=%)
"   mode         : 'chat' for :AI (full chat parsing + --reformat)
"                  'simple' for :AR (--simple + --reformat)
function! s:RunChat(line1, line2, mode) abort
    let l:total  = line('$')
    let l:is_whole = (a:line1 == 1 && a:line2 == l:total)

    " ---- Prepare input file ----
    let l:tmpfile = ''
    if l:is_whole && expand('%') !=# ''
        " Whole buffer with a saved filename: just write and use it
        :update
        let l:infile = expand('%:p')
    else
        " Selection, or unsaved buffer: dump lines to a temp file
        let l:tmpfile = tempname()
        call writefile(getline(a:line1, a:line2), l:tmpfile)
        let l:infile = l:tmpfile
    endif

    " ---- Build command ----
    let l:opts = '--reformat 1'
    if a:mode ==# 'simple'
        let l:opts = '--simple ' . l:opts
    endif
    let l:cmd = g:chatedit_cmd . ' ' . l:opts . ' ' . shellescape(l:infile)

    " ---- Run ----
    let l:output    = systemlist(l:cmd)
    let l:exit_code = v:shell_error

    if l:tmpfile !=# ''
        call delete(l:tmpfile)
    endif

    if l:exit_code != 0
        echohl ErrorMsg
        echomsg 'chatedit: ' . g:chatedit_cmd . ' exited with code ' . l:exit_code
        echohl None
        return
    endif

    " ---- Insert output ----
    if a:mode ==# 'simple'
        " Replace the original range
        execute a:line1 . ',' . a:line2 . 'delete _'
        call append(a:line1 - 1, l:output)
    else
        " Append to end of buffer
        call append(line('$'), l:output)
    endif
endfunction

" :AI [range]  -- full chat parse, append response to end of buffer
" Default range is % (whole file); visual selection sends selection only
command! -range=% AI call s:RunChat(<line1>, <line2>, 'chat')

" :AR [range]  -- simple mode, replace range with response
" Default range is % (whole file); visual selection replaces selection
command! -range=% AR call s:RunChat(<line1>, <line2>, 'simple')
