#!/bin/bash -eu

for file in *.sh; do
  if ! [ -x "$file" ]; then
    echo "$file is not executable!"
    exit 1
  fi
done
