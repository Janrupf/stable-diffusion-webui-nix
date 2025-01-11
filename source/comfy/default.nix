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
      # Required for some extensions, common enough to be included
      # here
      { name = "diffusers"; op = ">="; spec = "0.31.0"; }
      { name = "huggingface_hub"; }
      { name = "einops"; }
      { name = "peft"; }
      { name = "opencv-python"; }
      { name = "imageio-ffmpeg"; }
    ];

    installInstructions = ./install-instructions-cuda.json;

    requirementsFileName = "requirements.txt";

    inherit createPackage;
  };
}
