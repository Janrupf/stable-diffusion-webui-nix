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

Then add the default module to your flake outputs:

```nix
{
  modules =
  [
    inputs.stable-diffusion-webui-nix.nixosModules.default
    ./configuration.nix
  ];
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
    dataPermissions = "0700" # presmissions for the dataDir directory
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
[nix-community](https://app.cachix.org/cache/nix-community) Cachix as a
substituter to your Nix configuration. See the
[NixOS Wiki](https://nixos.wiki/wiki/CUDA) for more information.

## Developing this flake/updating packages to a new version

For purposes of development, the package overlay can be added directly to nixpkgs via:

```nix
{
  nixpkgs.overlays = [ stable-diffusion-webui-nix.overlays.default ];
}
```

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

The Nix packages provided by this flake have fixed dependencies and don't allow installing additional Python packages or extensions through the web interface. If you need this functionality, you can use the FHS (Filesystem Hierarchy Standard) environment instead.

### Using the FHS Environment

The FHS environment provides a standard Linux environment with Python and CUDA, where you can manually install WebUI software andextensions:

1. **Add the FHS package to your system:**
   ```nix
   environment.systemPackages = [
     pkgs.stable-diffusion-webui.fhs.cuda
   ];

2. Enter the FHS environment: In a shell run `stable-diffusion-fhs-cuda`
3. Inside the FHS environment, manually install your preferred WebUI:
  - Follow the upstream installation instructions for AUTOMATIC1111, Forge, or ComfyUI
  - Use pip or the WebUI's built-in package managers to install extensions
  - Set up Python virtual environments as needed

Important Limitations

- No pre-installed software: The FHS environment only provides the base system (Python, CUDA, libraries) - you must install the WebUIsoftware yourself
- Manual management: You're responsible for updates, dependency conflicts, and troubleshooting
- No reproducibility: Unlike the Nix packages, your FHS setup won't be reproducible across systems
  
