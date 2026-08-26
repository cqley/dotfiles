{ pkgs, ... }: {
  services.espanso = {
    enable = true;
    package = pkgs.espanso-wayland;
    matches = {
      base = {
        matches = [
          {
            trigger = ":e1";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show e1";
                };
              }
            ];
          }
          {
            trigger = ":e2";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show e2";
                };
              }
            ];
          }
          {
            trigger = ":e3";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show e3";
                };
              }
            ];
          }
          {
            trigger = ":e4";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show e4";
                };
              }
            ];
          }
          {
            trigger = ":e5";
            replace = "{{output}}";
            vars = [
              {
                name = "output";
                type = "shell";
                params = {
                  cmd = "PATH=$PATH:/run/current-system/sw/bin pass show e5";
                };
              }
            ];
          }
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
