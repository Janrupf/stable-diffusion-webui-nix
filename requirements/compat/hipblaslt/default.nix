{ pkgs
, python
, pythonPkgs
, lib
, rocmPackages
, stdenv
, fetchFromGitHub
, ...
}:
let
  src = fetchFromGitHub {
    owner = "ROCm";
    repo = "hipBLASLt";
    rev = "rocm-6.0.2";
    hash = "sha256-ZXiq5e6C7MU0nTpill/jCsjt1y3vwdt2xrrqCA6cCtw=";
  };

  tensileLitePython = python.withPackages (ps: with ps; [
    pyyaml
    msgpack
    joblib
  ]);

  tensileLite = pythonPkgs.buildPythonPackage {
    name = "hiblaslt-tensilelite";
    version = "internal";

    src = "${src}/tensilelite";

    patches = [
      # ./always-debug-print.patch
      ./assembler-try-in-temporary-directory.patch
      ./fix-bad-attribute-access.patch
      ./use-clang++-from-env.patch
      ./make-static-files-writable.patch
    ];

    # This seems weird... however, the CMake scripts later invoke scripts
    # in this package directly, so we need to build with a python environment
    # where the packages already exist - this causes shebang patching to properly
    # work.
    propagatedBuildInputs = [
      tensileLitePython
    ];
  };

  tensileLiteEnv = python.withPackages (ps: [
    tensileLite
    ps.pyyaml
    ps.msgpack
    ps.joblib
  ]);

  # Fix up the targets that the library actually compiles with successfully
  #
  # Check the CMakeLists.txt and look for rocm_check_target_ids
  tensileSupportedROCmTargets = ["gfx90a:xnack+" "gfx90a:xnack-" "gfx940" "gfx941" "gfx942"];
  enabledROCmTargets = lib.lists.intersectLists tensileSupportedROCmTargets rocmPackages.clr.gpuTargets;
in
stdenv.mkDerivation {
  name = "hipblaslt";
  version = "6.0.2";

  inherit src;

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.perl
    pkgs.git

    rocmPackages.llvm.clang
    tensileLiteEnv
  ];

  buildInputs = [
    pkgs.msgpack
    rocmPackages.rocm-cmake
    rocmPackages.clr
    rocmPackages.hipblas
    rocmPackages.rocblas
  ];

  patches = [
    ./use-external-python-env.patch
  ];

  unpackPhase = ''
    runHook preUnpack

    unpackFile $src
    sourceRoot="source"

    # Make sources writeable so that the build doesn't fail
    chmod -R u+w -- "$sourceRoot"

    runHook postUnpack
  '';

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_C_COMPILER" "hipcc")
    (lib.cmakeFeature "CMAKE_CXX_COMPILER" "hipcc")
    (lib.cmakeFeature "AMDGPU_TARGETS" (lib.strings.concatStringsSep ";" enabledROCmTargets))
    (lib.cmakeFeature "VIRTUALENV_HOME_DIR" "${tensileLiteEnv}")
    (lib.cmakeFeature "VIRTUALENV_BIN_DIR" "${tensileLiteEnv}/bin")
    (lib.cmakeFeature "Tensile_TENSILE_ROOT" "${tensileLiteEnv}")
    (lib.cmakeFeature "Tensile_CODE_OBJECT_VERSION" "V3")
  ];

  passthru = {
    inherit tensileLiteEnv;
  };
}
