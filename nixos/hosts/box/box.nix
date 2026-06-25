{ config, pkgs, ... }:

{
  imports = [
    ../../mdls/hypr.nix
    ../../mdls/qksh.nix
    ../../mdls/vim.nix
    ../../mdls/colors.nix
  ];

  home.username = "cat";
  home.homeDirectory = "/home/cat";
  home.stateVersion = "26.05";

  xdg.configFile."fish/config.fish".force = true;
  xdg.configFile."kitty/kitty.conf".force = true;
  xdg.configFile."btop/btop.conf".force = true;

  programs.fish = {
    enable = true;
    shellAbbrs = {
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos/#box";
      update = "nix flake update --flake /etc/nixos/ && sudo nixos-rebuild switch --flake /etc/nixos/#box";
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
          cat ~/.colors/sequences
      end
    '';
    loginShellInit = ''
      if test -z "$DISPLAY" -a (tty) = "/dev/tty1"
        exec start-hyprland
      end
    '';
  };

  programs.kitty = {
    enable = true;
    extraConfig = ''
      include ~/.colors/kitty.conf

      shell fish
      shell_integration enabled

      font_family JetBrainsMono Nerd Font
      font_size 11
      
      cursor_trail 3
      cursor_trail_decay 0.1 0.4
      cursor_shape beam
      cursor_blink_interval 1
      shell_integration no-cursor

      confirm_os_window_close 0
      allow_remote_control yes

      background_opacity 1
      background_blur 1
      dynamic_background_opacity 1
      scrollbar_handle_opacity 0
      scrollbar_track_opacity 0
      scrollbar_track_hover_opacity 0
    '';
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

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.kdePackages.breeze;
    name = "breeze_cursors";
    size = 16;
  };

  home.sessionVariables = {
    XCURSOR_THEME = "breeze_cursors";
    XCURSOR_SIZE = "16";
    QT_CURSOR_SIZE = "16";
    QT_QPA_PLATFORMTHEME = "kde";
  };

  gtk = {
    enable = true;
    theme = { name = "Adwaita-dark"; package = pkgs.gnome-themes-extra; };
    font = { name = "MonaspiceNe Nerd Font Mono"; size = 11; };
  };

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze";
  };

  xdg.configFile = {
  "dolphinrc".text = ''
    [General]
    ShowPreview=true
    ViewMode=1

    [MainWindow]
    MenuBar=Disabled
    ToolBarsMovable=Disabled
  '';

  "kdeglobals".source = pkgs.runCommand "breeze-dark-white" {} ''
    sed -E \
      -e 's/61,174,233/255,255,255/g' \
      -e 's/24,115,204/255,255,255/g' \
      -e 's/AccentColor=[0-9]+,[0-9]+,[0-9]+/AccentColor=255,255,255/' \
      "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors" > $out
  '';
};

  home.file = {
    ".documents/obsidian/.obsidian/app.json".text = builtins.toJSON {
      readableLineLength = true;
      foldHeading = true;
      showLineNumber = true;
      spellcheck = false;
      vimMode = false;
      newFileLocation = "current";
      promptDelete = false;
    };
    ".documents/obsidian/.obsidian/appearance.json".text = builtins.toJSON {
      accentColor = "#ffa8db";
      cssTheme = "";
      theme = "obsidian";
    };
    ".documents/obsidian/.obsidian/core-plugins.json".text = builtins.toJSON {
      "file-explorer" = true;
      "global-search" = true;
      "switcher" = false;
      "graph" = true;
      "backlink" = false;
      "canvas" = false;
      "outgoing-link" = true;
      "tag-pane" = true;
      "footnotes" = false;
      "properties" = false;
      "page-preview" = true;
      "daily-notes" = true;
      "templates" = false;
      "note-composer" = false;
      "command-palette" = false;
      "slash-command" = false;
      "editor-status" = true;
      "bookmarks" = false;
      "markdown-importer" = false;
      "zk-prefixer" = false;
      "random-note" = false;
      "outline" = true;
      "word-count" = true;
      "slides" = false;
      "audio-recorder" = false;
      "workspaces" = false;
      "file-recovery" = true;
      "publish" = false;
      "sync" = false;
      "bases" = false;
      "webviewer" = false;
    };
  };

  systemd.user.services.obsidian = {
    Unit.Description = "obsidian git sync";
    Service = {
      ExecStart = "${pkgs.writeShellScript "obsidian" ''
        while true; do
          cd /home/cat/.documents/obsidian || exit 1
          if [ ! -d .git ]; then
            exit 1
          fi
          git add .
          if ! git diff-index --quiet HEAD; then
            git commit -m "sync $(date +'%Y-%m-%d %H:%M:%S')"
            git pull --rebase origin main
            git push origin main
          fi
          sleep 60
        done
      ''}";
      Restart = "always";
    };
    Install.WantedBy = [ "default.target" ];
  };

home.file.".local/share/PrismLauncher/prismlauncher.cfg" = {
    text = pkgs.lib.generators.toINI {} {
      General = {
        ApplicationTheme = "dark";
        AutoCloseConsole = false;
        AutomaticJavaDownload = false;
        AutomaticJavaSwitch = true;
        CatFit = "fit";
        CatOpacity = 100;
        CentralModsDir = "mods";
        CloseAfterLaunch = false;
        ConfigVersion = "1.3";
        ConsoleFont = "DejaVu Sans Mono";
        ConsoleFontSize = 11;
        ConsoleMaxLines = 100000;
        ConsoleOverflowStop = true;
        DownloadsDir = "/home/cat/Downloads";
        DownloadsDirWatchRecursive = false;
        EnableFeralGamemode = false;
        EnableMangoHud = false;
        Env = "{}";
        FallbackMRBlockedMods = 2;
        IconTheme = "pe_colored";
        IconsDir = "icons";
        IgnoreJavaCompatibility = false;
        IgnoreJavaWizard = false;
        InstRenamingMode = "AskEverytime";
        InstSortMode = "Name";
        InstanceDir = "instances";
        JavaArchitecture = "64";
        JavaDir = "java";
        Language = "en_US";
        LastHostname = "box";
        LaunchMaximized = false;
        LowMemWarning = true;
        MaxMemAlloc = 6016;
        MinMemAlloc = 2048;
        MinecraftWinHeight = 480;
        MinecraftWinWidth = 854;
        ModDependenciesDisabled = false;
        ModMetadataDisabled = false;
        MoveModsFromDownloadsDir = false;
        NumberOfConcurrentDownloads = 6;
        NumberOfConcurrentTasks = 10;
        NumberOfManualRetries = 1;
        OnlineFixes = false;
        PastebinType = 3;
        PermGen = 128;
        ProxyAddr = "127.0.0.1";
        ProxyPort = 8080;
        ProxyType = "None";
        QuitAfterGameStop = false;
        RecordGameTime = true;
        RequestTimeout = 60;
        ShowConsole = false;
        ShowConsoleOnError = true;
        ShowGameTime = true;
        ShowGameTimeWithoutDays = false;
        ShowGlobalGameTime = true;
        ShowModIncompat = false;
        SkinsDir = "skins";
        SkipModpackUpdatePrompt = false;
        StatusBarVisible = true;
        TheCat = false;
        ToolbarsLocked = false;
        UseDiscreteGpu = false;
        UseNativeGLFW = false;
        UseNativeOpenAL = false;
        UseZink = false;
        UserAskedAboutAutomaticJavaDownload = true;
      };
    };
    force = true;
  };

  programs.home-manager.enable = true;
}
