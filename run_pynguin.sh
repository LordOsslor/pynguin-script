#!/bin/bash

# ARGUMENTS:
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

if [[ $# -ge 3 ]]; then
    RUN_NAME=$3
else
    RUN_NAME=.
fi

if [[ $# -ge 4 ]]; then
    CONF_PATH=$4
else
    CONF_PATH=./config
fi

# GLOBALS:
SECONDS=0
DOCKER_EXE=podman
MAX_PARALLEL=$(($(nproc --all) - 1))
GID=$(ps -o '%r' $$ | sed "s/[^0-9\n]//g")

WORKDIR=./runs/$RUN_NAME/$CONTAINER_NAME/$SEARCH_TIME/

DONE_PATH=$WORKDIR/done.txt
ERROR_PATH=$WORKDIR/errors.txt
AGG_PATH=$WORKDIR/aggregated.csv

EXCLUDE_PATH=$CONF_PATH/exclude_modules.txt
MODULES_PATH=$CONF_PATH/modulenames.txt

# HELPER FUNCTIONS:
to_time_str() {
    echo $(TZ=UTC0 printf '%(%H:%M:%S)T' $(printf %.0f $1))
}

progress() {
    done=$(cat $DONE_PATH | wc -l)
    error=$(cat $ERROR_PATH | wc -l)
    exclude=$(cat $EXCLUDE_PATH | wc -l)

    sum=$(($done + $error))

    total=$(cat $MODULES_PATH | wc -l)
    real_total=$(($total - $exclude))

    rel=$(echo "$sum/$real_total*100" | bc -l)
    perc=$(printf %.2f $rel)

    elapsed=$SECONDS
    rate=$(echo $sum.0001/$elapsed | bc -l)
    eta=$(to_time_str $(echo "($real_total-$sum)/$rate" | bc -l))

    echo "[$(to_time_str $elapsed)] (T=$SEARCH_TIME): (done: $done + error: $error) => $sum / $real_total ($perc%; $(printf %.2f $rate) mod/s); ETA: $eta"
}

get_container_count() {
    podman ps --noheading | wc -l
}

get_child_count() {
    pgrep -c -P$$
}

container_name() {
    module=$1
    echo $SEARCH_TIME.$module
}

init() {
    mkdir -p $WORKDIR
    touch $DONE_PATH
    touch $ERROR_PATH
}

# MEAT:
run_module() {
    module=$1

    echo "Running module $module"
    timeout -k 10 2000 \
        $DOCKER_EXE run \
        --name $(container_name $module) \
        --replace \
        --cpus 1.0 \
        --mount type=bind,source=$WORKDIR/$module/,target=/bind/ \
        $CONTAINER_NAME \
        $module \
        $SEARCH_TIME

    status=$?

    echo "Container finished with exit code $status"

    if [ $status -eq 0 ]; then
        echo "Module $module successfully completed; Marking as done"
        echo $module >>$DONE_PATH
    elif [ $status -ge 124 ]; then
        echo "Module $module timed out; Killing container and marking as error"
        $DOCKER_EXE kill $(container_name $module)
        echo $module >>$ERROR_PATH
    else
        echo "ERROR while running module $module: Exit code=$status; Marking as error"
        echo "$module (Timeout)" >>$ERROR_PATH
    fi

}

run() {
    while IFS= read -r module; do
        progress

        while (("$(get_container_count)" >= "$MAX_PARALLEL")); do
            sleep 1
            progress
        done

        if grep -q $module $EXCLUDE_PATH; then
            echo "Skipping module $module as it is excluded"
        elif grep -q $module $DONE_PATH; then
            echo "Skipping module $module as it has already been marked as done"
        elif grep -q $module $ERROR_PATH; then
            echo "Skipping module $module as it has already benn marked as erroneous"
        else
            echo "Starting execution of module $module..."

            mkdir -p $WORKDIR/$module/
            run_module $module &>$WORKDIR/$module/log.txt &

        fi
    done <$MODULES_PATH
}

post_run() {
    while (("$(pgrep -c -g $GID)" > 1)); do
        progress
        sleep 1
    done

    progress $SEARCH_TIME

    # Combine stats
    cat $WORKDIR/*/statistics.csv | awk '!seen[$0]++' >$AGG_PATH
}

# MAIN:

init
run

# Allow program to exit and signal that it's done but it can still do some cleanup after everything:
post_run &

echo "All modules have been started; exiting main script"
