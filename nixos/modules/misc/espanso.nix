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
        ];
      };
    };
  };
}