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
                  cmd = "cat e1";
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
                  cmd = "cat e2";
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
                  cmd = "cat e3";
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
                  cmd = "cat e4";
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
                  cmd = "cat e5";
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
                  cmd = "cat github";
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
                  cmd = "cat codeberg";
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
                  cmd = "cat reddit";
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
                  cmd = "cat discord";
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
                  cmd = "cat icloud";
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
                  cmd = "cat hytale";
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
                  cmd = "cat skrime";
                };
              }
            ];
          }
        ];
      };
    };
  };
}
