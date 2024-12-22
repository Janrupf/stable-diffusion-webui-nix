{ pkgs
, mkWebuiDistrib
, ...
}:
let
  raw = pkgs.callPackage ./raw.nix {};
in
{
  cuda = mkWebuiDistrib {
    source = raw;
    python = pkgs.python310;

    additionalRequirements = raw.additionalRequirements ++ [
      # Acceleration on CUDA
      { name = "xformers"; spec = "0.0.27"; }
    ];

    installInstructions = ./install-instructions-cuda.json;
  };
}
