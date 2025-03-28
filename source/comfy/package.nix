{ pkgs

# Extra parameters
, webuiPkgs
, requirements
}:
let
  python = requirements.requirementPkgs.webui-python-env;
in
pkgs.writeShellScriptBin "comfy-ui" ''
  prog_args=("$@")

  baseDirOverride="$HOME/.local/share/comfy-ui"

  for arg in "$@"; do
    if [[ "$arg" == "--base-directory" ]]; then
      baseDirOverride=""
      break
    fi
  done

  if [[ -n "$baseDirOverride" ]]; then
    echo "Automatically overwriting base directory to '$baseDirOverride'"

    prog_args+=("--base-directory" "$baseDirOverride")

    mkdir -p "$baseDirOverride"
    mkdir -p "$baseDirOverride/custom_nodes"
  fi

  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/run/opengl-driver/lib:/run/opengl-driver-32/lib:${pkgs.lib.makeLibraryPath [python]}"

  cd ${webuiPkgs.source}
  exec ${python}/bin/python ${webuiPkgs.source}/main.py "''${prog_args[@]}"
''
