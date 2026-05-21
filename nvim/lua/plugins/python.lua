return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        basedpyright = {
          mason = false,
          cmd = { "basedpyright-langserver", "--stdio" },
        },
        ruff = {
          mason = false,
          cmd = { "ruff", "server" },
        },
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(s)
        return s ~= "basedpyright" and s ~= "ruff"
      end, opts.ensure_installed or {})
    end,
  },
}
