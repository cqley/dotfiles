{ config, pkgs, ... }:

{
  home.packages = [ pkgs.prismlauncher ];

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
        IconTheme = "OSX";
        IconsDir = "icons";
        IgnoreJavaCompatibility = false;
        IgnoreJavaWizard = false;
        InstRenamingMode = "AskEverytime";
        InstSortMode = "Name";
        InstanceDir = "instances";
        JavaArchitecture = "64";
        JavaDir = "java";
        JavaPath = "/nix/store/55mw2ly3dxh5008li72rx6ilc75hgvr0-openjdk-8u502-b01/bin/java";
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
}
