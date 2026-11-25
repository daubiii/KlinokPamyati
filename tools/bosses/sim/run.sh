#!/bin/bash
# Офлайн-прогон сцен появления боссов — без Studio, на эмуляции Roblox API.
#   LUAU=путь/к/luau bash tools/bosses/sim/run.sh                 проверка: 5 боссов × полная / короткая / опоздавший
#   LUAU=путь/к/luau bash tools/bosses/sim/run.sh storyboard [id] раскадровки tools/bosses/sim/out/sheet_<id>.png
# Для раскадровок нужны python3 + numpy + Pillow. Модель босса — условный манекен.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
LUAU="${LUAU:-luau}"
CONTROLLERS=BossIntroController,BossIntroScenes,EnemyFx,EnemyVisualController,CameraController
if [ "$1" = "storyboard" ]; then
  ONLY="nil"; [ -n "$2" ] && ONLY="\"$2\""
  SIM_PRELUDE="local SIM_ONLY = $ONLY
" python3 "$HERE/build.py" "$CONTROLLERS" driver_dump.lua > /dev/null
  "$LUAU" "$HERE/out/sim.lua" > "$HERE/out/frames.jsonl"
  python3 "$HERE/render.py" "$HERE/out/frames.jsonl"
else
  python3 "$HERE/build.py" "$CONTROLLERS" > /dev/null
  "$LUAU" "$HERE/out/sim.lua"
fi
