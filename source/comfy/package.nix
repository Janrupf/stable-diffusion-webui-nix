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

  # Triton is a bit special and absolutely wants to run GCC at runtime...
  export TRITON_LIBCUDA_PATH="/run/opengl-driver/lib/libcuda.so"
  export LIBRARY_PATH="$LIBRARY_PATH:/run/opengl-driver/lib/"
  export PATH="''${PATH}:${pkgs.lib.makeBinPath [pkgs.gcc]}"

  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/run/opengl-driver/lib:/run/opengl-driver-32/lib:${pkgs.lib.makeLibraryPath [python]}"

  cd ${webuiPkgs.source}
  exec ${python}/bin/python ${webuiPkgs.source}/main.py "''${prog_args[@]}"
''
