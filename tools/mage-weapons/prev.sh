#!/bin/bash
# Превью-лист посохов: ./prev.sh <out.png> <cols> [id ...]   (без id — все 37)
# Нужны python3 (numpy, Pillow) и Blender 4.x: BLENDER=/путь/к/blender (по умолчанию blender из PATH).
# Крупный план наверший: ORTHO=3.6 HEAD=1.5 CW=260 CH=280 ./prev.sh heads.png 10
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUTP=$(realpath -m "$1"); COLS=$2; shift 2
BLENDER=${BLENDER:-blender}
D=$(mktemp -d)
python3 "$HERE/export_staffs.py" "$D" "$@" > "$D/export.log" 2>&1 || { tail -20 "$D/export.log"; exit 1; }
tail -3 "$D/export.log"
(cd "$D" && "$BLENDER" -b -P "$HERE/render_sheet.py" -- staffs_mage.obj "$OUTP" iso "$COLS" order.json > "$D/bl.log" 2>&1) || { tail -20 "$D/bl.log"; exit 1; }
python3 "$HERE/compose_sheet.py" "$OUTP" "$D/rarity.json"
rm -rf "$D"
echo "превью: $OUTP"
