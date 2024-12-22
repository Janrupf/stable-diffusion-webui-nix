{ pkgs
, stable-diffusion-webui-git
, python-flexseal

# Extra configuration
, preferNixBuiltinPythonPackages ? true
}:
let
  # Bootstrap setuptools using the nix provided python installations
  bootstrapPython = pkgs.python310;

  # When preferring the python packages that ship with the Nix installation
  # of python, we can simply re-use the python packages as is.
  #
  # However, if there is a collision/incompatibility, we can build a new python installation
  # using the existing one and then override the packages as required.
  python = if preferNixBuiltinPythonPackages
    then bootstrapPython
    else bootstrapPython.override {
      # Build the new packages using the existing python installation
      packageOverrides = prev: final: (pythonPkgs.callPackage ./raw.nix {
        pkgs = prev;
      }).overrides;
    };
  pythonPkgs = python.pkgs;

  # Some packages need fixups
  requirementsOverlay = import ./compat/package-fixups.nix {
    inherit pkgs;
    inherit python;
    inherit pythonPkgs;
    inherit stable-diffusion-webui-git;
  };

  # The helper which can import flexsealed data
  loadInstructions = pythonPkgs.callPackage ./install/load-instructions.nix { pkgs = pythonPkgs; };

  finalPackages = (loadInstructions ./install/install-instructions.json).packages.overrideScope requirementsOverlay;
in
  finalPackages
