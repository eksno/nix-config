return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        eslint = {
          mason = false,
          enabled = false,
        },
      },
    },
  },
}
