{
  flake.modules.homeManager.fish = {
    programs.fish = {
      enable = true;

      interactiveShellInit = ''
        set -g fish_greeting ""
      '';
    };
  };

  flake.modules.darwin.fish = {
    programs.fish.enable = true;
    programs.zsh = {
      interactiveShellInit = ''
        if [[ $(ps -o command= -p "$PPID" | awk '{print $1}') != 'fish' ]]
        then
          exec fish -l
        fi
      '';
    };
  };
}
