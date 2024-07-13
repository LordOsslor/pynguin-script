#!/bin/bash

usage() { 
    echo "Usage:$0 <command>"
    echo
    echo "Available commands:"
    echo "  install - download and install required components"
    echo "  reset   - reset folder structure and delete everything"
    echo "  fix-dbg - fix weird debug printing by pynguin"
    echo "  run     - run pynguin on all modules"
    echo "  yolo    - all of the above"
}

reset() {
    rm -r .venv downloaded extracted pynguin-prison modulenames.txt done.txt
}

fix_debug() {
    grep -rl "logging.getLogger(__name__)" \
        ".venv/lib/python3.10/site-packages/pynguin" | xargs sed -io \
        's/^\(\s*\)\(..*\) = \(logging.getLogger(__name__)\)/\1\2 = \3\n\1\2.setLevel(logging.INFO)/'
}

install() {
    python3.10 -m venv .venv
    source .venv/bin/activate

    python -m pip install pynguin wheel
    python -m pip install -r requirements.txt

    python -m pip download --no-deps -r requirements.txt -d downloaded

    for f in ./downloaded/*
    do
        unzip $f -x "*[0-9].[0-9]*" -fo -d ./extracted/
    done

    python iter_modules.py ./extracted/ 1 > ./modulenames.txt

    echo "Setup done"
}

run_module() {
    if grep -q $module done.txt; then
        echo "Skipping module $module as it has already been marked as done"
    else
        echo "Running module $module..."
        pynguin --population 50                             \
            --initial-config.number-of-tests-per-target 10  \
            --initial_config.number_of_mutations 1          \
            --focused-config.number-of-tests-per-target 1   \
            --focused-config.number-of-mutations 10         \
            --crossover-rate 0.75                           \
            --tournament_size 5                             \
            --maximum-slicing-time 600                      \
            --maximum_coverage 100                          \
            --project-path ../extracted/                    \
            --output-path ../output/${module}               \
            --module-name ${module}
        if [ $? -eq 0 ]; then
            echo "Module $module successfully completed; Marking as done"
            echo $module >> done.txt
        else
            echo "ERROR while running Module $module!"
        fi
    fi
}



run() {
    source .venv/bin/activate

    mkdir -p logging
    mkdir -p pynguin-prison

    cd pynguin-prison

    while IFS= read -r module
    do
        run_module $module | tee -ap "../logging/${module}.log"
    done < "../modulenames.txt"
}

case "$1" in
    "install")
        echo "Installing..."
        install
        ;;
    "reset")
        echo "Resetting..."
        reset
        ;;
    "fix-dbg")
        echo "Fixing Debug printing..."
        fix_debug
        ;;
    "run")
        echo "Running pynguin..."
        reset
        ;;
    "yolo")
        echo "DOING EVERYTHING"
        reset
        install
        fix_debug
        run
        ;;
    *)
        usage
        ;;
esac

