{ pkgs
, mkWebuiDistrib
, ...
}:
let
  raw = pkgs.callPackage ./raw.nix {};

  createPackage = import ./package.nix;
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

    inherit createPackage;
  };

  rocm = mkWebuiDistrib {
    source = raw;
    python = pkgs.python310;
    additionalRequirements = raw.additionalRequirements ++ [
      { name = "torch"; spec = "https://download.pytorch.org/whl/nightly/rocm6.0/torch-2.5.0.dev20240802%2Brocm6.0-cp310-cp310-linux_x86_64.whl"; }
      { name = "torchvision"; spec = "https://download.pytorch.org/whl/nightly/rocm6.0/torchvision-0.20.0.dev20240822%2Brocm6.0-cp310-cp310-linux_x86_64.whl"; }
    ];
    additionalPipArgs = ["--extra-index-url" "https://download.pytorch.org/whl/nightly/rocm6.2/"];

    installInstructions = ./install-instructions-rocm.json;

    createPackage = throw "ROCm is currently broken";
    # inherit createPackage; # Want to work on ROCm? Swap the line above with this
  };
}
