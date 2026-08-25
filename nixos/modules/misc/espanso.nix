{ pkgs, ... }: {
  users.users.cat.extraGroups = [ "input" ];

  services.espanso = {
    enable = true;
    package = pkgs.espanso-wayland;
    configs = {
      default = {
        search_shortcut = "off";
        toggle_key = "off";
      };
    };
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
        ];
      };
    };
  };
}
