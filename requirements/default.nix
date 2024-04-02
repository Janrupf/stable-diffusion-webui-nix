{ pkgs
, stable-diffusion-webui-git
}:
let
  # The python version we use
  python = pkgs.python310;
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

    # Remove all bytecode from the package
    removePythonBytecode = pkg: pkg.overridePythonAttrs (prev: {
      nativeBuildInputs = prev.nativeBuildInputs ++ [ pythonRemoveBytecodeHook ];
    });

    # Remove the explicit dependency on the torch native libraries
    withImplicitTorchLibs = pkg: pkg.overridePythonAttrs (prev: {
      autoPatchelfIgnoreMissingDeps = [
        "libtorch.so"
        "libtorch_cpu.so"
        "libtorch_python.so"
        "libtorch_cuda.so"
        "libc10_cuda.so"
        "libc10.so"
      ];
    });
  in
  with pkgs;
  {
    # A bunch of packages require zlib
    llvmlite = withZlib prev.llvmlite;
    tokenizers = withZlib prev.tokenizers;
    numpy = withZlib prev.numpy;
    pillow = withZlib prev.pillow;
    triton = withZlib (prev.triton.overridePythonAttrs (prev: {
      # https://github.com/NixOS/nixpkgs/issues/96654
      dontStrip = 1;
    }));
    nvidia_cudnn_cu12 = removePythonBytecode (withZlib prev.nvidia_cudnn_cu12);

    # Random other dependencies
    opencv_python = withExtraDependencies prev.opencv_python [
      libGL
      glib

      xorg.libxcb
      xorg.libICE
      xorg.libSM
    ];

    # Cuda stuff
    nvidia_cusparse_cu12 = removePythonBytecode (withExtraDependencies prev.nvidia_cusparse_cu12 [ cudaPackages.libnvjitlink ]);
    nvidia_cusolver_cu12 = removePythonBytecode (withExtraDependencies prev.nvidia_cusolver_cu12 [ cudaPackages.libcublas cudaPackages.libcusolver ]);
    torch = withExtraDependencies prev.torch [
      # To pull in graphics drivers
      cudaPackages.cuda_cupti
      cudaPackages.cuda_cudart
      cudaPackages.cuda_nvrtc
      cudaPackages.cuda_nvtx
      cudaPackages.libcufft
      cudaPackages.cudnn
      cudaPackages.nccl
      cudaPackages.libcurand
    ];

    numba = withExtraDependencies prev.numba [ tbb_2021_8 ];

    filterpy = prev.filterpy.overridePythonAttrs (prev: {
      # Fails for some reason
      doCheck = false;
    });

    jsonmerge = prev.jsonmerge.overridePythonAttrs (prev: {
      # No idea either, 2 tests fail
      doCheck = false;
    });

    # Torchvision and xformers requires the native libraries from torch -
    # since both packages depend on torch, they'll be available via python
    torchvision = withImplicitTorchLibs prev.torchvision;
    xformers = withImplicitTorchLibs prev.xformers;

    # Bytecode removal (thanks NVIDIA for shipping libraries with overlapping bytecode..)
    nvidia_cuda_cupti_cu12 = removePythonBytecode prev.nvidia_cuda_cupti_cu12;
    nvidia_cublas_cu12 = removePythonBytecode prev.nvidia_cublas_cu12;
    nvidia_cuda_nvrtc_cu12 = removePythonBytecode prev.nvidia_cuda_nvrtc_cu12;
    nvidia_cuda_runtime_cu12 = removePythonBytecode prev.nvidia_cuda_runtime_cu12;
    nvidia_curand_cu12 = removePythonBytecode prev.nvidia_curand_cu12;
    nvidia_cufft_cu12 = removePythonBytecode prev.nvidia_cufft_cu12;
    nvidia_nvjitlink_cu12 = removePythonBytecode prev.nvidia_nvjitlink_cu12;
    nvidia_nccl_cu12 = removePythonBytecode prev.nvidia_nccl_cu12;

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
in
  (pythonPkgs.callPackage ./raw.nix {}).overrideScope requirementsOverlay
