{ pkgs, ... }: {
  services.espanso = {
    enable = true;
    package = pkgs.espanso-wayland;
    matches = {
      base = {
        matches = [
          {
            trigger = ":date";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "date +%Y-%m-%d";
                };
              }
            ];
          }
          {
            trigger = ":github";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show github";
                };
              }
            ];
          }
          {
            trigger = ":codeberg";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show codeberg";
                };
              }
            ];
          }
          {
            trigger = ":reddit";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show reddit";
                };
              }
            ];
          }
          {
            trigger = ":discord";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show discord";
                };
              }
            ];
          }
          {
            trigger = ":icloud";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show icloud";
                };
              }
            ];
          }
          {
            trigger = ":hytale";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show hytale";
                };
              }
            ];
          }
          {
            trigger = ":skrime";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show skrime";
                };
              }
            ];
          }
        ];
      };
    };
  };
}
