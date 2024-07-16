#!/bin/bash

for ((RUN_COUNT = 1; ; RUN_COUNT++)); do
    for IMAGE in {pynguin-hmx,pynguin-sx}; do
        for SEARCH_TIME in {1,100,200,300,400,500,600}; do
            echo "Starting run: #$RUN_COUNT; I=$IMAGE; T=$SEARCH_TIME"

            ./run_pynguin.sh $SEARCH_TIME $IMAGE $RUN_COUNT

            echo "Next run will be started in 3s..."
            sleep 3
        done
    done
done
