# Setup hook for propagating libraries from a package to the lib output
echo "Sourcing python-propagate-lib-hook.sh"

pythonPropagateLibPhase () {
    mkdir -p "$lib"

    # Copy all .so files from "$out" to "$lib"
    echo "Site packages is: @pythonSitePackages@"
    for f in $(find "$out/@pythonSitePackages@" \( -name "*.so.*" -o -name "*.so" \) -not -name "_C.*.so" -type f); do
        origFile="$f"
        libOutFile="$lib/$(basename "$f")"

        echo "Moving lib $origFile ($(file "$origFile")) to $libOutFile"

        if [[ -h "$origFile" ]]; then
            # file is already a symlink, copy as-is
            # cp "$origFile" "$libOutFile"
            continue
        fi

        mv "$origFile" "$libOutFile"
        ln -s "$libOutFile" "$origFile"
        ln -s "$libOutFile" "$out/lib/$(basename "$f")"
    done
}

preFixupPhases+=" pythonPropagateLibPhase"
