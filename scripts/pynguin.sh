#!/bin/bash

BIND_PATH="/bind/"

if [[ $# -ge 2 ]]; then
    search_time=$2
else
    search_time=600
fi

mkdir -p prison
cd prison

echo "(in container) Running module $1"

pynguin --no-rich \
    --population 50 \
    --initial-config.number-of-tests-per-target 10 \
    --initial_config.number_of_mutations 1 \
    --focused-config.number-of-tests-per-target 1 \
    --focused-config.number-of-mutations 10 \
    --crossover-rate 0.75 \
    --tournament_size 5 \
    --maximum-search-time ${2} \
    --maximum_coverage 100 \
    --project-path ../extracted/ \
    --output-path ../output \
    --seed 12345 \
    --module-name ${1}

status=$?

cp pynguin-report/* $BIND_PATH/
cp -r ../output/ $BIND_PATH/

exit $status
