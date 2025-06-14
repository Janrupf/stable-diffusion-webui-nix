# Stable diffusion Web UI's for Nix

###### Fully reproducible flake packaging stable diffusion python UI's

## Using this flake

Add the following to your inputs:

```nix
stable-diffusion-webui-nix = {
  url = "github:Janrupf/stable-diffusion-webui-nix/main";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then add the overlay to your system configuration:

```nix
{
  nixpkgs.overlays = [ stable-diffusion-webui-nix.overlays.default ];
}
```

Finally add the package you want to your system packages:

```nix
environment.systemPackages = [
  pkgs.stable-diffusion-webui.forge.cuda # For lllyasviel's fork of AUTOMATIC1111 WebUI
  pkgs.stable-diffusion-webui.comfy.cuda # For ComfyUI
];
```

Afterwards you should have the command `stable-diffusion-webui` or `comfy-ui`
available which launches the server.

### Running as service

This flake exposes the module `services.sd-webui-forge` that runs the forge webui as a systemd service.

The available options are:

```nix
services.sd-webui-forge = {
    enable = true;
    user = "sd-webui-forge"; # The user that runs the service.
    group = "sd-webui-forge"; # The group that runs the service.
    dataDir = "/var/lib/sd-webui-forge"; # The directory that the webUI stores models and images in.
    package = pkgs.stable-diffusion-webui.forge.cuda; # The package (cuda/rocm) that you want to use.
    listen = true; # Whether to listen on all interfaces or only localhost.
    port = 7860; # The port for the webUI.
    extraArgs = "--cuda-malloc"; # Extra CLI args for the server.
};
```

### Quirks

#### Where is my WebUI (for Forge) data?

Data is by default stored in `$HOME/.local/share/stable-diffusion-webui`, this can be
overwritten by using the `--data-dir /another/path` argument when starting the Web UI.

#### Where is my ComfyUI data?

Data is by default stored in `$HOME/.local/share/comfy-ui`, this can be ovewritten
by using `--base-directory /another/path` argument.

#### This takes ages to compile...

Running Stable Diffusion models requires CUDA and thus depends on packages which are
by default not available in the NixOS cache. Add the
[cuda-maintainers](https://app.cachix.org/cache/cuda-maintainers) Cachix as a
substituter to your Nix configuration. See the
[NixOS Wiki](https://nixos.wiki/wiki/CUDA) for more information.

## Developing this flake/updating packages to a new version

Due to the nature of python package management, this flake is quite complex.

1. update the commit hashes in `source/package` (file depends on which package you want to change).
2. run `nix run .#package.update-helper source/package/install-instructions.json`
   (for example `.#comfy.cuda.update-helper source/comfy/install-instructions-cuda.json`)
   to update the requirements metadata
3. try running the package using `nix run .#package` (for example `nix run .#comfy.cuda`) and test everything

NOTE: If you get an error that you have run out of disk space during step 2, your
`/tmp` is too small. Either increase the tmpfs size or run the command with `TMPDIR`
set to a different directory. Generally, if step 2 fails the temporary directory
may not be deleted, you are free to `rm -rf` it, but it can be useful for inspecting
why it failed.

## What if I want to install extensions using the UI's?

This flake provides a FHS (`nix run .#fhs.cuda`) and `pkgs.stable-diffusion-webui.fhs.cuda`
(as command `stable-diffusion-fhs-cuda`) which can be used to provide an FHS which (hopefully...) has the
packages installed required to run with upstream python environments.

**NOTE:** The FHS is unmanaged - you don't get ComfyUI/StableDiffusionWebUI/Something pre-installed! It only
provides you a standard Linux environment, in which you can follow the upstream instructions to install
your UI of choice.

Due to being unmanaged, you should be able to install custom python packages just fine (provided you have
set up your python venv!).
