return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      typescript = { "prettier" },
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      svelte = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      scss = { "prettier" },
      markdown = { "prettier" },
      yaml = { "prettier" },
    },
    -- Don't override LazyVim's format_on_save
    formatters = {
      prettier = {
        condition = function(self, ctx)
          local bufname = vim.api.nvim_buf_get_name(ctx.buf)
          -- Skip build directories
          local ignore_patterns = {
            "%.svelte%-kit/",
            "/node_modules/",
            "/dist/",
            "/build/",
            "%.git/",
            "/target/",
            "/%.next/",
            "/%.nuxt/",
          }

          for _, pattern in ipairs(ignore_patterns) do
            if bufname:match(pattern) then
              return false
            end
          end
          return true
        end,
      },
      stylua = {
        condition = function(self, ctx)
          local bufname = vim.api.nvim_buf_get_name(ctx.buf)
          -- Only run on actual lua files, not in build dirs
          return vim.bo[ctx.buf].filetype == "lua"
            and not bufname:match("/node_modules/")
            and not bufname:match("%.git/")
        end,
        prepend_args = {
          "--indent-type=Spaces",
          "--indent-width=2",
          "--column-width=80",
        },
      },
    },
  },
}
