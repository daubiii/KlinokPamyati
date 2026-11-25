#!/bin/sh
# Этаж 1 v3: полная пересборка из исходников агента (KlinokFloor1v2) → out/
set -e
cd "$(dirname "$0")"
python3 build.py out
python3 audit3.py out 2.0 1
python3 fixspawns.py out 12
python3 spawns.py out
python3 camfix.py out
