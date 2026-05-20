{ config, pkgs, ... }:

{
  home.username = "silly";
  home.homeDirectory = "/home/silly";
  home.stateVersion = "25.11";

  xdg.configFile."fish/config.fish".force = true;
  xdg.configFile."kitty/kitty.conf".force = true;
  xdg.configFile."dunst/dunstrc".force = true;
  xdg.configFile."btop/btop.conf".force = true;

  programs.fish = {
    enable = true;
    shellAbbrs = {
      s = "sudo";
      update = "";
      zed = "zeditor";
    };
    functions = {
      fish_greeting = { body = ""; };
      fish_prompt = {
        body = ''
          echo -n (prompt_pwd)
          echo -n " > "
        '';
      };
    };
    interactiveShellInit = ''
      if status is-interactive
          cat ~/.cache/wal/sequences
      end
    '';
  };

  programs.kitty = {
    enable = true;
    extraConfig = ''
      include ~/.cache/wal/colors-kitty.conf

      shell fish
      shell_integration enabled

      cursor_trail 3
      cursor_trail_decay 0.1 0.4
      cursor_shape beam
      cursor_blink_interval 1
      shell_integration no-cursor

      confirm_os_window_close 0
      allow_remote_control yes

      background_opacity 0.7
      background_blur 1
      dynamic_background_opacity 1
      scrollbar_handle_opacity 0
      scrollbar_track_opacity 0
      scrollbar_track_hover_opacity 0
    '';
  };

  services.dunst = {
    enable = true;
    settings = {
      global = {
        origin = "top-right";
        offset = "15x15";
        monitor = 1;
        follow = "none";
        width = 250;
        height = "0x75";
        frame_width = 2;
        frame_color = "#ffffff";
        corner_radius = 0;
        background = "#000000";
        foreground = "#ffffff";
        separator_color = "frame";
        separator_height = 2;
        padding = 15;
        horizontal_padding = 20;
        icon_position = "left";
        max_icon_size = 32;
        markup = "full";
        format = "<span foreground='#ffffff'><b>%s</b></span>\n%b";
        alignment = "left";
        word_wrap = "yes";
        sort = "no";
        stack_duplicates = "false";
        notification_limit = 1;
        indicate_hidden = "yes";
        override_dbus_timeout = 3;
      };
      urgency_critical = {
        background = "#ff0000";
        foreground = "#ffffff";
        frame_color = "#ffffff";
        override_dbus_timeout = 5;
      };
    };
  };

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "TTY";
      theme_background = true;
      truecolor = true;
      force_tty = false;
      presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty";
      vim_keys = false;
      rounded_corners = false;
      terminal_sync = true;
      update_ms = 2000;
      background_update = true;
      clock_format = "%X";
      base_10_sizes = false;
      base_10_bitrate = "Auto";
      log_level = "WARNING";
      save_config_on_exit = true;
      shown_boxes = "cpu mem net proc";
      graph_symbol = "braille";
      graph_symbol_cpu = "default";
      graph_symbol_gpu = "default";
      graph_symbol_mem = "default";
      graph_symbol_net = "default";
      graph_symbol_proc = "default";
      cpu_bottom = false;
      cpu_graph_upper = "Auto";
      cpu_graph_lower = "Auto";
      cpu_invert_lower = true;
      cpu_single_graph = false;
      check_temp = true;
      cpu_sensor = "Auto";
      show_coretemp = true;
      cpu_core_map = "";
      temp_scale = "celsius";
      show_cpu_freq = true;
      freq_mode = "first";
      show_cpu_watts = true;
      show_uptime = true;
      custom_cpu_name = "";
      proc_left = false;
      proc_sorting = "cpu lazy";
      proc_reversed = false;
      proc_tree = false;
      proc_colors = true;
      proc_gradient = true;
      proc_per_core = false;
      proc_mem_bytes = true;
      proc_cpu_graphs = true;
      proc_info_smaps = false;
      proc_filter_kernel = false;
      proc_aggregate = false;
      keep_dead_proc_usage = false;
      mem_graphs = true;
      mem_below_net = false;
      show_swap = true;
      swap_disk = true;
      zfs_arc_cached = true;
      show_disks = true;
      disks_filter = "";
      only_physical = true;
      use_fstab = true;
      disk_free_priv = false;
      show_io_stat = true;
      io_mode = false;
      io_graph_combined = false;
      io_graph_speeds = "";
      zfs_hide_datasets = false;
      net_iface = "";
      net_auto = true;
      net_sync = true;
      net_download = 100;
      net_upload = 100;
      show_gpu_info = "Auto";
      shown_gpus = "nvidia";
      gpu_mirror_graph = true;
      nvml_measure_pcie_speeds = true;
      rsmi_measure_pcie_speeds = true;
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    extraPackages = with pkgs; [
      git
      gcc
      ripgrep
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

      vim.keymap.set({"n", "i"}, "<C-s>", "<cmd>write<cr>", {desc = "save file"})
      vim.keymap.set("n", "<C-s>", "<cmd>write<cr>", {desc = "save file"})
      vim.keymap.set("n", "<C-q>", "<cmd>quit<cr>", {desc = "quit neovim"})
      vim.keymap.set("n", "<C-Q>", "<cmd>quit!<cr>", {desc = "force quit"})
      vim.keymap.set("n", "<C-h>", "<cmd>nohlsearch<cr>", {desc = "clear search highlight"})
      vim.keymap.set({"n", "x"}, "gy", '"+y', {desc = "copy to clipboard"})
      vim.keymap.set({"n", "x"}, "gp", '"+p', {desc = "paste from clipboard"})
      vim.keymap.set("n", "<C-z>", "u", {desc = "undo"})
      vim.keymap.set("i", "<C-z>", "<C-o>u", {desc = "undo"})
      vim.keymap.set("n", "<C-y>", "<C-r>", {desc = "redo"})
      vim.keymap.set("i", "<C-y>", "<C-o><C-r>", {desc = "redo"})
      vim.keymap.set({"n", "i"}, "<C-a>", "ggVG", {desc = "select all"})
      vim.keymap.set("n", "<C-ff>", "<cmd>Telescope find_files<cr>", {desc = "find files"})
      vim.keymap.set("n", "<C-fg>", "<cmd>Telescope live_grep<cr>", {desc = "text search"})
      vim.keymap.set("n", "<C-fb>", "<cmd>Telescope buffers<cr>", {desc = "find buffers"})
      vim.keymap.set("n", "<C-fh>", "<cmd>Telescope help_tags<cr>", {desc = "help tags"})
      vim.keymap.set("n", "<C-h>", "<C-w>h", {desc = "move to left split"})
      vim.keymap.set("n", "<C-j>", "<C-w>j", {desc = "move to lower split"})
      vim.keymap.set("n", "<C-k>", "<C-w>k", {desc = "move to upper split"})
      vim.keymap.set("n", "<C-l>", "<C-w>l", {desc = "move to right split"})
      vim.keymap.set("n", "<C-|>", "<cmd>vsplit<cr>", {desc = "vertical split"})
      vim.keymap.set("n", "<C-->", "<cmd>split<cr>", {desc = "horizontal split"})
      vim.keymap.set("n", "<C-x>", "<cmd>close<cr>", {desc = "close split"})

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
            { "<C-ff>", "<cmd>Telescope find_files<cr>", desc = "find files" },
            { "<C-fg>", "<cmd>Telescope live_grep<cr>", desc = "text search" },
            { "<C-fb>", "<cmd>Telescope buffers<cr>", desc = "find buffers" },
            { "<C-fh>", "<cmd>Telescope help_tags<cr>", desc = "help tags" },
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
            { "<C-e>", "<cmd>Neotree toggle<cr>", desc = "toggle file explorer" },
          },
          config = function()
            require("neo-tree").setup({
              window = {
                position = "right",
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
              "       ⠀⠀⠀⢀⡴⠲⣄⠀⠀⢀⡶⠲⡄⠀⣀⣀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
              "       ⣀⣀⣀⣾⠁⠀⠹⠿⠟⠟⠀⠀⠙⣛⣉⡻⠿⠋⣿⣷⢦⣄⠀⠀⠀⠀⠀⠀",
              "       ⠭⠭⣽⠇⠀⠶⠀⢴⣦⠀⠶⠆⠸⠯⠭⠄⠀⠀⠀⠀⠀⠙⢧⡀⠀⢀⣤⣤",
              "⠀⠀       ⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢷⣤⣾⣻⡟",
              "       ⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣧⠽⠋⠀",
              "       ⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠀⠀⠀⠀",
              "       ⠀⠀⢷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡟⠀⠀⠀⠀",
              "⠀       ⠀⠈⠳⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⠟⠀⠀⠀⠀⠀",
              "⠀⠀       ⠀⠀⠉⠿⠟⠛⠛⠻⠾⠛⠛⠛⠛⠻⠟⠛⠛⠻⠾⠃⠀⠀⠀⠀⠀⠀",
            }

            dashboard.section.buttons.val = {
              dashboard.button("f", " > find file", "<cmd>Telescope find_files<cr>"),
              dashboard.button("n", " > new file", "<cmd>enew<cr>"),
              dashboard.button("r", " > recent files", "<cmd>Telescope oldfiles<cr>"),
              dashboard.button("q", " > quit", "<cmd>qa<cr>"),
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
    '';
  };

home.packages = with pkgs; [
    (writeShellScriptBin "power" ''
      options="lock\nlogout\nshutdown\nreboot"
      choice=$(echo -e "$options" | ${pkgs.rofi}/bin/rofi -dmenu -i -p ">")

      case "$choice" in
          lock)
              ${pkgs.hyprlock}/bin/hyprlock
              ;;
          logout)
              command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || ${pkgs.hyprland}/bin/hyprctl dispatch exit
              ;;
          shutdown)
              shutdown now
              ;;
          reboot)
              reboot
              ;;
      esac
    '')
  ];

  programs.home-manager.enable = true;
}
