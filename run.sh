#!/bin/bash

if [[ $# -ge 1 ]]; then
  search_time=$1
else
  search_time=600
fi

SECONDS=0
DOCKER_EXE=podman
let "MAX_PARALLEL=$(nproc --all)-1"

run_module() {
  module=$1
  search_time=$2

  echo "Running module $module"
  timeout -k 10 2000 \
    $DOCKER_EXE run \
    --name $search_time.$module \
    --replace \
    --cpus 1.0 \
    --mount type=bind,source=./out/$search_time/$module/,target=/bind/ \
    pynguin \
    $module \
    $search_time

  status=$?

  echo "Container finished with exit code $status"

  if [ $status -eq 0 ]; then
    echo "Module $module successfully completed; Marking as done"
    echo $module >>./state/$search_time/done.txt
  elif [ $status -ge 124 ]; then
    echo "Module $module timed out; Killing container and marking as error"
    $DOCKER_EXE kill $search_time.$module
    echo $module >>./state/$search_time/errors.txt
  else
    echo "ERROR while running module $module: Exit code=$status; Marking as error"
    echo $module >>./state/$search_time/errors.txt
  fi

}

progress() {
  search_time=$1
  done=$(cat ./state/$search_time/done.txt | wc -l)
  error=$(cat ./state/$search_time/errors.txt | wc -l)

  sum=$(($done + $error))

  total=$(cat ./modulenames.txt | wc -l)

  rel=$(echo "$sum/$total*100" | bc -l)
  perc=$(printf %.2f $rel)

  elapsed=$SECONDS
  rate=$(echo $sum.0001/$elapsed | bc -l)
  eta=$(TZ=UTC0 printf '%(%H:%M:%S)T' $(printf %.0f $(echo "($total-$sum)/$rate" | bc -l)))

  echo "[$(TZ=UTC0 printf '%(%H:%M:%S)T' $elapsed)] (T=$search_time): (done: $done + error: $error) => $sum / $total ($perc%; $(printf %.2f $rate) mod/s); ETA: $eta"
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
      progress $search_time
      sleep 1
    done

    if grep -q $module ./state/$search_time/done.txt; then
      echo "Skipping module $module as it has already been marked as done"
    elif grep -q $module ./state/$search_time/errors.txt; then
      echo "Skipping module $module as it has already benn marked as erroneous"
    else

      echo "Starting execution of module $module..."

      mkdir -p out/$search_time/$module/
      run_module $module $search_time &>out/$search_time/$module/log.txt &

    fi
  done <"./modulenames.txt"
}

post_run() {
  while (("$(pgrep -c -g $1)" > 1)); do
    progress $search_time
    sleep 1
  done

  progress $search_time
  cat ./out/$search_time/*/statistics.csv | awk '!seen[$0]++' >out/$search_time/total_stats.csv
}

$DOCKER_EXE build -t pynguin .

mkdir -p ./out/$search_time/
mkdir -p ./state
mkdir -p ./state/$search_time
touch ./state/$search_time/done.txt
touch ./state/$search_time/errors.txt

run

gid=$(ps -o '%r' $$ | sed "s/[^0-9\n]//g")
# Allow program to exit and signal that it's done but it can still do some cleanup after everything
post_run $gid &

echo "All modules have been started; exiting main script"
