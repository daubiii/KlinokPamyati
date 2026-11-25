"""Run a project Python script inside Blender with local Pillow available.
blender -b --python-exit-code 1 -P .sharrowkin/scripts/blender_project.py -- script.py [args]
"""
from pathlib import Path
import runpy
import sys

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / '.sharrowkin' / 'blender-deps'))
args = sys.argv[sys.argv.index('--') + 1:]
script = Path(args[0]).resolve()
sys.path.insert(0, str(script.parent))
# Existing render scripts expect Blender's -- separator.
sys.argv = [str(script), '--', *args[1:]]
runpy.run_path(str(script), run_name='__main__')
