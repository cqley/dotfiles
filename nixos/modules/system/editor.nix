{ config, pkgs, ... }:

let
  neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    extraPackages = with pkgs; [
      ripgrep
      fd
      wl-clipboard
      nixd
      nixfmt
      lua-language-server
      stylua
      typescript-language-server
      vscode-langservers-extracted
      prettierd
      bash-language-server
      shfmt
    ];

    plugins = with pkgs.vimPlugins; [
      lualine-nvim
      telescope-nvim
      plenary-nvim
      nvim-web-devicons
      neo-tree-nvim
      nui-nvim
      alpha-nvim
      which-key-nvim
      gitsigns-nvim
      (nvim-treesitter.withPlugins (p: with p; [
        nix lua javascript typescript html css json bash markdown markdown_inline
      ]))
      nvim-lspconfig
      blink-cmp
      conform-nvim
      render-markdown-nvim
    ];

    initLua = ''
      vim.opt.number = true
      vim.opt.statuscolumn = "%l %s"
      vim.opt.tabstop = 2
      vim.opt.softtabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.wrap = false
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.hlsearch = false
      vim.opt.signcolumn = "yes"
      vim.opt.scrolloff = 8
      vim.opt.showmode = false
      vim.opt.timeoutlen = 300
      vim.opt.updatetime = 250
      vim.opt.undofile = true
      vim.opt.matchpairs = ""
      vim.g.loaded_matchparen = 1

      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      local map = vim.keymap.set
      map({"n", "i"}, "<c-s>", "<cmd>write<cr>", {desc = "save file"})
      map("n", "<c-q>", "<cmd>quit<cr>", {desc = "quit"})
      map({"n", "x"}, "gy", '"+y', {desc = "copy to clipboard"})
      map({"n", "x"}, "gp", '"+p', {desc = "paste from clipboard"})
      map("n", "<c-z>", "u", {desc = "undo"})
      map("i", "<c-z>", "<c-o>u", {desc = "undo"})
      map("n", "<c-y>", "<c-r>", {desc = "redo"})
      map("i", "<c-y>", "<c-o><c-r>", {desc = "redo"})
      map("n", "<c-a>", "ggVG", {desc = "select all"})
      map("i", "<c-a>", "<esc>ggVG", {desc = "select all"})

      map("n", "<c-f>", "<cmd>Telescope current_buffer_fuzzy_find<cr>", {desc = "search buffer"})
      map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", {desc = "find files"})
      map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", {desc = "text search"})
      map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", {desc = "find buffers"})
      map("n", "<c-e>", "<cmd>Neotree toggle<cr>", {desc = "file explorer"})

      map("n", "<c-left>", "<c-w>h", {desc = "move left"})
      map("n", "<c-down>", "<c-w>j", {desc = "move down"})
      map("n", "<c-up>", "<c-w>k", {desc = "move up"})
      map("n", "<c-right>", "<c-w>l", {desc = "move right"})
      map("n", "<leader>|", "<cmd>vsplit<cr>", {desc = "vertical split"})
      map("n", "<leader>-", "<cmd>split<cr>", {desc = "horizontal split"})
      map("n", "<c-x>", "<cmd>close<cr>", {desc = "close split"})

      map("n", "]h", "<cmd>Gitsigns next_hunk<cr>", {desc = "next git hunk"})
      map("n", "[h", "<cmd>Gitsigns prev_hunk<cr>", {desc = "prev git hunk"})
      map("n", "<leader>gs", "<cmd>Gitsigns stage_hunk<cr>", {desc = "stage hunk"})
      map("n", "<leader>gr", "<cmd>Gitsigns reset_hunk<cr>", {desc = "reset hunk"})
      map("n", "<leader>gb", "<cmd>Gitsigns blame_line<cr>", {desc = "blame line"})

      -- theme from ~/.colors/colors.lua, reloaded when it changes
      -- (falls back to the terminal palette if the file is missing)
      local lualine_opts = {
        options = { component_separators = "", section_separators = "" },
      }
      local colors_dir = "/home/cat/.colors"
      local function apply_colors()
        local ok, p = pcall(dofile, colors_dir .. "/colors.lua")
        if not ok then
          vim.opt.termguicolors = false
          return
        end
        vim.opt.termguicolors = true
        local c, bg, fg = p.color, p.background, p.foreground
        for i = 0, 15 do vim.g["terminal_color_" .. i] = c[i] end
        local hl = function(group, spec) vim.api.nvim_set_hl(0, group, spec) end
        hl("Normal", { fg = fg, bg = bg })
        hl("NormalFloat", { fg = fg, bg = bg })
        hl("FloatBorder", { fg = c[8], bg = bg })
        hl("Comment", { fg = c[8], italic = true })
        hl("String", { fg = c[11] })
        hl("Constant", { fg = c[14] })
        hl("Number", { fg = c[6] })
        hl("Identifier", { fg = fg })
        hl("@variable", { fg = fg })
        hl("Function", { fg = c[12] })
        hl("Statement", { fg = c[5] })
        hl("Keyword", { fg = c[5] })
        hl("PreProc", { fg = c[5] })
        hl("Type", { fg = c[13] })
        hl("Special", { fg = c[6] })
        hl("Operator", { fg = c[7] })
        hl("Delimiter", { fg = c[7] })
        hl("LineNr", { fg = c[8] })
        hl("CursorLineNr", { fg = fg })
        hl("SignColumn", { bg = bg })
        hl("Visual", { bg = c[8] })
        hl("Search", { fg = c[15], bg = c[4] })
        hl("IncSearch", { fg = c[0], bg = p.accent })
        hl("CurSearch", { fg = c[0], bg = p.accent })
        hl("Pmenu", { fg = fg, bg = c[8] })
        hl("PmenuSel", { fg = c[15], bg = c[4] })
        hl("StatusLine", { fg = fg, bg = c[8] })
        hl("StatusLineNC", { fg = c[7], bg = c[8] })
        hl("WinSeparator", { fg = c[8] })
        hl("Directory", { fg = c[12] })
        hl("Title", { fg = p.accent, bold = true })
        hl("TelescopeMatching", { fg = p.accent, bold = true })
        hl("TelescopeSelection", { bg = c[8] })
      end
      apply_colors()
      local watcher = vim.uv.new_fs_event()
      if watcher then
        watcher:start(colors_dir, {}, vim.schedule_wrap(function(_, file)
          if file == "colors.lua" then
            apply_colors()
            require("lualine").setup(lualine_opts)
          end
        end))
      end

      require("lualine").setup(lualine_opts)

      require("telescope").setup({
        defaults = {
          file_ignore_patterns = { "node_modules", "%.git/", "%.lock" },
          layout_config = { horizontal = { preview_width = 0.5 } },
        },
      })

      require("neo-tree").setup({
        window = {
          position = "right",
          width = 30,
          mappings = { ["l"] = "open", ["h"] = "close_node" },
        },
        filesystem = {
          filtered_items = {
            hide_dotfiles = false,
            hide_gitignored = false,
            hide_by_name = { ".git" },
          },
          follow_current_file = { enabled = true },
        },
      })

      require("which-key").setup()
      require("gitsigns").setup()

      local dashboard = require("alpha.themes.dashboard")
      dashboard.section.header.val = {}
      dashboard.section.buttons.val = {
        dashboard.button("f", "   find file", "<cmd>Telescope find_files<cr>"),
        dashboard.button("n", "   new file", "<cmd>enew<cr>"),
        dashboard.button("r", "   recent files", "<cmd>Telescope oldfiles<cr>"),
        dashboard.button("q", "   quit", "<cmd>qa<cr>"),
      }
      require("alpha").setup(dashboard.opts)

      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          if pcall(vim.treesitter.start) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
          vim.opt_local.wrap = true
          vim.opt_local.spell = true
          vim.opt_local.conceallevel = 2
        end,
      })

      vim.lsp.enable({ "nixd", "lua_ls", "ts_ls", "html", "cssls", "jsonls", "bashls" })
      vim.diagnostic.config({ virtual_text = true })
      require("blink.cmp").setup()

      require("conform").setup({
        formatters_by_ft = {
          nix = { "nixfmt" },
          lua = { "stylua" },
          javascript = { "prettierd" },
          typescript = { "prettierd" },
          html = { "prettierd" },
          css = { "prettierd" },
          json = { "prettierd" },
          markdown = { "prettierd" },
          sh = { "shfmt" },
        },
        format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
      })

      map("n", "gd", vim.lsp.buf.definition, {desc = "go to definition"})
      map("n", "<leader>ca", vim.lsp.buf.code_action, {desc = "code action"})
      map("n", "<leader>rn", vim.lsp.buf.rename, {desc = "rename"})
      map("n", "<leader>xx", vim.diagnostic.setloclist, {desc = "diagnostics list"})

      require("render-markdown").setup()
    '';
  };
in
{
  home-manager.users.cat.programs.neovim = neovim;
  home-manager.users.root = {
    programs.neovim = neovim;
    xdg.configFile."nvim/init.lua".force = true;
    home.stateVersion = "26.05";
  };
  environment.systemPackages = [ config.home-manager.users.root.programs.neovim.finalPackage ];
}