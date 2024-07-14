run_module() {
  module=$1
  mkdir -p out/$module/

  if grep -q $module ./done.txt; then
    echo "Skipping module $module as it has already been marked as done"
  elif grep -q $module ./errors.txt; then
    echo "Skipping module $module as it has already benn marked as erroneous"
  else
    echo "Running module $module"
    timeout -k 2 1500 podman run --name $module --mount type=bind,source=./out/$module/,target=/bind/ pynguin $module

    status=$?

    echo "Container finished with exit code $status"

    if [ $status -eq 0 ]; then
      echo "Module $module successfully completed; Marking as done"
      echo $module >>./done.txt
    elif [ $status -ge 124 ]; then
      echo "Module $module timed out; Killing container and marking as error"
      podman kill $module
      echo $module >>./errors.txt
    else
      echo "ERROR while running module $module: Exit code=$status; Marking as error"
      echo $module >>./errors.txt
    fi
  fi
}

run() {
  while IFS= read -r module; do
    run_module $module
  done <"./modulenames.txt"
}

podman build -t pynguin .
run
