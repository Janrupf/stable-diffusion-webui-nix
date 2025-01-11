{ pkgs

# Extra parameters
, webuiPkgs
, requirements
}:
let
  python = requirements.requirementPkgs.webui-python-env;
in
pkgs.writeShellScriptBin "comfy-ui" ''
  prog_args=()
  dataDirOverride=""

  for (( i=1; i <= "$#"; i++ ))
  do
    arg="''${!i}"
    echo "Handling arg $i: $arg"
    if [[ "$arg" == "--data-dir" ]]; then
      i=$(( $i + 1 ))
      dataDirOverride="''${!i}"
    else
      prog_args+=("$arg")
    fi
  done

  if [[ -n "$dataDirOverride" ]]; then
    export NIX_COMFYUI_BASE_PATH="$dataDirOverride"
  fi

  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/run/opengl-driver/lib:/run/opengl-driver-32/lib:${pkgs.lib.makeLibraryPath [python]}"

  cd ${webuiPkgs.source}
  exec ${python}/bin/python ${webuiPkgs.source}/main.py "''${prog_args[@]}"
''
