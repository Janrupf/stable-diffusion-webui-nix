{ pkgs

# Extra parameters
, webuiPkgs
, requirements
}:
let
  python = requirements.requirementPkgs.webui-python-env;
in
pkgs.writeShellScriptBin "stable-diffusion-webui" ''
  prog_args=("$@")

  dataDirOverride="$HOME/.local/share/stable-diffusion-webui"

  for arg in "$@"; do
    if [[ "$arg" == "--data-dir" ]]; then
      dataDirOverride=""
      break
    fi
  done

  if [[ -n "$dataDirOverride" ]]; then
    echo "Automatically overwriting data directory to '$dataDirOverride'"

    # Work around issues with gradio not allowing to serve dotfiles
    tmp_dir="$(mktemp -d)"
    link_dir="$tmp_dir/stable-diffusion-webui"

    mkdir -p "$dataDirOverride"
    ln -sf "$dataDirOverride" "$link_dir"

    prog_args+=("--data-dir" "$link_dir")
  fi

  prog_args+=("--gradio-allowed-path" "${webuiPkgs.source}")

  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/run/opengl-driver/lib:/run/opengl-driver-32/lib:${pkgs.lib.makeLibraryPath [python]}"

  cd ${webuiPkgs.source}
  exec ${python}/bin/python ${webuiPkgs.source}/webui.py "''${prog_args[@]}"
''
