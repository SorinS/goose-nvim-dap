# goose-nvim-dap

Debug [Goose](https://github.com/aardappel/goose) programs in Neovim with
[nvim-dap](https://github.com/mfussenegger/nvim-dap). The plugin
(`dap-goose`) registers [goose-dap](https://github.com/SorinS/goose-debugger/tree/main/dap)
as nvim-dap's adapter for the `goose` filetype, with two configurations:

- **Debug Goose file** builds the current file with `goose build -g` (into
  the file's directory, named after it) and launches it;
- **Debug Goose file with arguments** asks for the program's arguments
  first.

You get breakpoints, stepping, the call stack, the Goose locals in scope
under their own names, Goose names in watches and conditions, and a stop
on a Goose runtime error (a failed assert, a bounds or overflow check) at
the line that failed.

## What you need

- Neovim 0.10 or later, and nvim-dap.
  [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) is optional and
  works as it does for any adapter.
- The `goose` filetype. [goose-lang.vim](https://github.com/exaroth/goose-lang.vim)
  sets it, with highlighting and indentation; or add
  `vim.filetype.add({ extension = { goose = "goose" } })`.
- A Goose compiler with `-g` (`goose help build` lists `--debug-info`).
- goose-dap, from [goose-debugger](https://github.com/SorinS/goose-debugger)
  (`dap/goose-dap`), with Python 3 and an `lldb-dap` (on macOS the Command
  Line Tools have one; goose-dap finds it).

## Setup

With lazy.nvim:

```lua
{
  "SorinS/goose-nvim-dap",
  dependencies = { "mfussenegger/nvim-dap" },
  ft = "goose",
  opts = {
    goose = "/path/to/goose",
    adapter = "/path/to/goose-debugger/dap/goose-dap",
  },
}
```

Without a plugin manager, with the repository on `runtimepath`:

```lua
require("dap-goose").setup({ goose = "/path/to/goose", adapter = "/path/to/goose-dap" })
```

`setup` takes, all optional:

| Option | Meaning |
|---|---|
| `goose` | The compiler. Default: goose-lang.vim's `g:goose_compiler_path`, then `$GOOSE`, then `goose` on PATH. |
| `adapter` | goose-dap's path. Default: `goose-dap` on PATH. |
| `lldb_dap` | The lldb-dap goose-dap runs. Default: goose-dap finds one. |
| `stop_on_runtime_error` | `false`: no stop on Goose runtime errors. Default `true`. |
| `configurations` | `false`: add none to `dap.configurations.goose` (write your own). |

## Using it

In a `.goose` file, set a breakpoint with `:DapToggleBreakpoint`, start
with `:DapContinue` and choose **Debug Goose file**, then step with
`:DapStepOver`, `:DapStepInto` and `:DapStepOut`. The build's output and
the program's go to the REPL (`:DapToggleRepl`).

### Key bindings

nvim-dap has no key bindings of its own. A common set, as a lazy.nvim
`keys` table on nvim-dap's spec:

```lua
keys = {
  { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "DAP toggle breakpoint" },
  { "<leader>dr", function() require("dap").continue() end, desc = "DAP start/continue" },
  { "<leader>do", function() require("dap").step_over() end, desc = "DAP step over" },
  { "<leader>di", function() require("dap").step_into() end, desc = "DAP step into" },
  { "<leader>dO", function() require("dap").step_out() end, desc = "DAP step out" },
  { "<leader>dq", function() require("dap").terminate() end, desc = "DAP stop" },
  { "<leader>du", function() require("dapui").toggle() end, desc = "DAP toggle UI" },
  { "<leader>dh", function() require("dap.ui.widgets").hover() end, desc = "DAP value under cursor" },
},
```

`<leader>dr` starts a session (pick **Debug Goose file**) and, once
stopped, continues to the next breakpoint. `<leader>dh` shows the value of
the variable under the cursor in a popup.

### nvim-dap-ui

[nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) shows the session
in windows around the code: by default a column on the left with
**Variables** (Locals, Globals, Registers), **Breakpoints**, **Stack** and
**Watches**, and a panel at the bottom with the **REPL** (with the step and
continue buttons above it) and the program's output. To open it when a
session starts and close it when the session ends, and to choose its
sizes:

```lua
local dap, dapui = require("dap"), require("dapui")
dapui.setup({
  layouts = {
    {
      elements = { "scopes", "breakpoints", "stacks", "watches" },
      size = 60,            -- the left column's width in columns (0.35: 35% of the screen)
      position = "left",
    },
    {
      elements = { "repl", "console" },
      size = 12,            -- the bottom panel's height in lines
      position = "bottom",
    },
  },
})
dap.listeners.before.launch.dapui_config = function() dapui.open() end
dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
dap.listeners.before.event_exited.dapui_config = function() dapui.close() end
```

**Moving between windows.** dap-ui's panes are ordinary windows: in
normal mode `Ctrl-w h`, `Ctrl-w j`, `Ctrl-w k` and `Ctrl-w l` go to the
window to the left, below, above and right, and `Ctrl-w w` cycles through
them all. Many configurations (NvChad's among them) map `Ctrl-h`, `Ctrl-j`,
`Ctrl-k` and `Ctrl-l` to the same. Going left from the code lands in the
pane level with the cursor; `Ctrl-w k` and `Ctrl-w j` then move up and
down the column. With `:set mouse=a`, a click selects a pane too.

**Resizing.** In a pane of the column, `Ctrl-w >` widens it by a column
and `Ctrl-w <` narrows it (`20 Ctrl-w >` adds 20), and `:vertical resize
70` sets the width; `Ctrl-w +`, `Ctrl-w -` and `:resize 15` do the same for
the height of the bottom panel. With the mouse, drag the separator. A size
set this way lasts until dap-ui is opened again; `size` in the layout
above is the lasting one.

**In the panes:**

| Key | Where | What it does |
|---|---|---|
| `Enter` (or double-click) | Variables, Watches | expand or collapse a value (an array, a struct, an enum's fields) |
| `w` | Variables | add the variable to Watches |
| `r` | Variables, Watches | send the value to the REPL |
| `Enter` | Stack | go to that frame: the code window shows it, Variables shows its locals |
| `e` | Variables | change the variable's value |
| `e` | Watches | edit the expression |
| `i`, then `Enter` | Watches | add an expression, in Goose names (`count`, `xs[0]`, `p.x`) |
| `d` | Breakpoints, Watches | remove the breakpoint or the expression |
| `o` | Breakpoints, Stack | open that line in the code window |
| `t` | Breakpoints | turn the breakpoint on or off |

In the REPL, an expression is evaluated in the current frame, and a line
that starts with a backtick is an LLDB command (`` `goose-locals ``,
`` `register read ``).

**One pane in a floating window**, without the layout:
`:lua require("dapui").float_element("scopes")` (or `"stacks"`,
`"watches"`, `"breakpoints"`, `"repl"`) opens it at the cursor; `q` closes
it.

**Icons.** dap-ui draws its arrows and its control buttons with
[Nerd Font](https://www.nerdfonts.com) glyphs (Codicons). If they show as
boxes or question marks, the terminal's font does not have them: use a
Nerd Font, or keep your font and give the Nerd Font to the other glyphs
only (in iTerm2: Settings, Profiles, Text, "Use a different font for
non-ASCII text", for example Hack Nerd Font Mono; `brew install --cask
font-hack-nerd-font` installs it). Or give dap-ui plain Unicode icons:

```lua
dapui.setup({
  icons = { expanded = "▾", collapsed = "▸", current_frame = "→" },
  controls = {
    icons = {
      pause = "⏸", play = "▶", step_into = "↓", step_over = "↷", step_out = "↑",
      step_back = "↶", run_last = "↻", terminate = "■", disconnect = "⏏",
    },
  },
})
```

### Your own configurations

A configuration of your own takes goose-dap's launch keys (`source`,
`program`, `build`, `goose`, `buildArgs`, `args`, `cwd`, …; see goose-dap's
[README](https://github.com/SorinS/goose-debugger/blob/main/dap/README.md#launch-configuration)):

```lua
table.insert(require("dap").configurations.goose, {
  type = "goose", request = "launch", name = "Debug main",
  source = "${workspaceFolder}/main.goose",
  program = "${workspaceFolder}/main",
  build = true,
})
```

## Test

```sh
GOOSE=/path/to/goose GOOSE_DAP=/path/to/goose-dap nvim --clean --headless -l test/run.lua
```

It copies `test/samples/` to a temporary directory and checks, through
nvim-dap and goose-dap: three stops at a breakpoint in a loop with Goose
frames and locals, a step over to the next line, and the stop on a failed
assert. `GOOSE_DAP` defaults to goose-dap on PATH; `NVIM_DAP` names an
nvim-dap checkout (default lazy.nvim's); `GOOSE_LANG_VIM` names a
goose-lang.vim checkout to take the filetype and `g:goose_compiler_path`
from instead.
