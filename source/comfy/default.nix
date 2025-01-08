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

    additionalRequirements = [];

    installInstructions = ./install-instructions-cuda.json;

    requirementsFileName = "requirements.txt";

    inherit createPackage;
  };
}
