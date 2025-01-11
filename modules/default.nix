{ packageOverlay }: # Module factory!
{ ... }:
{
  imports = [
    ./comfy.nix
  ];

  config = {
    nixpkgs.overlays = [ packageOverlay ];
  };
}
