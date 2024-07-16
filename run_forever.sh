#!/bin/bash

if [[ $# -ge 1 ]]; then
    START=$1
else
    START=1
fi

if [[ $# -ge 2 ]]; then
    TIMES=$2
else
    TIMES="1,100,200,300,400,500,600"
fi

IFS=',' read -ra TIMES_ARR <<<"$TIMES"

for ((RUN_COUNT = $START; ; RUN_COUNT++)); do
    for IMAGE in {pynguin-hmx,pynguin-sx}; do
        for SEARCH_TIME in ${TIMES_ARR[@]}; do
            echo "[LOOP] Starting run: #$RUN_COUNT; I=$IMAGE; T=$SEARCH_TIME"

            ./run_pynguin.sh $SEARCH_TIME $IMAGE $RUN_COUNT

            echo "[LOOP] Next run will be started in 3s..."
            sleep 3
        done
    done
done
