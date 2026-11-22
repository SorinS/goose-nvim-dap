-- Headless test of lua/dap-goose with nvim-dap:
--
--   GOOSE=/path/to/goose-with-g GOOSE_DAP=/path/to/goose-dap \
--     nvim --clean --headless -l test/run.lua
--
-- GOOSE_DAP defaults to goose-dap on PATH; NVIM_DAP names an nvim-dap
-- checkout (default lazy.nvim's, ~/.local/share/nvim/lazy/nvim-dap).
-- Each case opens a copy of a sample, sets breakpoints, starts "Debug Goose
-- file" (goose-dap builds it with goose build -g) and checks the stops.
local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local repo = vim.fn.fnamemodify(here, ":h")
local nvim_dap = os.getenv("NVIM_DAP") or (vim.fn.stdpath("data") .. "/lazy/nvim-dap")
vim.opt.rtp:prepend(nvim_dap)
vim.opt.rtp:prepend(repo)
-- GOOSE_LANG_VIM=/path/to/goose-lang.vim: its filetype and its
-- g:goose_compiler_path for the compiler, rather than ours.
local langvim = os.getenv("GOOSE_LANG_VIM")
if langvim == "" then langvim = nil end
if langvim then
  vim.opt.rtp:prepend(langvim)
  -- Filetype detection was set up before; a plugin manager sources a
  -- plugin's ftdetect when it adds the plugin, as this does.
  vim.cmd("runtime! ftdetect/goose.vim")
  vim.g.goose_compiler_path = os.getenv("GOOSE")
  vim.env.GOOSE = nil   -- so goose-dap gets the compiler from the setting alone
else
  vim.filetype.add({ extension = { goose = "goose" } })
end
vim.cmd("filetype plugin indent on")   -- nvim -l starts without it

local dap = require("dap")
require("dap-goose").setup({ goose = not langvim and os.getenv("GOOSE") or nil, adapter = os.getenv("GOOSE_DAP") })

local work = os.getenv("GOOSE_NVIM_WORK") or vim.fn.tempname()
vim.fn.mkdir(work, "p")
local fails = 0

local function check(what, ok, detail)
  if ok then print("ok    " .. what)
  else print("FAIL  " .. what .. (detail and (": " .. detail) or "")); fails = fails + 1 end
end

local function copy(name)
  local dst = work .. "/" .. vim.fn.fnamemodify(name, ":t")
  vim.fn.writefile(vim.fn.readfile(repo .. "/" .. name), dst)
  return dst
end

-- Runs "Debug Goose file" on `file` with breakpoints on `lines`; on each
-- stop calls on_stop(session, body, frames, vars, n), which returns the
-- next action ("continue", "next" or "stop"). Returns the stops' count
-- and whether the session ended.
local function session(file, lines, on_stop)
  vim.cmd("edit " .. vim.fn.fnameescape(file))
  local bufnr = vim.api.nvim_get_current_buf()
  require("dap.breakpoints").clear()
  for _, l in ipairs(lines) do require("dap.breakpoints").set({}, bufnr, l) end
  local stops, ended = 0, false
  -- Only this case's session: the last one's terminated event can come late.
  local mine
  dap.listeners.after.launch.test = function(s) mine = s end
  dap.listeners.after.event_stopped.test = function(s, body)
    if s ~= mine then return end
    stops = stops + 1
    s:request("stackTrace", { threadId = body.threadId, levels = 4 }, function(_, st)
      local f = st.stackFrames[1]
      s:request("scopes", { frameId = f.id }, function(_, sc)
        s:request("variables", { variablesReference = sc.scopes[1].variablesReference }, function(_, v)
          local frames, vars = {}, {}
          for _, x in ipairs(st.stackFrames) do
            table.insert(frames, string.format("%s %s:%d", x.name,
              x.source and vim.fn.fnamemodify(x.source.path or "", ":t") or "", x.line))
          end
          for _, x in ipairs(v.variables) do vars[x.name] = x.value end
          local action = on_stop(s, body, frames, vars, stops)
          if action == "next" then s:request("next", { threadId = body.threadId }, function() end)
          elseif action == "stop" then dap.terminate()
          else s:request("continue", { threadId = body.threadId }, function() end) end
        end)
      end)
    end)
  end
  local function done(s) if s == mine then ended = true end end
  dap.listeners.after.event_terminated.test = done
  dap.listeners.after.event_exited.test = done
  dap.run(dap.configurations.goose[1])
  vim.wait(120000, function() return ended end, 50)
  dap.listeners.after.event_stopped.test = nil
  -- Let the adapter and the debuggee go before the next case.
  vim.wait(3000, function() return dap.session() == nil end, 50)
  return stops, ended
end

-- 1. A breakpoint in a loop: three stops, Goose frames and locals.
local area = copy("test/samples/area.goose")
vim.cmd("edit " .. vim.fn.fnameescape(area))
check("area.goose has the goose filetype", vim.bo.filetype == "goose", vim.bo.filetype)
local seen = {}
local stops, ended = session(area, { 9 }, function(_, body, frames, vars, n)
  seen[n] = { reason = body.reason, top = frames[1], caller = frames[2], i = vars.i, total = vars.total }
  return "continue"
end)
check("area: three stops at the loop line", stops == 3, "stops=" .. stops)
check("area: session ended", ended)
check("area: stop reason breakpoint", seen[1] and seen[1].reason == "breakpoint", vim.inspect(seen[1]))
check("area: Goose frame main at area.goose:9", seen[1] and seen[1].top == "main area.goose:9", seen[1] and seen[1].top)
check("area: Goose locals i and total", seen[3] and seen[3].i == "2" and seen[3].total == "2", vim.inspect(seen[3]))

-- 2. Step over: from the call in the loop to the next Goose line.
local steps = {}
stops, ended = session(area, { 11 }, function(_, _, frames, _, n)
  steps[n] = frames[1]
  if n == 1 then return "next" end
  return "stop"
end)
check("step: next goes from 11 to 12", steps[1] == "main area.goose:11" and steps[2] == "main area.goose:12",
  vim.inspect(steps))

-- 3. A failed assert stops at the Goose line, without a breakpoint.
copy("test/samples/geo.goose")
local assert_file = copy("test/samples/assert.goose")
local at
stops, ended = session(assert_file, {}, function(_, body, frames, vars, n)
  at = { reason = body.reason, top = frames[1], w = vars.w }
  return "stop"
end)
check("assert: stops on the runtime error", at and at.reason == "exception", vim.inspect(at))
check("assert: at geo::area geo.goose:5", at and at.top == "geo::area geo.goose:5", at and at.top)
check("assert: the failing value w = -1", at and at.w == "-1", at and at.w)

print(fails == 0 and "\nall passed" or ("\n" .. fails .. " failed"))
os.exit(fails == 0 and 0 or 1)
