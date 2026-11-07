require("config.lazy")

vim.wo.number = true
vim.wo.numberwidth = 4

vim.bo.tabstop = 2
vim.bo.shiftwidth = 2
vim.bo.softtabstop = 2
vim.bo.expandtab = true
vim.bo.autoindent = true

vim.o.hlsearch = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { silent = true })

vim.wo.cursorline = true

vim.wo.list = true
vim.opt.listchars = {
  tab = "» ",
  trail = "·",
  nbsp = "␣",
}

vim.opt.clipboard = "unnamedplus"
vim.bo.undofile = true

