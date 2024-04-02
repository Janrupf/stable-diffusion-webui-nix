# Stable diffusion Web UI for Nix

###### Fully reproducible flake packaging the stable diffusion web ui

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

Finally add the package to your packages:

```nix
environment.systemPackages = [ pkgs.stable-diffusion-webui ];
```

Afterwards you should have the command `stable-diffusion-webui` 
available which launches the server.

### Quirks

#### Where is my WebUI data?

Data is by default stored in `$HOME/.local/share/stable-diffusion-webui`, this can be
overwritten by using the `--data-dir /another/path` argument when starting the Web UI.

#### This takes ages to compile...

Running Stable Diffusion models requires CUDA and thus depends on packages which are
by default not available in the NixOS cache. Add the 
[cuda-maintainers](https://app.cachix.org/cache/cuda-maintainers) Cachix as a 
substituter to your Nix configuration. See the 
[NixOS Wiki](https://nixos.wiki/wiki/CUDA) for more information.

## Developing this flake/updating to a new version

Due to the nature of python package management, this flake is quite complex.

1. update the Web UI commit hash in `source/default.nix` (and other sources).
2. run `nix run .#stable-diffusion-webui-update-requirements requirements/requirements.json`
to update the requirements metadata
3. try running the Web UI using `nix run .` and test everything

NOTE: If you get an error that you have run out of disk space during step 2, your 
`/tmp` is too small. Either increase the tmpfs size or run the command with `TMPDIR` 
set to a different directory. Generally, if step 2 fails the temporary directory 
may not be deleted, you are free to `rm -rf` it, but it can be useful for inspecting
why it failed.

## Working on the Web UI itself

This flake supports the usual mechanism of opening a development shell with a proper
python environment set up already. Run `nix develop` to open this shell.

Please note that this shell does not come with a virtual environment. If you need to
update requirements, do so as described above.
