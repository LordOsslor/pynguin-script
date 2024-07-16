#!/bin/bash

IFS="," read -a array <<<"$1"
for arg in ${array[@]}; do
    src="${arg%:*}"
    dest="${arg#*:}"

    echo "Copying /build_dir/$src to $dest"
    cp /build_dir/$src $dest
done
