-- dap-goose: debug Goose programs in Neovim with nvim-dap, through goose-dap
-- (https://github.com/SorinS/goose-debugger, dap/goose-dap).
--
-- Registers goose-dap as nvim-dap's adapter for the goose filetype, with
-- configurations that build the current file with `goose build -g` and
-- launch it. See README.md.
local M = {}

local function split_args(s)
  local args = {}
  for a in (s or ""):gmatch("%S+") do table.insert(args, a) end
  return args
end

-- goose-dap: the adapter option, else on PATH. Resolved when a session
-- starts, so a missing one is reported then, not at startup.
local function find_adapter(opts)
  if opts.adapter and opts.adapter ~= "" then return vim.fn.expand(opts.adapter) end
  local p = vim.fn.exepath("goose-dap")
  if p ~= "" then return p end
  return nil
end

--- opts (all optional):
---   goose     the Goose compiler, which must have -g (default: goose-lang.vim's
---             g:goose_compiler_path, then $GOOSE, then goose on PATH)
---   adapter   goose-dap's path (default: goose-dap on PATH)
---   lldb_dap  the lldb-dap goose-dap runs (default: goose-dap finds one)
---   stop_on_runtime_error  stop on a failed assert, bounds or overflow check (default true)
---   configurations  false to add none to dap.configurations.goose
function M.setup(opts)
  opts = opts or {}
  local dap = require("dap")

  dap.adapters.goose = function(callback, _)
    local adapter = find_adapter(opts)
    if not adapter or vim.fn.executable(adapter) ~= 1 then
      vim.notify("dap-goose: goose-dap not found" .. (adapter and (": " .. adapter) or " on PATH")
        .. "; set the adapter option to its path", vim.log.levels.ERROR)
      return
    end
    local args = {}
    if opts.lldb_dap then args = { "--lldb-dap", vim.fn.expand(opts.lldb_dap) } end
    callback({ type = "executable", command = adapter, args = args })
  end

  if opts.stop_on_runtime_error == false then
    dap.defaults.goose.exception_breakpoints = {}
  end

  if opts.configurations == false then return end
  local base = {
    type = "goose",
    request = "launch",
    source = "${file}",
    program = "${fileDirname}/${fileBasenameNoExtension}",
    cwd = "${fileDirname}",
    build = true,
    -- goose-lang.vim's setting for :make, when it is set.
    goose = opts.goose and vim.fn.expand(opts.goose) or vim.g.goose_compiler_path,
  }
  dap.configurations.goose = dap.configurations.goose or {}
  table.insert(dap.configurations.goose, vim.tbl_extend("force", base, { name = "Debug Goose file" }))
  table.insert(dap.configurations.goose, vim.tbl_extend("force", base, {
    name = "Debug Goose file with arguments",
    args = function() return split_args(vim.fn.input("Arguments: ")) end,
  }))
end

return M
