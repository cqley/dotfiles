{ config, pkgs, ... }:

{
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
}
