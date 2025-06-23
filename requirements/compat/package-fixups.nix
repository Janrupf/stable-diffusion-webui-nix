# The python wheels that are downloaded will usually not run
# on Nix because of linker issues/missing dependencies
#
# For these packages we need to apply special steps - this is done
# in form of an overlay to the python packages
{
  pkgs,
  python,
  pythonPkgs,
  lib,
}:
final: prev:
let
  hipblaslt = pkgs.callPackage ./hipblaslt {
    inherit python;
    inherit pythonPkgs;
  };

  # Add dependencies to a package
  withExtraDependencies =
    pkg: extraDeps:
    pkg.overridePythonAttrs (prev: {
      dependencies = prev.dependencies ++ extraDeps;
    });

  # Add zlib to a package
  withZlib = pkg: withExtraDependencies pkg [ pkgs.zlib ];

  # Hook for removing all compiled bytecode
  pythonRemoveBytecodeHook = pythonPkgs.callPackage (
    { makePythonHook }:
    makePythonHook {
      name = "python-remove-bytecode-hook";
      propagatedBuildInputs = [ ];
    } ./python-remove-bytecode-hook.sh
  ) { };

  # Hook for copying libraries to lib output
  pythonPropagateLibHook = pythonPkgs.callPackage (
    { makePythonHook }:
    makePythonHook {
      name = "python-propagate-lib-hook";
      propagatedBuildInputs = [ ];
      substitutions = {
        pythonSitePackages = python.sitePackages;
      };
    } ./python-propagate-lib-hook.sh
  ) { };

  # Remove all bytecode from the package
  removePythonBytecode =
    pkg:
    pkg.overridePythonAttrs (prev: {
      nativeBuildInputs = prev.nativeBuildInputs ++ [ pythonRemoveBytecodeHook ];
    });

  # Make sure the package has a lib output
  propagateLib =
    pkg:
    pkg.overrideAttrs (prev: {
      outputs = (prev.outputs or [ ]) ++ [ "lib" ];
      nativeBuildInputs = prev.nativeBuildInputs ++ [ pythonPropagateLibHook ];
    });

in
with pkgs;
rec {
  inherit hipblaslt;

  # Numpy needs zlib and also needs to define coreIncludeDir so that scipy
  # can consume it
  numpy = prev.numpy.overridePythonAttrs (prevPyAttrs: {
    dependencies = prevPyAttrs.dependencies ++ [ zlib ];
    passthru = (prevPyAttrs.passthru or { }) // {
      # Needed for nixpkgs scipy to build
      coreIncludeDir = "${final.numpy}/${python.sitePackages}/numpy/core/include";
    };
  });

  # A bunch of packages require zlib
  llvmlite = withZlib prev.llvmlite;
  tokenizers = withZlib prev.tokenizers;
  pillow = withZlib prev.pillow;
  av = withZlib prev.av;
  triton = withZlib (
    prev.triton.overridePythonAttrs (prev: {
      # https://github.com/NixOS/nixpkgs/issues/96654
      dontStrip = 1;
    })
  );

  # Random other dependencies
  opencv-python = withExtraDependencies prev.opencv-python [
    libGL
    glib

    xorg.libxcb
    xorg.libICE
    xorg.libSM
  ];

  # Cuda stuff
  torch = propagateLib (
    prev.torch.overridePythonAttrs (prev: {
      # Will be added by pkgs.autoAddDriverRunpath
      autoPatchelfIgnoreMissingDeps = [ "libcuda.so.1" ];
      nativeBuildInputs = (prev.nativeBuildInputs or [ ]) ++ [ pkgs.autoAddDriverRunpath ];

      # TODO: This is ROCm only!
      # dependencies = (prev.dependencies or []) ++ [ hipblaslt ];
    })
  );

  torchaudio = propagateLib (
    prev.torchaudio.overridePythonAttrs (prev: {
      dependencies = [
        pkgs.ffmpeg_6
        pkgs.sox
        torch
      ];

      # Torchaudio automatically selects between ffmpeg 6, 5 and 4 -
      # we provide 6, so ignore the missing ffmpeg 4 and 5
      autoPatchelfIgnoreMissingDeps = [
        # ffmpeg 5
        "libavutil.so.57"
        "libavcodec.so.59"
        "libavformat.so.59"
        "libavfilter.so.8"
        "libavutil.so.57"
        "libavdevice.so.59"

        # ffmpeg 4
        "libavutil.so.56"
        "libavcodec.so.58"
        "libavformat.so.58"
        "libavfilter.so.7"
        "libavutil.so.56"
        "libavdevice.so.58"
      ];
    })
  );

  bitsandbytes = (
    prev.bitsandbytes.overridePythonAttrs (prev: {
      # Available at runtime if, and only if, CUDA is loaded -
      # but also only required if its loaded either way, so we
      # ignore these dependencies
      autoPatchelfIgnoreMissingDeps = [
        "libcudart.so.11.0"
        "libcublas.so.11"
        "libcusparse.so.11"
        "libcublasLt.so.11"
      ];
    })
  );

  numba = withExtraDependencies prev.numba [ tbb_2021 ];

  filterpy = prev.filterpy.overridePythonAttrs (prev: {
    # Fails for some reason
    doCheck = false;
  });

  jsonmerge = prev.jsonmerge.overridePythonAttrs (prev: {
    # No idea either, 2 tests fail
    doCheck = false;
  });

  # Bytecode removal (thanks NVIDIA for shipping libraries with overlapping bytecode..)
  nvidia-nvjitlink-cu12 = propagateLib (removePythonBytecode prev.nvidia-nvjitlink-cu12);
  nvidia-cusparse-cu12 = propagateLib (removePythonBytecode prev.nvidia-cusparse-cu12);
  nvidia-cusparselt-cu12 = propagateLib (removePythonBytecode prev.nvidia-cusparselt-cu12);
  nvidia-cusolver-cu12 = propagateLib (removePythonBytecode prev.nvidia-cusolver-cu12);
  nvidia-cudnn-cu12 = propagateLib (removePythonBytecode (withZlib prev.nvidia-cudnn-cu12));
  nvidia-cuda-cupti-cu12 = propagateLib (removePythonBytecode prev.nvidia-cuda-cupti-cu12);
  nvidia-cublas-cu12 = propagateLib (removePythonBytecode prev.nvidia-cublas-cu12);
  nvidia-cuda-nvrtc-cu12 = propagateLib (removePythonBytecode prev.nvidia-cuda-nvrtc-cu12);
  nvidia-cuda-runtime-cu12 = propagateLib (removePythonBytecode prev.nvidia-cuda-runtime-cu12);
  nvidia-curand-cu12 = propagateLib (removePythonBytecode prev.nvidia-curand-cu12);
  nvidia-cufft-cu12 = propagateLib (removePythonBytecode prev.nvidia-cufft-cu12);
  nvidia-nccl-cu12 = propagateLib (removePythonBytecode prev.nvidia-nccl-cu12);
  nvidia-nvtx-cu12 = propagateLib (removePythonBytecode prev.nvidia-nvtx-cu12);
  nvidia-cufile-cu12 = propagateLib (
    withExtraDependencies (removePythonBytecode prev.nvidia-cufile-cu12) [
      pkgs.rdma-core
    ]
  );

  # ROCm specific stuff
  pytorch-triton-rocm = withExtraDependencies prev.pytorch-triton-rocm [
    pkgs.zlib
    pkgs.zstd
  ];

  # Extra packages
  webui-python-raw = python;
  webui-python-env = python.withPackages (_: final.allRequirements);
}
