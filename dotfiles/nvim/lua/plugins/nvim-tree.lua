return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    keys = {
      {
        "<leader>fe",
        function()
          require("neo-tree.command").execute({
            toggle = true,
            dir = LazyVim.root(),
            position = "current",
            reveal = true,
          })
        end,
        desc = "Explorer NeoTree (Root Dir)",
      },
      {
        "<leader>fE",
        function()
          require("neo-tree.command").execute({
            toggle = true,
            dir = vim.uv.cwd(),
            position = "current",
            reveal = true,
          })
        end,
        desc = "Explorer NeoTree (cwd)",
      },
      {
        "<leader>e",
        "<leader>fe",
        desc = "Explorer NeoTree (Root Dir)",
        remap = true,
      },
      {
        "<leader>E",
        "<leader>fE",
        desc = "Explorer NeoTree (cwd)",
        remap = true,
      },
      {
        "<leader>ge",
        function()
          require("neo-tree.command").execute({
            source = "git_status",
            toggle = true,
          })
        end,
        desc = "Git Explorer",
      },
      {
        "<leader>be",
        function()
          require("neo-tree.command").execute({
            source = "buffers",
            toggle = true,
          })
        end,
        desc = "Buffer Explorer",
      },
    },
    init = function()
      -- FIX: use `autocmd` for lazy-loading neo-tree instead of directly requiring it,
      -- because `cwd` is not set up properly.
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup(
          "Neotree_start_directory",
          { clear = true }
        ),
        desc = "Start Neo-tree with directory",
        once = true,
        callback = function()
          if package.loaded["neo-tree"] then
            return
          else
            local stats = vim.uv.fs_stat(vim.fn.argv(0))
            if stats and stats.type == "directory" then
              -- on open
              require("neo-tree")
            end
          end
        end,
      })
    end,
  },
}
