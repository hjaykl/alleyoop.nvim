# alleyoop.nvim

Build structured prompts from your editor context and send them anywhere.

Collect file references, code snippets, diagnostics, and quickfix entries, edit them in a floating markdown buffer, and dispatch to clipboard, tmux, or custom targets.

## Why

AI coding tools work better with precise context. But assembling that context by hand — copying file paths, selecting ranges, grabbing diagnostics — is tedious and breaks your flow.

Alleyoop gives you keybindings to collect context from your editor and compose it into a prompt, without leaving Neovim.

## Install

Requires Neovim >= 0.10.

**lazy.nvim**

```lua
{
  "hjaykl/alleyoop.nvim",
  config = function()
    require("alleyoop").setup()
  end,
}
```

## How it works

There are two modes of operation:

**Copy** (`<leader>a_`) — grab a single reference and send it straight to the target (clipboard by default).

**Compose** (`<leader>ac_`) — accumulate multiple references, then open the builder to edit and send them all at once.

### Quick copy

| Mapping | Mode | Description |
|---------|------|-------------|
| `<leader>af` | n | File path |
| `<leader>aF` | n | File path + full contents |
| `<leader>at` | n | Line reference |
| `<leader>at` | v | Range reference |
| `<leader>av` | v | Range with code |
| `<leader>ad` | n | Line diagnostics |
| `<leader>ad` | v | Range with code + diagnostics |
| `<leader>aD` | n | All buffer diagnostics |
| `<leader>aq` | n | Quickfix list |

### Compose and build

| Mapping | Mode | Description |
|---------|------|-------------|
| `<leader>acf` | n | Compose file path |
| `<leader>acF` | n | Compose file + contents |
| `<leader>act` | n | Compose line reference |
| `<leader>act` | v | Compose range reference |
| `<leader>acv` | v | Compose range with code |
| `<leader>acd` | n | Compose line diagnostics |
| `<leader>acd` | v | Compose range + diagnostics |
| `<leader>acD` | n | Compose buffer diagnostics |
| `<leader>acq` | n | Compose quickfix list |
| `<leader>ax` | n | Clear compose list |
| `<leader>ap` | n | Open builder |

### Workflow

1. Navigate to files and compose references with `<leader>ac_` mappings
2. Open the builder with `<leader>ap`
3. Edit the prompt — add instructions, reorder, remove what you don't need
4. `:w` to dispatch to the current target

The builder preserves your draft when you close with `q`. Reopen it, compose more references, and they'll be appended to your existing work.

## Builder

The builder is a floating markdown window with syntax highlighting. Your composed references appear as the initial content, and you can freely edit before dispatching.

| Key | Action |
|-----|--------|
| `:w` | Dispatch to target |
| `q` | Save draft and close |
| `C-p` / `C-n` | Browse prompt history |
| `C-t` | Switch dispatch target |
| `C-s` | Save to library |
| `C-l` | Clear buffer |

## Targets

Targets are where your prompt goes when you dispatch. Built-in targets:

- **clipboard** (default) — copies to system clipboard
- **tmux** — pastes into a tmux pane (prompts for pane ID on first use)

Switch the active target with `<leader>aT` or `C-t` inside the builder.

### Custom targets

```lua
require("alleyoop").setup({
  default_target = "clipboard",
  targets = {
    {
      name = "my-target",
      fn = function(prompt)
        -- do something with the prompt string
      end,
    },
  },
})
```

## Library

Save and reuse prompt templates.

- `C-s` in the builder saves the current buffer to the library
- `<leader>al` browses saved prompts and loads one into the builder
- `<leader>aL` deletes a saved prompt

Templates are stored as `.md` files. Global templates live in `stdpath("data")/alleyoop/library/`. Per-project templates go in a `.alleyoop/` directory at your project root.

## History

Every dispatched prompt is saved to `stdpath("data")/alleyoop/history/`. Browse previous prompts with `C-p` / `C-n` in the builder.

## Configuration

All options with defaults:

```lua
require("alleyoop").setup({
  commands = {},          -- additional commands (same name overrides defaults)
  targets = {},           -- additional targets (same name overrides built-ins)
  default_target = "clipboard",
  max_history = 50,
  notify = {
    compose = true,     -- "Compose (3): @/foo.lua", "Compose cleared"
    dispatch = true,    -- "Prompt copied to clipboard", "Sent to tmux pane: ..."
    target = true,      -- "Default target: tmux"
    library = true,     -- "Saved to...", "Deleted:..."
  },
  -- notify = false,    -- disable all INFO notifications
  builder = {
    width = 0.8,          -- fraction of editor width
    height = 0.6,         -- fraction of editor height
    title = "Alley-Oop",  -- set to false to hide
  },
  mappings = {
    -- override any mapping key with a new lhs, or false to disable
    -- copy_file = "<leader>cf",
    -- compose_file = false,
  },
})
```

### Mapping keys

All default mappings can be remapped or disabled by name:

`copy_file`, `copy_file_content`, `copy_line`, `copy_range`, `copy_range_content`, `copy_line_diagnostics`, `copy_range_diagnostics`, `copy_buf_diagnostics`, `copy_quickfix`, `compose_file`, `compose_file_content`, `compose_line`, `compose_range`, `compose_range_content`, `compose_line_diagnostics`, `compose_range_diagnostics`, `compose_buf_diagnostics`, `compose_quickfix`, `clear_compose`, `open_builder`, `set_target`, `browse_library`, `delete_library`

### Custom commands

```lua
require("alleyoop").setup({
  commands = {
    {
      name = "git_diff",
      modes = { "n" },
      fn = function(ctx)
        local diff = vim.fn.system("git diff " .. ctx.filepath)
        return "@" .. ctx.filepath .. "\n\n```diff\n" .. diff .. "\n```"
      end,
    },
  },
})
```

## License

MIT
