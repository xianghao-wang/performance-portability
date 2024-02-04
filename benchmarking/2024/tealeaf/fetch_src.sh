#!/bin/bash

set -eu

fetch_src() {
  if [ ! -e TeaLeaf/driver/main.cpp ]; then
    if ! git clone https://github.com/milthorpe/TeaLeaf; then
      echo
      echo "Failed to fetch source code."
      echo
      exit 1

    fi
  else
    (
      cd TeaLeaf
      # git pull
    )
  fi
  export SRC_DIR="$PWD/TeaLeaf"
}