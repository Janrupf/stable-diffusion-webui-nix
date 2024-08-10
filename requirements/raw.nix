# Automatically parse all the requirements from frozen-requirements.txt
{ lib
, newScope
, pkgs
}:
let
  # Read the locked data
  requirementsData = builtins.fromJSON (builtins.readFile ./requirements.json);

  # Convert a package name to a Pypi name
  toPypiName = name:
  let
    strings = lib.strings;
  in
    strings.stringAsChars (x: if x == "-" then "_" else x) (strings.toLower name);

  # Override setuptools if required
  setuptools-override =
  let
    setuptoolsData = lib.lists.findFirst (el: el.name == "setuptools") null requirementsData;
  in
    if setuptoolsData == null
      then pkgs.setuptools
      else pkgs.callPackage makePythonPackage {
        requirementData = setuptoolsData;
        selfPkgs = pkgs; # Can't reference own packages
      };

  # Called with callPackaged makePythonPackage { inherit requirementData; };
  makePythonPackage = 
  { buildPythonPackage
  , pkgs
  , selfPkgs
  , fetchurl
  , fetchzip
  
  # Hooks
  , autoPatchelfHook

    # Dependencies
  , setuptools
  , pip

    # Extra data
  , requirementData
  }: buildPythonPackage {
    pname = requirementData.name;
    version = requirementData.version;

    # Some packages are not wheels and have to be built, detect that here
    format = if requirementData.is-wheel then "wheel" else null;

    # Use fetchurl for wheels since they are auto extracted by nix,
    # for everything else extract the source
    src = (if requirementData.is-wheel then fetchurl else fetchzip) {
      url = requirementData.url;
      hash = requirementData.hash;
    };

    # Supply setuptools and pip for everything that is NOT a wheel
    build-system = if requirementData.is-wheel then [] else [
      setuptools
      pip
    ];

    nativeBuildInputs = [
      # Patch ELF binaries afterwards, they WILL be wrong for wheels
      autoPatchelfHook
    ];

    # Add the dependencies from the packages set
    dependencies = map (dep: 
      # Handle setuptools and pip special
      if dep == "setuptools"
        then setuptools
      else if dep == "pip"
        then pip
      else
        selfPkgs.${toPypiName dep}
    ) requirementData.dependencies;
  };

  # Convert the requirementsData to a key-value set that can be passed to
  # builtins.listToAttrs
  mappedPackages = pkgs: (map (requirementData: {
    name = toPypiName requirementData.name;
    value = pkgs.callPackage makePythonPackage { inherit requirementData; selfPkgs = pkgs; };
  }) requirementsData) ++ [{
    name = "allRequirements";
    value = map (requirementData: pkgs.${toPypiName requirementData.name}) requirementsData;
  }];

  packages = lib.makeScope newScope (self: builtins.listToAttrs (mappedPackages self));
in {
  inherit packages;
  overrides = {
    setuptools = setuptools-override;
  };
}
