{
  flake.modules.homeManager.flywheel =
    { pkgs, ... }:
    let
      sources = import ./_sources.nix { inherit (pkgs) fetchFromGitHub; };
      riderLicense = import ../_rider-license.nix;

      # ntm shells out to tmux and to the agent CLIs (claude/codex/gemini) at
      # runtime. tmux is wrapped onto its PATH from nixpkgs; the agent CLIs
      # are deliberately left off the wrapper PATH so ntm resolves whichever
      # ones the user's own session already provides.
      ntm = pkgs.buildGoModule {
        pname = "ntm";
        inherit (sources.ntm) version src vendorHash;

        subPackages = [ "cmd/ntm" ];
        doCheck = false;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        postFixup = ''
          wrapProgram $out/bin/ntm --prefix PATH : ${pkgs.tmux}/bin
        '';

        # MIT with an OpenAI/Anthropic rider barring those vendors (and
        # anyone acting on their behalf) from any rights in the Software;
        # never lib.licenses.mit.
        meta = {
          mainProgram = "ntm";
          license = riderLicense // {
            url = "https://github.com/Dicklesworthstone/ntm/blob/v${sources.ntm.version}/LICENSE";
          };
        };
      };
    in
    {
      home.packages = [ ntm ];
    };
}
