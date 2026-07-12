{
  programs.yazi = {
    enable = true;
    
    settings = {
      manager = {
        layout = [ 1 4 3 ];
        sort_by = "alphabetical";
        sort_dir_first = true;
        linemode = "none";
        show_hidden = true;
        show_symlink = true;
      };
    };

    theme = {
      mgr = {
        border_symbol = " ";
      };
      indicator = {
        padding = { open = "█"; close = "█"; };
      };
      mode = {
        normal_main = { fg = "black"; bg = "blue"; bold = true; };
        normal_alt = { fg = "blue"; bg = "black"; };
        select_main = { fg = "black"; bg = "green"; bold = true; };
        select_alt = { fg = "green"; bg = "black"; };
        unset_main = { fg = "black"; bg = "yellow"; bold = true; };
        unset_alt = { fg = "yellow"; bg = "black"; };
      };
      status = {
        sep_left = { open = ""; close = ""; };
        sep_right = { open = ""; close = ""; };
      };
    };

    keymap = {
      manager = {
        prepend_keymap = [
          { on = [ "x" ]; run = "yank --cut"; }
          { on = [ "y" ]; run = "yank"; }
          { on = [ "p" ]; run = "paste"; }
          { on = [ "d" ]; run = "remove"; }
          { on = [ "r" ]; run = "rename"; }
          { on = [ "c" ]; run = "create"; }
        ];
      };
    };
  };
}
