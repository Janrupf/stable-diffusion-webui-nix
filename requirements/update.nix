# Development script to generate a new list of stable diffusion requirements
# This is only needed when updating the flake, you don't need to install
# this when just using stable-diffusion.
{ pkgs
, lib
, stable-diffusion-webui-git
, stable-diffusion-webui-python-raw
, jq
, gnugrep
, findutils
, nix
, coreutils-full
, gawk
}:
let
  # Use the raw python with a few custom packages
  basic-python = stable-diffusion-webui-python-raw.withPackages (pyPkgs: [
    pyPkgs.pip
    pyPkgs.virtualenv
    pyPkgs.wheel
  ]);
in
pkgs.writeShellScriptBin "stable-diffusion-webui-update-requirements" ''
  set -e

  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <requirements.json>" >&2
    exit 1
  fi

  output="$(realpath "$1")"

  echo "Stable diffusion repository is at ${stable-diffusion-webui-git}"

  temporary_dir="$(mktemp -d)"
  cd "$temporary_dir"

  download_dir="$temporary_dir/downloads"
  cache_dir="$temporary_dir/cache"
  env_dir="$temporary_dir/venv"
  requirement_files=("${stable-diffusion-webui-git}/requirements_versions.txt")
  additional_requirements_file="${stable-diffusion-webui-git}/additional-requirements.json"

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

  function capture_pip_download_urls() {
    python -m pip install \
      -vvv \
      --progress-bar off \
      "$@" \
      --cache-dir "$cache_dir" |
        ${gnugrep}/bin/grep --line-buffered "GET /packages" |
        ${coreutils-full}/bin/tee /dev/stderr |
        ${gawk}/bin/awk '{print $1$3}'
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

  # Install all wheels with one pip install invocation - this ensures the dependency resolver
  # works correctly
  capture_pip_download_urls "''${pip_requirement_files[@]}" "''${pip_requirements_extra[@]}" > downloads.txt

  echo "Pip generated $(wc -l < downloads.txt) download URLs"

  echo "Removing wheel.."
  python -m pip uninstall -y wheel

  echo "Freezing environment via pip list"
  python -m pip list --format json > requirements.json

  packages_with_version="$(${jq}/bin/jq -r '.[] | (.name + " " + .version)' requirements.json)"
  echo "Locking the following packages:"
  echo "$packages_with_version"

  final_json="[]"

  # Iterate over all packages and find the associated wheel URL
  while IFS= read -r p; do
    # Split the package into its name and version
    IFS=' ' read -r -a p_array <<< "$p"
    package_name="''${p_array[0]}"
    package_version="''${p_array[1]}"

    pypi_download_name="''${package_name//-/_}"

    echo "Processing $package_name $package_version"

    # Skip pip and setuptools
    if [[ "$package_name" == "pip" ]] || [[ "$package_name" == "setuptools" ]] || [[ "$package_name" == "wheel" ]]; then
      continue
    fi

    download_url="''${additional_requirements[$package_name]}"
    is_wheel=false

    if [[ -z "$download_url" ]] || ! is_direct_download "$download_url"; then
      # Construct regex of form name-version.*\.whl$
      search_regex="''${pypi_download_name}-''${package_version}.*\\.whl\$"

      echo "  Looking up download URL using $search_regex"
      download_url="$(${gnugrep}/bin/grep -i "$search_regex" downloads.txt || true)"

      is_wheel=true

      if [[ -z "$download_url" ]]; then
        is_wheel=false
        echo "  Download URL not found, retrying as tar.gz"

        # Construct regex of form name-version.*\.tar.gz$
        search_regex="''${package_name}-''${package_version}.*\\.tar.gz\$"
        download_url="$(${gnugrep}/bin/grep -i "$search_regex" downloads.txt || true)"

        if [[ -z "$download_url" ]]; then
          echo "  Download URL not found, retrying as zip"
          # Construct regex of form name-version.*\.zip$
          search_regex="''${package_name}-''${package_version}.*\\.zip\$"
          download_url="$(${gnugrep}/bin/grep -i "$search_regex" downloads.txt)"
        fi
      fi
    fi

    echo "Download URL for $package_name version $package_version is $download_url"

    # Get the hash
    if [[ "$is_wheel" == "true" ]]; then
      # Don't unpack wheels, nix will do so later automatically
      raw_hash="$(${nix}/bin/nix-prefetch-url --type sha256 "$download_url")"
    else
      raw_hash="$(${nix}/bin/nix-prefetch-url --unpack --type sha256 "$download_url")"
    fi
    
    hash="$(${nix}/bin/nix hash to-sri --type sha256 "$raw_hash")"

    # Find the dependencies
    dependencies_line="$(python -m pip show "$package_name" | grep "^Requires: ")"
    dependencies_str="''${dependencies_line#Requires:}"
    dependencies_str_no_whitespace="''${dependencies_str// /}"
    dependencies_json="$(${jq}/bin/jq -Rc 'split(",")' <<< "$dependencies_str_no_whitespace")"
    echo "$dependencies_json"

    # Append the JSON array
    json_template='. += [{ "name": $name, "version": $version, "url": $url, "hash": $hash, "is-wheel": $is_wheel, "dependencies": $dependencies }]'
    final_json="$(
      ${jq}/bin/jq \
      --arg name "$package_name" \
      --arg version "$package_version" \
      --arg url "$download_url" \
      --arg hash "$hash" \
      --argjson is_wheel "$is_wheel" \
      --argjson dependencies "$dependencies_json" \
      "$json_template" <<< "$final_json")"
  done <<< "$packages_with_version"

  deactivate
  echo "$final_json" > "$output"
  echo "Written json to $output"
  rm -rf "$temporary_dir"
''