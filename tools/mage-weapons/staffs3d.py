"""Все посохи мага: реестр WEAPONS [(id, функция, редкость)], SPEC[id] = (масштаб, y кисти),
GUARD[id] — y низа навершия (BladeBase), FOCUS[id] — воксель центра камня (если авто не подходит)."""
import staffs_f1, staffs_f2, staffs_f3, staffs_f4, staffs_f5

WEAPONS = []
for mod in (staffs_f1, staffs_f2, staffs_f3, staffs_f4, staffs_f5):
    WEAPONS += mod.WEAPONS

SPEC = {}
GUARD = {}
FOCUS = {}
KEEP = {}
for mod in (staffs_f1, staffs_f2, staffs_f3, staffs_f4, staffs_f5):
    SPEC.update(getattr(mod, 'SPEC', {}))
    GUARD.update(getattr(mod, 'GUARD', {}))
    FOCUS.update(getattr(mod, 'FOCUS', {}))
    KEEP.update(getattr(mod, 'KEEP', {}))
for wid, _, _ in WEAPONS:
    SPEC.setdefault(wid, (0.8, 22))
    GUARD.setdefault(wid, 44)
