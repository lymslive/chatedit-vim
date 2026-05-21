" vim/autoload/chatedit.vim
" Async implementation for chatedit -- requires Vim 8 with +job feature
"
" Public functions:
"   chatedit#RunChat(line1, line2, mode)  -- async streaming chat call
"   chatedit#HeadingIndent(direction)     -- adjust markdown heading level

let g:chatedit_version = '1.0'

" ---------------------------------------------------------------------------
" Public: RunChat
" ---------------------------------------------------------------------------

" chatedit#RunChat({line1}, {line2}, {mode})
"   Start an async job calling ai-chat.pl with --stream.
"   mode: 'chat'   -- full chat parse, append response to end of buffer
"         'simple' -- --simple mode, replace range with response
function! chatedit#RunChat(line1, line2, mode) abort
    let l:total    = line('$')
    let l:is_whole = (a:line1 == 1 && a:line2 == l:total)

    " ---- Prepare input file ----
    let l:tmpfile = ''
    if l:is_whole && expand('%') !=# ''
        :update
        let l:infile = expand('%:p')
    else
        let l:tmpfile = tempname()
        call writefile(getline(a:line1, a:line2), l:tmpfile)
        let l:infile = l:tmpfile
    endif

    " ---- Build command ----
    let l:opts = '--stream --reformat 1'
    if a:mode ==# 'simple'
        let l:opts = '--simple ' . l:opts
    endif
    let l:cmd = g:chatedit_cmd . ' ' . l:opts . ' ' . shellescape(l:infile)

    " ---- Context dict shared across callbacks ----
    let l:ctx = {
        \ 'bufnr'    : bufnr('%'),
        \ 'mode'     : a:mode,
        \ 'line1'    : a:line1,
        \ 'line2'    : a:line2,
        \ 'tmpfile'  : l:tmpfile,
        \ 'insert_at': a:line1 - 1,
        \ 'replaced' : 0,
        \ 'stderr'   : [],
        \ }

    " ---- Start async job ----
    let l:job = job_start(['/bin/sh', '-c', l:cmd], {
        \ 'out_cb'  : function('s:OnOut',  [l:ctx]),
        \ 'err_cb'  : function('s:OnErr',  [l:ctx]),
        \ 'exit_cb' : function('s:OnExit', [l:ctx]),
        \ })

    if job_status(l:job) ==# 'fail'
        echohl ErrorMsg
        echomsg 'chatedit: failed to start job'
        echohl None
        if l:tmpfile !=# ''
            call delete(l:tmpfile)
        endif
    else
        echomsg l:cmd
    endif
endfunction

" ---------------------------------------------------------------------------
" Public: HeadingIndent
" ---------------------------------------------------------------------------

" chatedit#HeadingIndent({direction})
"   Adjust heading level on the current line.
"   direction: 'increase' -- prepend one '#' (max level 6)
"              'decrease' -- remove one '#' (min level 1)
"   Non-heading lines fall through to the default >> / << behaviour.
function! chatedit#HeadingIndent(direction) abort
    let l:line = getline('.')
    if l:line =~# '^#\+\s'
        let l:level = len(matchstr(l:line, '^#\+'))
        if a:direction ==# 'increase' && l:level < 6
            call setline('.', '#' . l:line)
        elseif a:direction ==# 'decrease' && l:level > 1
            call setline('.', l:line[1:])
        endif
    else
        " Not a heading: delegate to normal >> / <<
        if a:direction ==# 'increase'
            normal! >>
        else
            normal! <<
        endif
    endif
endfunction

" ---------------------------------------------------------------------------
" Private: job callbacks
" ---------------------------------------------------------------------------

" Called once per output line while the job is running.
function! s:OnOut(ctx, channel, data) abort
    " Vim sends '' at end-of-stream; skip it
    if a:data ==# '' | return | endif

    let l:bufnr = a:ctx.bufnr

    " Buffer gone (deleted) while streaming -- silently discard
    if !bufexists(l:bufnr) || !bufloaded(l:bufnr)
        return
    endif

    " simple mode: delete original range on the first real output line
    if a:ctx.mode ==# 'simple' && !a:ctx.replaced
        if a:ctx.line2 >= a:ctx.line1
            call deletebufline(l:bufnr, a:ctx.line1, a:ctx.line2)
        endif
        let a:ctx.replaced = 1
        " insert_at is already (line1 - 1); content will be inserted after it
    endif

    if a:ctx.mode ==# 'simple'
        call appendbufline(l:bufnr, a:ctx.insert_at, a:data)
        let a:ctx.insert_at += 1
    else
        " chat mode: always grow at the end of the buffer
        call appendbufline(l:bufnr, '$', a:data)
    endif
endfunction

" Called once per stderr line.
function! s:OnErr(ctx, channel, data) abort
    if a:data ==# '' | return | endif
    call add(a:ctx.stderr, a:data)
endfunction

" Called when the job exits.
function! s:OnExit(ctx, job, status) abort
    " Clean up temp input file
    if a:ctx.tmpfile !=# ''
        call delete(a:ctx.tmpfile)
    endif

    let l:bufnr = a:ctx.bufnr

    " Non-zero exit: report error + append stderr to buffer (or echo)
    if a:status != 0
        echohl ErrorMsg
        echomsg 'chatedit: ai-chat.pl exited with code ' . a:status
        echohl None
        if !empty(a:ctx.stderr)
            if bufexists(l:bufnr) && bufloaded(l:bufnr)
                call appendbufline(l:bufnr, '$', a:ctx.stderr)
            else
                for l:line in a:ctx.stderr
                    echomsg l:line
                endfor
            endif
        endif
        return
    endif

    " Success path -- determine where the user is now
    if !bufexists(l:bufnr)
        " Buffer was deleted mid-stream
        echohl WarningMsg
        echomsg 'chatedit: done (original buffer was deleted; output was lost)'
        echohl None
        return
    endif

    if bufnr('%') !=# l:bufnr
        " User has moved to another window / tab / buffer
        let l:name = bufname(l:bufnr)
        if l:name ==# '' | let l:name = 'buf#' . l:bufnr | endif
        echomsg 'chatedit: done [' . l:name . ']'
    endif
    " When the user is still in the same buffer, the streaming output is
    " already visible -- no extra notification needed.
endfunction
