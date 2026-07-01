{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    extraPackages = with pkgs; [
      ripgrep
    ];

    plugins = with pkgs.vimPlugins; [
      lualine-nvim
      telescope-nvim
      plenary-nvim
      nvim-web-devicons
      neo-tree-nvim
      nui-nvim
      alpha-nvim
    ];

    initLua = ''
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

      vim.keymap.set({"n", "i"}, "<c-s>", "<cmd>write<cr>", {desc = "save file"})
      vim.keymap.set("n", "<c-q>", "<cmd>quit<cr>", {desc = "quit neovim"})
      vim.keymap.set("n", "<c-h>", "<cmd>nohlsearch<cr>", {desc = "clear search highlight"})
      vim.keymap.set({"n", "x"}, "gy", '"+y', {desc = "copy to clipboard"})
      vim.keymap.set({"n", "x"}, "gp", '"+p', {desc = "paste from clipboard"})
      vim.keymap.set("n", "<c-z>", "u", {desc = "undo"})
      vim.keymap.set("i", "<c-z>", "<c-o>u", {desc = "undo"})
      vim.keymap.set("n", "<c-y>", "<c-r>", {desc = "redo"})
      vim.keymap.set("i", "<c-y>", "<c-o><c-r>", {desc = "redo"})
      vim.keymap.set({"n", "i"}, "<c-a>", "ggVG", {desc = "select all"})
      
      vim.keymap.set("n", "<c-f>", "<cmd>Telescope current_buffer_fuzzy_find<cr>", {desc = "search buffer"})

      vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", {desc = "find files"})
      vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", {desc = "text search"})
      vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<cr>", {desc = "find buffers"})
      vim.keymap.set("n", "<c-e>", "<cmd>Neotree toggle<cr>", {desc = "toggle file explorer"})
      
      vim.keymap.set("n", "<c-left>", "<c-w>h", {desc = "move left"})
      vim.keymap.set("n", "<c-down>", "<c-w>j", {desc = "move down"})
      vim.keymap.set("n", "<c-up>", "<c-w>k", {desc = "move up"})
      vim.keymap.set("n", "<c-right>", "<c-w>l", {desc = "move right"})
      vim.keymap.set("n", "<c-|>", "<cmd>vsplit<cr>", {desc = "vertical split"})
      vim.keymap.set("n", "<c-->", "<cmd>split<cr>", {desc = "horizontal split"})
      vim.keymap.set("n", "<c-x>", "<cmd>close<cr>", {desc = "close split"})

      vim.cmd.colorscheme("default")
      vim.opt.matchpairs = ""
      vim.api.nvim_set_hl(0, "MatchParen", {})
      vim.cmd("highlight clear MatchParen")
      vim.cmd("highlight MatchParen guifg=NONE guibg=NONE gui=NONE")

      require("lualine").setup({
        options = {
          icons_enabled = true,
          theme = "auto",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
      })

      require("telescope").setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git", "%.lock" },
          layout_strategy = "horizontal",
          layout_config = { horizontal = { preview_width = 0.5 } },
        },
      })

      require("neo-tree").setup({
        window = {
          position = "right",
          width = 30,
          mappings = {
            ["l"] = "open",
            ["h"] = "close_node",
            ["<cr>"] = "open",
            ["<esc>"] = "revert_preview",
          },
        },
        filesystem = {
          filtered_items = {
            visible = false,
            hide_dotfiles = false,
            hide_gitignored = false,
            hide_by_name = { ".git", ".DS_Store", "thumbs.db" },
          },
          follow_current_file = { enabled = true },
        },
      })

      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        "        ⠀⠀⠀⢀⡴⠲⣄⠀⠀⢀⡶⠲⡄⠀⣀⣀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
        "        ⣀⣀⣀⣾⠁⠀⠹⠿⠟⠟⠀⠀⠙⣛⣉⡻⠿⠋⣿⣷⢦⣄⠀⠀⠀⠀⠀⠀",
        "        ⠭⠭⣽⠇⠀⠶⠀⢴⣦⠀⠶⠆⠸⠯⠭⠄⠀⠀⠀⠀⠀⠙⢧⡀⠀⢀⣤⣤",
        "⠀⠀        ⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢷⣤⣾⣻⡟",
        "        ⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣧⠽⠋⠀",
        "        ⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠀⠀⠀⠀",
        "        ⠀⠀⢷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⠀⠀⠀⠀",
        "⠀        ⠀⠈⠳⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⠟⠀⠀⠀⠀⠀",
        "⠀⠀        ⠀⠀⠉⠿⠟⠛⠛⠻⠾⠛⠛⠛⠛⠻⠟⠛⠛⠻⠾⠃⠀⠀⠀⠀⠀⠀",
      }

      dashboard.section.buttons.val = {
        dashboard.button("f", " > find file", "<cmd>Telescope find_files<cr>"),
        dashboard.button("n", " > new file", "<cmd>enew<cr>"),
        dashboard.button("r", " > recent files", "<cmd>Telescope oldfiles<cr>"),
        dashboard.button("q", " > quit", "<cmd>qa<cr>"),
      }

      alpha.setup(dashboard.opts)
    '';
  };
}
