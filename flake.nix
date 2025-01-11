{
  description = "Flake for running upstream stable diffusion webui on Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    python-flexseal = {
      url = "github:Janrupf/python-flexseal";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { nixpkgs, flake-utils, python-flexseal, ... }:
  let
    localOverlay = import ./overlay.nix;

    pkgsForSystem = system: 
    let
      # TODO: This should be an overlay in python-flexseal
      python-flexseal-pkg = python-flexseal.packages.${system}.python-flexseal;
    in
    import nixpkgs {
      config = {
        allowUnfree = true;
        cudaSupport = true;
      };

      overlays = [
        (prev: final: { python-flexseal = python-flexseal-pkg; })
        localOverlay
      ];
      inherit system;
    };
  in
  flake-utils.lib.eachDefaultSystem (system: rec {
    # Make packages available
    legacyPackages = pkgsForSystem system;
    packages = legacyPackages.stable-diffusion-webui;

    # Make all the webui packages also available as apps
    apps = legacyPackages.lib.attrsets.mapAttrsRecursiveCond
      (as: !(as ? "type" && as.type == "derivation"))
      (_: drv: (
        flake-utils.lib.mkApp { inherit drv; } // {
          # Also expose the update helper
          update-helper = flake-utils.lib.mkApp { drv = drv.update-helper; }; 
        }
      ))
      packages;
  }) // rec {
    # Non system specific stuff
    overlays.default = (final: prev: {
      # For now we need to pollute with python-flexseal, not sure how to prevent this
      python-flexseal = python-flexseal.packages.${prev.stdenv.system}.python-flexseal;
    } // (localOverlay final prev));

    nixosModules.default = import ./modules { packageOverlay = overlays.default; };
  };
}