#!/usr/bin/env bash
# run.sh -- build and run the WGPU game scaffold

CARP_FORK_DIR="/home/sqrew/Desktop/Carp-fork"
PROJECT_DIR="/home/sqrew/Desktop/carp-wgpu-scaffold"

if [ ! -d "$CARP_FORK_DIR" ]; then
    echo "Error: Carp-fork directory not found at $CARP_FORK_DIR"
    exit 1
fi

cd "$CARP_FORK_DIR"
./scripts/carp.sh -x $PROJECT_DIR/src/main.carp
