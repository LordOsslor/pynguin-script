#!/bin/bash

if [[ $# -ge 1 ]]; then
    SEARCH_TIME=$1
else
    SEARCH_TIME=600
fi

if [[ $# -ge 2 ]]; then
    CONTAINER_NAME=$2
else
    CONTAINER_NAME=pynguin
fi

SECONDS=0
DOCKER_EXE=podman
let "MAX_PARALLEL=$(nproc --all)-1"

run_module() {
    module=$1

    echo "Running module $module"
    timeout -k 10 2000 \
        $DOCKER_EXE run \
        --name $SEARCH_TIME.$module \
        --replace \
        --cpus 1.0 \
        --mount type=bind,source=./out/$SEARCH_TIME/$module/,target=/bind/ \
        $CONTAINER_NAME \
        $module \
        $SEARCH_TIME

    status=$?

    echo "Container finished with exit code $status"

    if [ $status -eq 0 ]; then
        echo "Module $module successfully completed; Marking as done"
        echo $module >>./state/$SEARCH_TIME/done.txt
    elif [ $status -ge 124 ]; then
        echo "Module $module timed out; Killing container and marking as error"
        $DOCKER_EXE kill $SEARCH_TIME.$module
        echo $module >>./state/$SEARCH_TIME/errors.txt
    else
        echo "ERROR while running module $module: Exit code=$status; Marking as error"
        echo $module >>./state/$SEARCH_TIME/errors.txt
    fi

}

progress() {
    done=$(cat ./state/$SEARCH_TIME/done.txt | wc -l)
    error=$(cat ./state/$SEARCH_TIME/errors.txt | wc -l)
    exclude=$(cat ./exclude_modules.txt | wc -l)

    sum=$(($done + $error))

    total=$(cat ./modulenames.txt | wc -l)
    real_total=$(($total - $exclude))

    rel=$(echo "$sum/$real_total*100" | bc -l)
    perc=$(printf %.2f $rel)

    elapsed=$SECONDS
    rate=$(echo $sum.0001/$elapsed | bc -l)
    eta=$(TZ=UTC0 printf '%(%H:%M:%S)T' $(printf %.0f $(echo "($real_total-$sum)/$rate" | bc -l)))

    echo "[$(TZ=UTC0 printf '%(%H:%M:%S)T' $elapsed)] (T=$SEARCH_TIME): (done: $done + error: $error) => $sum / $real_total ($perc%; $(printf %.2f $rate) mod/s); ETA: $eta"
}

get_containers() {
    podman ps --noheading | wc -l
}

run() {
    while IFS= read -r module; do
        if (("$(get_containers)" >= "$MAX_PARALLEL")); then
            echo "Current container count:  $(get_containers); Our containers: $(pgrep -c -P$$); Waiting for threads to finish"
        fi
        while (("$(get_containers)" >= "$MAX_PARALLEL")); do
            progress
            sleep 1
        done

        if grep -q $module ./exclude_modules.txt; then
            echo "Skipping module $module as it is excluded"
        elif grep -q $module ./state/$SEARCH_TIME/done.txt; then
            echo "Skipping module $module as it has already been marked as done"
        elif grep -q $module ./state/$SEARCH_TIME/errors.txt; then
            echo "Skipping module $module as it has already benn marked as erroneous"
        else

            echo "Starting execution of module $module..."

            mkdir -p out/$SEARCH_TIME/$module/
            run_module $module &>out/$SEARCH_TIME/$module/log.txt &

        fi
    done <"./modulenames.txt"
}

post_run() {
    while (("$(pgrep -c -g $1)" > 1)); do
        progress
        sleep 1
    done

    progress $SEARCH_TIME
    cat ./out/$SEARCH_TIME/*/statistics.csv | awk '!seen[$0]++' >out/$SEARCH_TIME/total_stats.csv
}

mkdir -p ./out/$SEARCH_TIME/
mkdir -p ./state
mkdir -p ./state/$SEARCH_TIME
touch ./state/$SEARCH_TIME/done.txt
touch ./state/$SEARCH_TIME/errors.txt

run

gid=$(ps -o '%r' $$ | sed "s/[^0-9\n]//g")
# Allow program to exit and signal that it's done but it can still do some cleanup after everything
post_run $gid &

echo "All modules have been started; exiting main script"
