#!/bin/sh
# Склеивает fixlib.lua + fix_collisions.lua и выполняет в Studio (режим Edit).
D="$(dirname "$0")"
T="${TMPDIR:-/tmp}/floor1_fix_$$.lua"
cat "$D/fixlib.lua" "$D/bounds_data.lua" "$D/fix_collisions.lua" > "$T"
node C:/Users/artem/.dsh-roblox/s.js exec "$T" Edit
rm -f "$T"
