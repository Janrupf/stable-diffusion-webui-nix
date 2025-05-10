{ pkgs
, lib
, python-flexseal

# Extra configuration
, webuiPkgs
, preferNixBuiltinPythonPackages ? true
}:
let
  # When preferring the python packages that ship with the Nix installation
  # of python, we can simply re-use the python packages as is.
  #
  # However, if there is a collision/incompatibility, we can build a new python installation
  # using the existing one and then override the packages as required.
  python = if preferNixBuiltinPythonPackages
    then webuiPkgs.python
    else webuiPkgs.python.override {
      # Build the new packages using the existing python installation
      packageOverrides = prev: final: (pythonPkgs.callPackage ./compat/package-fixups.nix {
        pkgs = prev;
      }).overrides;
    };
  pythonPkgs = python.pkgs;

  # Some packages need fixups
  requirementsOverlay = import ./compat/package-fixups.nix {
    inherit pkgs;
    inherit python;
    inherit pythonPkgs;
    inherit lib;
  };

  # The helper which can import flexsealed data
  loadInstructions = pythonPkgs.callPackage ./install/load-instructions.nix { pkgs = pythonPkgs; };

  requirementPkgs = (loadInstructions webuiPkgs.installInstructions).packages.overrideScope requirementsOverlay;
in {
  # Package requirements for the given source packages
  inherit requirementPkgs;

  # Helper for updating the install instructions
  update-helper = pythonPkgs.callPackage ./update.nix {
    inherit webuiPkgs;
    inherit python-flexseal;
  };
}
