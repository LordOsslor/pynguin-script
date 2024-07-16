#!/bin/bash

IFS="," read -a array <<<"$1"
for arg in ${array[@]}; do
    src="${arg%:*}"
    dest="${arg#*:}"

    echo "Copying ./inject/$src to $dest"
    cp ./inject/$src $dest
done
