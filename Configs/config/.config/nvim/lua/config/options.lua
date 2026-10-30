-- options -------------

-- moxiu szpont fixes
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.whichwrap:append("<,>,[,]")
vim.env.PATH = "/etc/profiles/per-user/" .. vim.env.USER .. "/bin:" .. vim.env.PATH
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Keep recovery files in private, persistent directories.
local state = vim.fn.stdpath("state")
for _, name in ipairs({ "swap", "undo" }) do
  vim.fn.mkdir(state .. "/" .. name, "p", 448) -- 0700
end
vim.opt.directory = state .. "/swap//"
vim.opt.undodir = state .. "/undo//"
