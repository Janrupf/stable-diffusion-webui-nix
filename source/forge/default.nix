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

  rocm = mkWebuiDistrib {
    source = raw;
    python = pkgs.python310;
    additionalRequirements = raw.additionalRequirements ++ [
      { name = "torch"; spec = "https://download.pytorch.org/whl/nightly/rocm6.2/torch-2.6.0.dev20241122%2Brocm6.2-cp310-cp310-linux_x86_64.whl"; }
      { name = "torchvision"; spec = "https://download.pytorch.org/whl/nightly/rocm6.2/torchvision-0.20.0.dev20241206%2Brocm6.2-cp310-cp310-linux_x86_64.whl"; }
      { name = "torchaudio"; spec = "https://download.pytorch.org/whl/nightly/rocm6.2/torchaudio-2.5.0.dev20241206%2Brocm6.2-cp310-cp310-linux_x86_64.whl"; }
    ];
    additionalPipArgs = ["--extra-index-url" "https://download.pytorch.org/whl/nightly/rocm6.2/"];

    installInstructions = ./install-instructions-rocm.json;
  };
}
