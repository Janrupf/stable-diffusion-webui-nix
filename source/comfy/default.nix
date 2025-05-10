{ pkgs
, fetchFromGitHub
, mkWebuiDistrib
, stdenv
, ...
}:
let
  sourceDerivation = stdenv.mkDerivation {
    name = "ComfyUI";

    src = fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "02a1b01aad28470f06c8b4f95b90914413d3e4c8";
      hash = "sha256-nqYVrkkog4We6DmnV2Qb+xncHqpSnFGQnSQjZUBb33Y=";
    };

    patches = [];

    installPhase = ''
      cp -r . "$out"
    '';
  };

  createPackage = import ./package.nix;
in {
  cuda = mkWebuiDistrib {
    source = sourceDerivation;
    python = pkgs.python312;

    additionalRequirements = [
      # Required for most video extensions, common enough to be included
      # here
      { name = "diffusers"; op = ">="; spec = "0.32.0"; }
      { name = "accelerate"; op = ">="; spec = "1.2.1"; }
      { name = "transformers"; op = ">="; spec = "4.49.1"; }
      { name = "jax"; op = ">="; spec = "0.4.28"; }
      { name = "sentencepiece"; op = ">="; spec = "0.2.0"; }
      { name = "huggingface_hub"; }
      { name = "einops"; }
      { name = "peft"; }
      { name = "opencv-python"; }
      { name = "imageio-ffmpeg"; }
      { name = "bitsandbytes"; }
      { name = "matplotlib"; }
      { name = "mss"; }
      { name = "color-matcher"; }
      { name = "ftfy"; }
      { name = "protobuf"; }
      { name = "sageattention"; }
      { name = "timm"; }
    ];

    installInstructions = ./install-instructions-cuda.json;

    requirementsFileName = "requirements.txt";

    inherit createPackage;
  };
}
