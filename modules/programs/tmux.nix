{
  flake.modules.homeManager.tmux = {
    programs.tmux = {
      enable = true;
      # Clicking into a teammate's pane requires mouse mode.
      mouse = true;
    };
  };
}
