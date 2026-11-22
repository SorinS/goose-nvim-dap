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
