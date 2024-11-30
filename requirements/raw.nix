# Automatically parse all the requirements from frozen-requirements.txt
{ lib
, newScope
, pkgs
, runCommandLocal
, unzip
, glibcLocalesUtf8
}:
let
  # Read the locked data
  installInstructions = builtins.fromJSON (builtins.readFile ./install-instructions.json);
  packagesToInstall = installInstructions.packages;

  # Extract an archive after downloading it
  #
  # We can't rely on fetchzip to do this for us, because the hashes we get from PyPi are
  # for the non-extracted archives.
  extractArchive = file: runCommandLocal "extract-python-archive" {
    input = file;
    nativeBuildInputs = [ unzip glibcLocalesUtf8 ];
  } ''
      # Derived from https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/fetchzip/default.nix

      unpackDir="$TMPDIR/unpack"
      mkdir "$unpackDir"
      cd "$unpackDir"

      unpackFile "$input"
      chmod -R +w "$unpackDir"

      fn=$(cd "$unpackDir" && ls -A)
      if [ -f "$unpackDir/$fn" ]; then
        mkdir $out
      fi
      mv "$unpackDir/$fn" "$out"

      chmod 755 "$out"
  '';

  # Override setuptools if required
  setuptools-override =
  let
    setuptoolsData = lib.lists.findFirst (el: el.name == "setuptools") null packagesToInstall;
  in
    if setuptoolsData == null
      then pkgs.setuptools
      else pkgs.callPackage makePythonPackage {
        packageData = setuptoolsData;
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
  , packageData
  }: buildPythonPackage {
    pname = packageData.name;
    version = packageData.version;

    # Some packages are not wheels and have to be built, detect that here
    format = if packageData.source.is_wheel then "wheel" else null;

    # Use fetchurl for wheels since they are auto extracted by nix,
    # for everything else extract the source
    src = (if packageData.source.is_wheel then lib.id else extractArchive) (fetchurl ({
      url = lib.elemAt packageData.source.urls 0;
    } // packageData.source.hashes));

    # Supply setuptools and pip for everything that is NOT a wheel
    build-system = if packageData.source.is_wheel then [] else [
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
        selfPkgs.${dep}
    ) packageData.dependencies;
  };

  # Convert the requirementsData to a key-value set that can be passed to
  # builtins.listToAttrs
  mappedPackages = pkgs: (map (packageData: {
    name = packageData.name;
    value = pkgs.callPackage makePythonPackage { inherit packageData; selfPkgs = pkgs; };
  }) packagesToInstall) ++ [{
    name = "allRequirements";
    value = map (packageData: pkgs.${packageData.name}) packagesToInstall;
  }];

  packages = lib.makeScope newScope (self: builtins.listToAttrs (mappedPackages self));
in {
  inherit packages;
  overrides = {
    setuptools = setuptools-override;
  };
}
