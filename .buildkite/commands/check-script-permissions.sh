#!/bin/bash -eu

for file in bin/*; do
  echo "Checking for +x permission on $file..."
  if ! [ -x "$file" ]; then
    echo "$file is not executable!"
    exit 1
  fi
done
