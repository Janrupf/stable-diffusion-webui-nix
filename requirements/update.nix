# Development script to generate a new list of stable diffusion requirements
# This is only needed when updating the flake, you don't need to install
# this when just using stable-diffusion.
{ pkgs
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
  requirement_files=("${webuiPkgs.source}/requirements_versions.txt")
  additional_requirements_file="${webuiPkgs.source}/additional-requirements.json"

  # Make an array of additional requirements
  declare -A additional_requirements
  while IFS="@" read -r key value; do
    echo "Adding additional requirement $key -> $value"
    additional_requirements[$key]="$value"
  done < <(${pkgs.jq}/bin/jq -r 'map("\(.name)@\(.spec)")|.[]' "$additional_requirements_file")

  echo "Creating virtual environment in $env_dir"
  ${basic-python}/bin/python -m venv "$env_dir"
  
  source "$env_dir/bin/activate"

  echo "Temporarily installing wheel..."
  python -m pip install wheel

  echo "Installing dependencies..."

  function is_direct_download() {
    if [[ "$1" =~ http(s):\/\/.* ]]; then
      return 0
    else
      return 1
    fi
  }

  function to_pip_spec() {
    local package_name="$1"
    local package_spec="''${additional_requirements[$package_name]}"

    if is_direct_download "$package_spec"; then
      echo -n "$package_spec"
    else
      echo -n "$package_name==$package_spec"
    fi
  }

  declare -a pip_requirement_files
  declare -a pip_requirements_extra

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
    "''${pip_requirements_extra[@]}" \
    --cache-dir "$cache_dir"

  echo "Removing wheel.."
  python -m pip uninstall -y wheel

  deactivate

  echo "Sealing environment from install report"

  ${python-flexseal}/bin/python-flexseal -p install-report.json -o "$output"

  echo "Written json to $output"
  rm -rf "$temporary_dir"
''
