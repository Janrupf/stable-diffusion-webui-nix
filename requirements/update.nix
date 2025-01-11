# Development script to generate a new list of stable diffusion requirements
# This is only needed when updating the flake, you don't need to install
# this when just using stable-diffusion.
{ pkgs
, lib
, python-flexseal

# Extra parameters
, webuiPkgs
}:
let
  # Use the raw python with a few custom packages
  basic-python = webuiPkgs.python.withPackages (pyPkgs: [
    pyPkgs.pip
    pyPkgs.virtualenv
    pyPkgs.wheel
  ]);

  # Transform the Nix objects into arguments that can be passed to pip
  requirementToPip = requirement:
    if requirement ? spec then
      if (lib.strings.hasPrefix "https://" requirement.spec) || (lib.strings.hasPrefix "http://" requirement.spec)
        then requirement.spec
      else let
        op = requirement.op or "==";
      in "${requirement.name}${op}${requirement.spec}"
    else
      requirement.name;

  additionalPipArgs = lib.strings.escapeShellArgs (
    (map requirementToPip (webuiPkgs.additionalRequirements or [])) ++
    webuiPkgs.additionalPipArgs
  );
in
pkgs.writeShellScriptBin "stable-diffusion-webui-update-requirements" ''
  set -e

  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <install-instructions.json>" >&2
    exit 1
  fi

  output="$(realpath "$1")"

  echo "Stable diffusion repository is at ${webuiPkgs.source}"

  temporary_dir="$(mktemp -d)"
  cd "$temporary_dir"

  download_dir="$temporary_dir/downloads"
  cache_dir="$temporary_dir/cache"
  env_dir="$temporary_dir/venv"
  requirement_files=("${webuiPkgs.source}/${webuiPkgs.requirementsFileName}")

  echo "Creating virtual environment in $env_dir"
  ${basic-python}/bin/python -m venv "$env_dir"
  
  source "$env_dir/bin/activate"

  echo "Temporarily installing wheel..."
  python -m pip install wheel

  echo "Installing dependencies..."

  declare -a pip_requirement_files

  for f in $requirement_files; do
    echo "  Adding requirement file $f"
    pip_requirement_files+=("-r" "$f")
  done

  for package_name in "''${!additional_requirements[@]}"; do
    pip_spec="$(to_pip_spec "$package_name")"
    echo "  Adding additional requirement $pip_spec to pip"
    pip_requirements_extra+=("$pip_spec")
  done

  # Install everything with one pip install invocation - this ensures the dependency resolver
  # works correctly
  python -m pip install \
    --dry-run \
    --ignore-installed \
    --report install-report.json \
    "''${pip_requirement_files[@]}" \
    --cache-dir "$cache_dir" \
    ${additionalPipArgs}

  echo "Removing wheel.."
  python -m pip uninstall -y wheel

  deactivate

  echo "Sealing environment from install report"

  ${python-flexseal}/bin/python-flexseal -p install-report.json -o "$output"

  echo "Written json to $output"
  rm -rf "$temporary_dir"
''
