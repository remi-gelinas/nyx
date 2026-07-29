# Pinned source for ntm (Named Tmux Manager). Underscore prefix keeps this
# out of import-tree; imported directly by ntm.nix.
{ fetchFromGitHub }:
{
  ntm =
    let
      version = "1.20.0";
    in
    {
      inherit version;
      src = fetchFromGitHub {
        owner = "Dicklesworthstone";
        repo = "ntm";
        tag = "v${version}";
        hash = "sha256-3Vs9eHSAeTP0zbJO8l1o+0BQ514807D5xjs51Foe9HA=";
      };
      # No vendor/ committed upstream; fetched via vendorHash.
      vendorHash = "sha256-uGEcLzOAl5wQ4BVRlZwjln6JziIUbNulO1xfZOtpS/8=";
    };
}
