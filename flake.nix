{
  description = "Flake for running upstream stable diffusion webui on Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system: 
  let
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        cudaSupport = true;
      };
    };
    python = pkgs.python310;
    pythonPkgs = python.pkgs;

    # Source repo
    stable-diffusion-webui-git = pkgs.callPackage ./source {};

    # Create a script which can be used to update the requirements
    stable-diffusion-webui-update-requirements = pkgs.callPackage ./requirements/update.nix {
      inherit stable-diffusion-webui-git;
      inherit python;
    };

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
    };

    # Import the requirements
    stable-diffusion-requirements = (pythonPkgs.callPackage ./requirements {}).overrideScope requirementsOverlay;

    stable-diffusion-webui = pythonPkgs.callPackage ./package.nix {
      inherit stable-diffusion-webui-git;
      inherit stable-diffusion-requirements;
    };
  in
  {
    inherit stable-diffusion-requirements;

    packages = {
      inherit stable-diffusion-webui;
      inherit stable-diffusion-webui-update-requirements;
    };
    
    devShells.default = pkgs.mkShell {
      packages = [
        stable-diffusion-webui-update-requirements
      ] ++ stable-diffusion-requirements.allRequirements;
    };
  });
}