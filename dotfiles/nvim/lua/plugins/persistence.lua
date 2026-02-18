local LOG_FILE = vim.fn.stdpath("state") .. "/persistence-debug.log"

local function log(msg)
  local f = io.open(LOG_FILE, "a")
  if f then
    f:write(os.date("%H:%M:%S") .. " " .. msg .. "\n")
    f:close()
  end
end

return {
  {
    "folke/persistence.nvim",
    lazy = false,
    config = function(_, opts)
      log("config() called")
      local persistence = require("persistence")
      persistence.setup(opts)
      log("setup() done, dir=" .. require("persistence.config").options.dir)

      -- Auto-load session on startup
      vim.api.nvim_create_autocmd("VimEnter", {
        nested = true,
        callback = function()
          local argc = vim.fn.argc()
          local cwd = vim.fn.getcwd()
          local session = persistence.current()
          local exists = vim.fn.filereadable(session) == 1
          log("VimEnter: argc=" .. argc .. " cwd=" .. cwd)
          log("VimEnter: session=" .. session .. " exists=" .. tostring(exists))

          if argc == 0 then
            if exists then
              log("loading session")
              persistence.load()
              log("session loaded")
            else
              log("SKIP: session file not found")
            end
          else
            log("SKIP: argc=" .. argc)
          end
        end,
      })

      -- Periodic auto-save every 60 seconds
      local timer = vim.uv.new_timer()
      timer:start(10000, 10000, vim.schedule_wrap(function()
        if persistence.active() then
          persistence.save()
          log("periodic save")
        end
      end))
    end,
  },
}
