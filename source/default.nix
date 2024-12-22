# A listing of stable diffusion packages that are to
# be made available
{ pkgs,
...
}:
let
  forge = pkgs.callPackage ./forge.nix {};
in
{
  forge = {
    cuda = {
      source = forge;
      python = pkgs.python310;

      additionalRequirements = forge.additionalRequirements ++ [
        # Acceleration on CUDA
        { name = "xformers"; spec = "0.0.27"; }
      ];
    };
  };
}