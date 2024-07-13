#!/bin/bash

if [ -z ${PY_PATH+x} ]; then
    PY_PATH="python3.10"
fi


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
    rm -r .venv downloaded extracted pynguin-prison modulenames.txt
    if [ "$1" = "--full" ]; then
        echo "Also removing all output files and directories"
        rm -r logging output done.txt errors.txt
    fi
}

fix_debug() {
    grep -rl "logging.getLogger(__name__)" \
        ".venv/lib/python3.10/site-packages/pynguin" | xargs sed -io \
        's/^\(\s*\)\(..*\) = \(logging.getLogger(__name__)\)/\1\2 = \3\n\1\2.setLevel(logging.INFO)/'
}

install() {
    $PY_PATH -m venv .venv
    source .venv/bin/activate

    $PY_PATH -m pip install pynguin wheel
    $PY_PATH -m pip install -r requirements.txt

    $PY_PATH -m pip download --no-deps -r requirements.txt -d downloaded

    for f in ./downloaded/*
    do
        unzip $f -x "*[0-9].[0-9]*" -fo -d ./extracted/
    done

    $PY_PATH iter_modules.py ./extracted/ 1 > ./modulenames.txt

    touch done.txt
    touch errors.txt

    echo "Setup done"
}

run_module() {
    if grep -q $module ../done.txt; then
        echo "Skipping module $module as it has already been marked as done"
    elif grep -q $module ../errors.txt; then
      echo "Skipping module $module as it has already benn marked as erroneous"
    else
        echo "Running module $module..."
        pynguin --no-rich                                   \
            --population 50                                 \
            --initial-config.number-of-tests-per-target 10  \
            --initial_config.number_of_mutations 1          \
            --focused-config.number-of-tests-per-target 1   \
            --focused-config.number-of-mutations 10         \
            --crossover-rate 0.75                           \
            --tournament_size 5                             \
            --maximum-search-time 600                       \
            --maximum_coverage 100                          \
            --project-path ../extracted/                    \
            --output-path ../output/${module}               \
            --module-name ${module} | tee -ap "../logging/${module}.log"

        if [ $? -eq 0 ]; then
            echo "Module $module successfully completed; Marking as done"
            echo $module >> ../done.txt
        else
            echo "ERROR while running Module $module!; Marking as error"
            echo $module >> ../errors.txt
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
        run_module $module
    done < "../modulenames.txt"
}

case "$1" in
    "install")
        echo "Installing..."
        install
        ;;
    "reset")
        echo "Resetting..."
        reset $2
        ;;
    "fix-dbg")
        echo "Fixing Debug printing..."
        fix_debug
        ;;
    "run")
        echo "Running pynguin..."
        run
        ;;
    "yolo")
        echo "DOING EVERYTHING"
        reset $2
        install
        fix_debug
        PYNGUIN_DANGER_AWARE=1 run
        ;;
    *)
        usage
        ;;
esac

