#!/bin/bash

# ARGUMENTS:
if [[ $# -ge 1 ]]; then
    SEARCH_TIME=$1
else
    SEARCH_TIME=600
fi

if [[ $# -ge 2 ]]; then
    IMAGE_NAME=$2
else
    IMAGE_NAME=pynguin
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
PID=$$
GID=$(ps -o '%r' $$ | sed "s/[^0-9\n]//g")

WORKDIR=./runs/$RUN_NAME/$IMAGE_NAME/$SEARCH_TIME

DONE_PATH=$WORKDIR/done.txt
ERROR_PATH=$WORKDIR/errors.txt
AGG_PATH=$WORKDIR/aggregated.csv
LOG_PATH=$WORKDIR/log.txt

EXCLUDE_PATH=$CONF_PATH/exclude_modules.txt
MODULES_PATH=$CONF_PATH/modulenames.txt

# HELPER FUNCTIONS:
to_time_str() {
    echo $(TZ=UTC0 printf '%(%H:%M:%S)T' $(printf %.0f $1))
}

prefix() {
    printf "[%s] [N=%s; I=%+11s; T=%03d]" $(to_time_str $elapsed) $RUN_NAME $IMAGE_NAME $SEARCH_TIME
}

progress() {
    done=$(cat $DONE_PATH | wc -l)
    error=$(cat $ERROR_PATH | wc -l)
    exclude=$(cat $EXCLUDE_PATH | wc -l)

    sum=$(($done + $error))

    total=$(cat $MODULES_PATH | wc -l)
    real_total=$(($total - $exclude))

    rel=$(echo "$sum/$real_total*100" | bc -l)

    elapsed=$SECONDS
    rate=$(echo \($sum+0.00001\)/\($elapsed +0.00001\) | bc -l)
    eta=$(to_time_str $(echo "($real_total-$sum)/$rate" | bc -l))

    printf "%s Progress: %3d / %3d (%6.2f%%; %6.2f mod/s; D=%3d; E=%3d); (%2d / %2d); ETA: %s\n" \
        "$(prefix)" \
        $sum \
        $real_total \
        $rel \
        $rate \
        $done \
        $error \
        $(get_process_count) \
        $(get_container_count) \
        $eta

    if (($sum >= $real_total)); then
        true
    else
        false
    fi
}

get_container_count() {
    podman ps --noheading | wc -l
}

get_process_count() {
    pgrep -c -g $GID
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

    echo "$(prefix) Running module $module"
    timeout -k 10 3600 \
        $DOCKER_EXE run \
        --name $(container_name $module) \
        --replace \
        --cpus 1.0 \
        --mount type=bind,source=$WORKDIR/$module/,target=/bind/ \
        $IMAGE_NAME \
        $module \
        $SEARCH_TIME

    status=$?

    echo "$(prefix) Container finished with exit code $status"

    if [ $status -eq 0 ]; then
        echo "$(prefix) Module $module successfully completed; Marking as done"
        echo $module >>$DONE_PATH
    elif [ $status -ge 124 ]; then
        echo "$(prefix) Module $module timed out ($status); Killing container and marking as error"
        $DOCKER_EXE kill $(container_name $module)
        echo "$module (Timeout!)" >>$ERROR_PATH
    else
        echo "$(prefix) ERROR while running module $module: Exit code=$status; Marking as error"
        echo "$module ($status)" >>$ERROR_PATH
    fi

}

run() {
    while IFS= read -r module; do
        while (("$(get_container_count)" >= "$MAX_PARALLEL")); do
            sleep 1
        done

        if grep -q $module $EXCLUDE_PATH; then
            echo "$(prefix) Skipping module $module as it is excluded"
        elif grep -q $module $DONE_PATH; then
            echo "$(prefix) Skipping module $module as it has already been marked as done"
        elif grep -q $module $ERROR_PATH; then
            echo "$(prefix) Skipping module $module as it has already benn marked as erroneous"
        else
            echo "$(prefix) Starting execution of module $module..."

            mkdir -p $WORKDIR/$module/
            run_module $module &>$WORKDIR/$module/log.txt &
        fi
    done <$MODULES_PATH
}

post_run() {
    while ! progress; do
        sleep 1
    done

    # Combine stats
    cat $WORKDIR/*/statistics.csv | awk '!seen[$0] {print} {++seen[$0]}' >$AGG_PATH
}

# MAIN:

init

# Allow program to exit and signal that it's done but it can still do some cleanup after everything:
post_run | tee -ap $LOG_PATH &

run | tee -ap $LOG_PATH

echo "$(prefix) All containers launched"
