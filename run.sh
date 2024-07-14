DOCKER_EXE=podman
let "MAX_PARALLEL=$(nproc --all)-2"

run_module() {
  module=$1
  echo "Running module $module"
  timeout -k 10 1500 \
    $DOCKER_EXE run \
    --name $module \
    --replace \
    --cpus 1.0 \
    --mount type=bind,source=./out/$module/,target=/bind/ \
    pynguin \
    $module

  status=$?

  echo "Container finished with exit code $status"

  if [ $status -eq 0 ]; then
    echo "Module $module successfully completed; Marking as done"
    echo $module >>./done.txt
  elif [ $status -ge 124 ]; then
    echo "Module $module timed out; Killing container and marking as error"
    $DOCKER_EXE kill $module
    echo $module >>./errors.txt
  else
    echo "ERROR while running module $module: Exit code=$status; Marking as error"
    echo $module >>./errors.txt
  fi

}

run() {
  while IFS= read -r module; do
    if (("$(pgrep -c -P$$)" >= "$MAX_PARALLEL")); then
      echo "Current thread count: $(pgrep -c -P$$); Waiting for threads to finish"
    fi
    while (("$(pgrep -c -P$$)" >= "$MAX_PARALLEL")); do
      sleep 1
    done

    if grep -q $module ./done.txt; then
      echo "Skipping module $module as it has already been marked as done"
    elif grep -q $module ./errors.txt; then
      echo "Skipping module $module as it has already benn marked as erroneous"
    else

      echo "Starting execution of module $module..."

      mkdir -p out/$module/
      run_module $module &>out/$module/log.txt &
    fi
  done <"./modulenames.txt"
}

$DOCKER_EXE build -t pynguin .

touch ./done.txt
touch ./errors.txt

run
