-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.lazyvim_python_lsp = "basedpyright"
-- Force OSC 52 clipboard over SSH (skips neovim's auto-detection which fails through nested tmux)
local osc52 = require("vim.ui.clipboard.osc52")
vim.g.clipboard = {
  name = "OSC 52",
  copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
  paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
}
-- Force unnamedplus before LazyVim captures it (LazyVim blanks it on SSH_CONNECTION)
vim.o.clipboard = "unnamedplus"
vim.env.SSH_CONNECTION = nil
