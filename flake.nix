{
  description = "Flake for running upstream stable diffusion webui on Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
  let
    localOverlay = import ./overlay.nix;

    pkgsForSystem = system: import nixpkgs {
      config = {
        allowUnfree = true;
        cudaSupport = true;
      };

      overlays = [ localOverlay ];
      inherit system;
    };
  in
  flake-utils.lib.eachDefaultSystem (system: rec {
    # Make packages available
    legacyPackages = pkgsForSystem system;
    packages = flake-utils.lib.flattenTree {
      inherit (legacyPackages) stable-diffusion-webui stable-diffusion-webui-update-requirements;
    };
    defaultPackage = packages.stable-diffusion-webui;

    # For development
    apps.stable-diffusion-webui-update-requirements = flake-utils.lib.mkApp {
      drv = packages.stable-diffusion-webui-update-requirements;
    };

    devShells.default = legacyPackages.mkShell {
      packages = [
        # Add the python interpreter with all the requirements set up
        legacyPackages.stable-diffusion-webui-python

        # Tool for updating the requirements json
        legacyPackages.stable-diffusion-webui-update-requirements
      ];
    };

    # Final application
    apps.stable-diffusion-webui = flake-utils.lib.mkApp {
      drv = packages.stable-diffusion-webui;
    };
    apps.default = apps.stable-diffusion-webui;

    requirements = legacyPackages.stable-diffusion-requirements;
  }) // {
    # Non system specific stuff
    overlays.default = localOverlay;
  };
}