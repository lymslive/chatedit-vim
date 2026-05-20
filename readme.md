# chatedit-vim

Vim plugin for [chatedit](https://github.com/lymslive/chatedit) -- integrates
`ai-chat.pl` with Vim so you can send Markdown chat files to an AI model API
without leaving the editor.

## Requirements

- Vim 8.0+ with `+job` feature (for async streaming mode)
- Vim 7 / no `+job`: automatic synchronous fallback
- `ai-chat.pl` on `$PATH` (or configure `g:chatedit_cmd`)

## Installation

Vim 8+ native packages:

```bash
mkdir -p ~/.vim/pack/chatedit/start

# Option A: symlink from chatedit repo submodule
ln -s /path/to/chatedit/vim ~/.vim/pack/chatedit/start/chatedit

# Option B: clone standalone
git clone https://github.com/lymslive/chatedit-vim \
    ~/.vim/pack/chatedit/start/chatedit
```

## Configuration

```vim
" Path / name of the ai-chat.pl command (default: 'ai-chat.pl')
let g:chatedit_cmd = 'ai-chat.pl'
```

## Commands

| Command | Mode | Behaviour |
|---------|------|-----------|
| `:AI` | whole buffer | Full chat parse (`ai-chat.pl --stream --reformat 1`); append streaming response to end of buffer |
| `:'<,'>AI` | visual selection | Send selection as chat; stream response below selection |
| `:AR` | whole buffer | Simple mode (`--simple`); replace buffer with response |
| `:'<,'>AR` | visual selection | Simple mode; replace selection with response |

All commands run **asynchronously** (Vim 8+): the editor stays responsive while
`ai-chat.pl` is calling the AI API.  Output is written to the buffer line by
line as it streams in.

## Markdown Abbreviations

In insert mode inside `.md` files:

| Type | Expands to |
|------|-----------|
| `#s` | `## system >>` |
| `#u` | `## user >>` |
| `#a` | `## assistant >>` |

## Normal-mode Mappings (Markdown files)

| Key | Action |
|-----|--------|
| `>>` | Increase heading level (add `#`, max `######`) |
| `<<` | Decrease heading level (remove `#`, min `#`) |

These mappings only affect heading lines (`# …`).  On non-heading lines the
default `>>` (indent) / `<<` (unindent) behaviour is preserved.

## Async Edge Cases

When `ai-chat.pl` finishes, the plugin handles the following situations:

| Situation | Behaviour |
|-----------|-----------|
| Still in same buffer | Streaming output is already visible; no extra notification |
| Moved to another window / tab | `echomsg` notification with buffer name |
| Original buffer hidden | Output is written to the hidden buffer; notification shown |
| Original buffer deleted | Warning message; streamed content is lost |
| Non-zero exit code | Error message + stderr appended to buffer |

## Chat Format

See [docs/chat-format.md](../docs/chat-format.md) in the parent repository for
the Markdown conversation format that `ai-chat.pl` understands.
