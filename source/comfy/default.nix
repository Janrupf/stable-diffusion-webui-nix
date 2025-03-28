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
      rev = "d0f3752e332ad9b2d8ee6f9c4317868aa685a62e";
      hash = "sha256-KP/ICZ0aMt7ViRD2L9dsvx9eLmaW7COYLrqhcurTZSc=";
    };

    patches = [ ./0001-Use-XDG-data-home-as-additional-base-path.patch ];

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
      { name = "diffusers"; op = ">="; spec = "0.31.0"; }
      { name = "accelerate"; op = ">="; spec = "1.2.1"; }
      { name = "transformers"; op = "=="; spec = "4.47.1"; }
      { name = "jax"; op = ">="; spec = "0.4.28"; }
      { name = "huggingface_hub"; }
      { name = "einops"; }
      { name = "peft"; }
      { name = "opencv-python"; }
      { name = "imageio-ffmpeg"; }
      { name = "bitsandbytes"; }
      { name = "matplotlib"; }
      { name = "mss"; }
      { name = "color-matcher"; }
    ];

    installInstructions = ./install-instructions-cuda.json;

    requirementsFileName = "requirements.txt";

    inherit createPackage;
  };
}
