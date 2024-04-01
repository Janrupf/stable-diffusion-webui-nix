{ pkgs
, python

# Extra parameters
, stable-diffusion-webui-git
, stable-diffusion-requirements
}:
let
  pythonEnv = python.withPackages (_: stable-diffusion-requirements.allRequirements);
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
    echo "Automatically overriden data directory to '$dataDirOverride'"
    prog_args+=("--data-dir" "$dataDirOverride")
  fi

  # exec ${pythonEnv}/bin/python
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/run/opengl-driver/lib:/run/opengl-driver-32/lib"

  cd ${stable-diffusion-webui-git}
  exec ${pythonEnv}/bin/python ${stable-diffusion-webui-git}/webui.py "''${prog_args[@]}"
''
