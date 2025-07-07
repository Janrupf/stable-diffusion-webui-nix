# The FHS is meant for unlocked and non-nix controlled instances of Comfy/StableDiffusionWebUI.
# It can probably also be used for other AI software.
#
# No diffusion packages are provided. Only the required base software (ie. CUDA) and a python
# interpreter are at your disposal inside the FHS.
#
# ComfyUI now provides it's own package management system, which naturally doesn't play very
# well with Nix (and ComfyUI custom_nodes never did either way).
{ pkgs
, ...
}:
{
  cuda = pkgs.buildFHSEnv {
    name = "stable-diffusion-fhs-cuda";

    targetPkgs = pkgs: (with pkgs; [
      (pkgs.python312.withPackages (pypi: [
        pypi.pip
        pypi.uv
      ]))

      zlib
      zstd

      libGL
      glib

      xorg.libxcb
      xorg.libICE
      xorg.libSM

      ffmpeg_6
      sox
      rdma-core
      stdenv.cc
    ]);

    runScript = "$SHELL";
  };
}
