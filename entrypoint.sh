#!/bin/bash
set -e

DATA_DIR="/root/.hashcoinx"

mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

echo "Starting HashCoinX daemon..."
exec hashcoinxd -datadir="$DATA_DIR" -server=1 -printtoconsole
