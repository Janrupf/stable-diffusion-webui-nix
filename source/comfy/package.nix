{ pkgs

# Extra parameters
, webuiPkgs
, requirements
}:
let
  python = requirements.requirementPkgs.webui-python-env;
in
pkgs.writeShellScriptBin "comfyui" ''
  prog_args=("$@")

  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/run/opengl-driver/lib:/run/opengl-driver-32/lib:${pkgs.lib.makeLibraryPath [python]}"

  cd ${webuiPkgs.source}
  exec ${python}/bin/python ${webuiPkgs.source}/main.py "''${prog_args[@]}"
''
