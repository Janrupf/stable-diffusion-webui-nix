{ packageOverlay }: # Module factory!
{ ... }:
{
  imports = [
    ./comfy.nix
    ./forge.nix
  ];

  config = {
    nixpkgs.overlays = [ packageOverlay ];
  };
}
