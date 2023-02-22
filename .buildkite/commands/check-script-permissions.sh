#!/bin/bash -eu

cd bin

for file in ./*.sh; do
  # echo "$f"
  if ! [ -x "$file" ]; then
    echo "$file is not executable!"
    exit 1
  fi
done
