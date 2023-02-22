#!/bin/bash -eu

pwd 

cd bin

pwd

ls -la

for file in ./*.sh; do
  if ! [ -x "$file" ]; then
    echo "$file is not executable!"
    exit 1
  fi
done
