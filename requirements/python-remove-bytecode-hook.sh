# Setup hook for removing bytecode from the entire package
echo "Sourcing python-remove-bytecode-hook.sh"

# We have packages (guess from whoom... yep, NVIDIA!) which have conflicting
# bytecode. This hooks helps us get rid of all bytecode.

pythonRemoveBytecodePhase () {
    # Only works with python 3, we don't have python 2 in this
    # project
    find "$out" -type f -name "*.pyc" -delete
}

preDistPhases+=" pythonRemoveBytecodePhase"
