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

Afterwards you should have the command `stable-diffusion-webui` or `comfyui`
available which launches the server.

### Quirks

#### Where is my WebUI (for Forge) data?

Data is by default stored in `$HOME/.local/share/stable-diffusion-webui`, this can be
overwritten by using the `--data-dir /another/path` argument when starting the Web UI.

#### Where is my ComfyUI data?

Data is by default stored in `$HOME/.local/share/comfy-ui`, this can be ovewritten
by using `--data-dir /another/path` argument or setting the `NIX_COMFYUI_BASE_PATH`
environment variable. The argument takes precedence over the environment variable.

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
