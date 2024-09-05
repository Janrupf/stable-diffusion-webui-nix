{ pkgs
, stable-diffusion-webui-git
}:
let
  # Bootstrap setuptools using the nix provided python installations
  bootstrapPython = pkgs.python310;
  bootstrapPkgs = bootstrapPython.pkgs;
  bootstrapOverrides = (pythonPkgs.callPackage ./raw.nix { pkgs = bootstrapPkgs; }).overrides;

  # Python with setuptools overwritten
  python = bootstrapPython.override {
    packageOverrides = prev: final: {
      setuptools = bootstrapOverrides.setuptools;
    };
  };
  pythonPkgs = python.pkgs;

  # Some packages need fixups
  requirementsOverlay = final: prev: 
  let
    # Add dependencies to a package
    withExtraDependencies = pkg: extraDeps: pkg.overridePythonAttrs (prev: {
      dependencies = prev.dependencies ++ extraDeps;
    });

    # Add zlib to a package
    withZlib = pkg: withExtraDependencies pkg [ pkgs.zlib ]; 

    # Hook for removing all compiled bytecode
    pythonRemoveBytecodeHook = pythonPkgs.callPackage ({ makePythonHook }:
      makePythonHook {
        name = "python-remove-bytecode-hook";
        propagatedBuildInputs = [];
      } ./python-remove-bytecode-hook.sh
    ) {};

    # Hook for copying libraries to lib output
    pythonPropagateLibHook = pythonPkgs.callPackage ({ makePythonHook }:
      makePythonHook {
        name = "python-propagate-lib-hook";
        propagatedBuildInputs = [];
        substitutions = {
          pythonSitePackages = python.sitePackages;
        };
      } ./python-propagate-lib-hook.sh
    ) {};

    # Remove all bytecode from the package
    removePythonBytecode = pkg: pkg.overridePythonAttrs (prev: {
      nativeBuildInputs = prev.nativeBuildInputs ++ [ pythonRemoveBytecodeHook ];
    });

    # Make sure the package has a lib output
    propagateLib = pkg: pkg.overrideAttrs (prev: {
      outputs = (prev.outputs or []) ++ ["lib"];
      nativeBuildInputs = prev.nativeBuildInputs ++ [ pythonPropagateLibHook ];
    });

  in
  with pkgs;
  {
    # Replace scipy with the one from nixpkgs
    #
    # Not doing so results in a corrupted scipy_openblas library:
    #  ImportError: libscipy_openblas-c128ec02.so: ELF load command address/offset not page-aligned
    #
    # Probably a case of https://github.com/NixOS/patchelf/issues/492
    scipy = pythonPkgs.scipy.override (scipyPrev: {
      numpy = final.numpy;
    });

    # A bunch of packages require zlib
    llvmlite = withZlib prev.llvmlite;
    tokenizers = withZlib prev.tokenizers;
    numpy = withZlib prev.numpy;
    pillow = withZlib prev.pillow;
    triton = withZlib (prev.triton.overridePythonAttrs (prev: {
      # https://github.com/NixOS/nixpkgs/issues/96654
      dontStrip = 1;
    }));

    # Random other dependencies
    opencv_python = withExtraDependencies prev.opencv_python [
      libGL
      glib

      xorg.libxcb
      xorg.libICE
      xorg.libSM
    ];

    # Cuda stuff
    torch = propagateLib (prev.torch.overridePythonAttrs (prev: {
      # Will be added by pkgs.autoAddDriverRunpath
      autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];
      nativeBuildInputs = (prev.nativeBuildInputs or []) ++ [ pkgs.autoAddDriverRunpath ];
    }));

    numba = withExtraDependencies prev.numba [ tbb_2021_11 ];

    filterpy = prev.filterpy.overridePythonAttrs (prev: {
      # Fails for some reason
      doCheck = false;
    });

    jsonmerge = prev.jsonmerge.overridePythonAttrs (prev: {
      # No idea either, 2 tests fail
      doCheck = false;
    });

    # Bytecode removal (thanks NVIDIA for shipping libraries with overlapping bytecode..)
    nvidia_nvjitlink_cu12 = propagateLib (removePythonBytecode prev.nvidia_nvjitlink_cu12);
    nvidia_cusparse_cu12 = propagateLib (removePythonBytecode prev.nvidia_cusparse_cu12);
    nvidia_cusolver_cu12 = propagateLib (removePythonBytecode prev.nvidia_cusolver_cu12);
    nvidia_cudnn_cu12 = propagateLib (removePythonBytecode (withZlib prev.nvidia_cudnn_cu12));
    nvidia_cuda_cupti_cu12 = propagateLib (removePythonBytecode prev.nvidia_cuda_cupti_cu12);
    nvidia_cublas_cu12 = propagateLib (removePythonBytecode prev.nvidia_cublas_cu12);
    nvidia_cuda_nvrtc_cu12 = propagateLib (removePythonBytecode prev.nvidia_cuda_nvrtc_cu12);
    nvidia_cuda_runtime_cu12 = propagateLib (removePythonBytecode prev.nvidia_cuda_runtime_cu12);
    nvidia_curand_cu12 = propagateLib (removePythonBytecode prev.nvidia_curand_cu12);
    nvidia_cufft_cu12 = propagateLib (removePythonBytecode prev.nvidia_cufft_cu12);
    nvidia_nccl_cu12 = propagateLib (removePythonBytecode prev.nvidia_nccl_cu12);
    nvidia_nvtx_cu12 = propagateLib (removePythonBytecode prev.nvidia_nvtx_cu12);

    # Extra packages
    inherit stable-diffusion-webui-git;
    stable-diffusion-webui-python-raw = python;
    stable-diffusion-webui-python = python.withPackages (_: final.allRequirements);

    stable-diffusion-webui-update-requirements = pythonPkgs.callPackage ./update.nix {
      # Inherit the final versions of the dependencies
      inherit (final) stable-diffusion-webui-git;
      inherit (final) stable-diffusion-webui-python-raw;
    };
  };

  finalPackages = (pythonPkgs.callPackage ./raw.nix { pkgs = pythonPkgs; }).packages.overrideScope requirementsOverlay;
in
  finalPackages
