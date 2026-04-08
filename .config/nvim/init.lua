vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.numberwidth = 4
vim.opt.statuscolumn = "%l %s"
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.termguicolors = false
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8
vim.opt.showmode = false
vim.opt.timeoutlen = 300
vim.opt.updatetime = 250
vim.opt.foldcolumn = "0"
vim.opt.directory = vim.fn.stdpath("state") .. "/swap//"

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set({"n", "i"}, "<C-s>", "<cmd>write<cr>", {desc = "Save file"})
vim.keymap.set("n", "<C-s>", "<cmd>write<cr>", {desc = "Save file"})
vim.keymap.set("n", "<C-q>", "<cmd>quit<cr>", {desc = "Quit Neovim"})
vim.keymap.set("n", "<C-Q>", "<cmd>quit!<cr>", {desc = "Force quit"})
vim.keymap.set("n", "<C-h>", "<cmd>nohlsearch<cr>", {desc = "Clear search highlight"})
vim.keymap.set({"n", "x"}, "gy", '"+y', {desc = "Copy to clipboard"})
vim.keymap.set({"n", "x"}, "gp", '"+p', {desc = "Paste from clipboard"})
vim.keymap.set("n", "<C-z>", "u", {desc = "Undo"})
vim.keymap.set("i", "<C-z>", "<C-o>u", {desc = "Undo"})
vim.keymap.set("n", "<C-y>", "<C-r>", {desc = "Redo"})
vim.keymap.set("i", "<C-y>", "<C-o><C-r>", {desc = "Redo"})
vim.keymap.set({"n", "i"}, "<C-a>", "ggVG", {desc = "Select all"})
vim.keymap.set("n", "<C-ff>", "<cmd>Telescope find_files<cr>", {desc = "Find files"})
vim.keymap.set("n", "<C-fg>", "<cmd>Telescope live_grep<cr>", {desc = "Text search"})
vim.keymap.set("n", "<C-fb>", "<cmd>Telescope buffers<cr>", {desc = "Find buffers"})
vim.keymap.set("n", "<C-fh>", "<cmd>Telescope help_tags<cr>", {desc = "Help tags"})
vim.keymap.set("n", "<C-h>", "<C-w>h", {desc = "Move to left split"})
vim.keymap.set("n", "<C-j>", "<C-w>j", {desc = "Move to lower split"})
vim.keymap.set("n", "<C-k>", "<C-w>k", {desc = "Move to upper split"})
vim.keymap.set("n", "<C-l>", "<C-w>l", {desc = "Move to right split"})
vim.keymap.set("n", "<C-|>", "<cmd>vsplit<cr>", {desc = "Vertical split"})
vim.keymap.set("n", "<C-->", "<cmd>split<cr>", {desc = "Horizontal split"})
vim.keymap.set("n", "<C-x>", "<cmd>close<cr>", {desc = "Close split"})

vim.cmd.colorscheme("default")
vim.opt.matchpairs = ""
vim.api.nvim_set_hl(0, "MatchParen", {})
vim.cmd("highlight clear MatchParen")
vim.cmd("highlight MatchParen guifg=NONE guibg=NONE gui=NONE")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    keys = {
      { "<C-ff>", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<C-fg>", "<cmd>Telescope live_grep<cr>", desc = "Text search" },
      { "<C-fb>", "<cmd>Telescope buffers<cr>", desc = "Find buffers" },
      { "<C-fh>", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git", "%.lock" },
          layout_strategy = "horizontal",
          layout_config = {
            horizontal = {
              preview_width = 0.5,
            },
          },
        },
        pickers = {
          find_files = {
            hidden = true,
            no_ignore = false,
          },
          live_grep = {
            additional_args = function()
              return { "--hidden" }
            end,
          },
        },
      })
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<C-e>", "<cmd>Neotree toggle<cr>", desc = "Toggle file explorer" },
    },
    config = function()
      require("neo-tree").setup({
        window = {
          position = "left",
          width = 30,
          mappings = {
            ["l"] = "open",
            ["h"] = "close_node",
            ["<CR>"] = "open",
            ["<Esc>"] = "revert_preview",
          },
        },
        filesystem = {
          filtered_items = {
            visible = false,
            hide_dotfiles = false,
            hide_gitignored = false,
            hide_by_name = {
              ".git",
              ".DS_Store",
              "thumbs.db",
            },
          },
          follow_current_file = {
            enabled = true,
          },
        },
      })
    end,
  },
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        "⠀⠀⠀⢀⡴⠲⣄⠀⠀⢀⡶⠲⡄⠀⣀⣀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
        "⣀⣀⣀⣾⠁⠀⠹⠿⠟⠟⠀⠀⠙⣛⣉⡻⠿⠋⣿⣷⢦⣄⠀⠀⠀⠀⠀⠀",
        "⠭⠭⣽⠇⠀⠶⠀⢴⣦⠀⠶⠆⠸⠯⠭⠄⠀⠀⠀⠀⠀⠙⢧⡀⠀⢀⣤⣤",
        "⠀⠀⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢷⣤⣾⣻⡟",
        "⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣧⠽⠋⠀",
        "⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠀⠀⠀⠀",
        "⠀⠀⢷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⠀⠀⠀⠀",
        "⠀⠀⠈⠳⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⠟⠀⠀⠀⠀⠀",
        "⠀⠀⠀⠀⠉⠿⠟⠛⠛⠻⠾⠛⠛⠛⠛⠻⠟⠛⠛⠻⠾⠃⠀⠀⠀⠀⠀⠀",
      }

      dashboard.section.buttons.val = {
        dashboard.button("f", "find file", "<cmd>Telescope find_files<cr>"),
        dashboard.button("n", "new file", "<cmd>enew<cr>"),
        dashboard.button("r", "recent files", "<cmd>Telescope oldfiles<cr>"),
        dashboard.button("q", "quit", "<cmd>qa<cr>"),
      }

      alpha.setup(dashboard.opts)
    end,
  },
})

vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  callback = function()
    vim.notify("plugins loaded", vim.log.levels.INFO, { title = "neovim" })
  end,
})
