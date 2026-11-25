-- СГЕНЕРИРОВАНО tools/make-assemble.js
-- Оригинал требует модуль конфига через require; в потоке MCP это запрещено
-- (Capabilities: Network), поэтому исходник модуля встроен и грузится loadstring.
local __DATA = assert(loadstring([=[
-- Сгенерировано tools/mage-weapons/export_staffs.py. Меши посохов мага: MeshPart из staffs_mage.glb.
-- offset/size — в стадах относительно хвата (Attachment Grip у Root). Посох по +Y.
-- bladeBase — низ навершия, bladeTip — верх посоха, focus — центр светящегося камня навершия
-- (VoxelWeaponBuilder ставит туда BladeTip: оттуда срываются снаряды и заклинания).
-- Сборщик tools/mage-weapons/AssembleMageWeapons.lua кладёт импортированные меши в
-- ReplicatedStorage.WeaponMeshes; без них VoxelWeaponBuilder строит запасной воксельный посох.
return {
	apprentice_staff = {
		scale = 0.8, rarity = "common",
		bladeBase = 2.150, bladeTip = 3.650, bottom = -2.250,
		focus = Vector3.new(0.0000, 2.8100, 0.0000),
		aura = { offset = Vector3.new(0.0000, 2.9000, 0.0000), size = Vector3.new(0.8000, 1.5000, 0.4000) },
		objects = {
			{ name = "W_apprentice_staff", role = "mesh", offset = Vector3.new(0.0000, 0.7000, 0.0000), size = Vector3.new(0.8000, 5.9000, 0.4000) },
			{ name = "G1_apprentice_staff", role = "glow", offset = Vector3.new(0.0000, 2.8500, 0.0000), size = Vector3.new(0.4000, 0.6000, 0.4000), glow = Color3.fromHex("#8C6CFF") },
			{ name = "G2_apprentice_staff", role = "glow", offset = Vector3.new(0.0000, 2.7000, 0.0000), size = Vector3.new(0.2000, 0.1000, 0.2000), glow = Color3.fromHex("#F0EBFF") },
		},
	},
	rusted_rod = {
		scale = 0.8, rarity = "common",
		bladeBase = 2.150, bladeTip = 3.550, bottom = -2.250,
		focus = Vector3.new(0.0000, 3.4500, 0.0000),
		aura = { offset = Vector3.new(0.0000, 2.8500, 0.0000), size = Vector3.new(0.8000, 1.4000, 0.8000) },
		objects = {
			{ name = "W_rusted_rod", role = "mesh", offset = Vector3.new(0.0000, 0.5500, 0.0000), size = Vector3.new(0.8000, 5.6000, 0.8000) },
			{ name = "G1_rusted_rod", role = "glow", offset = Vector3.new(0.0000, 2.9500, 0.0000), size = Vector3.new(0.2000, 1.2000, 0.8000), glow = Color3.fromHex("#D9772F") },
		},
	},
	ember_staff = {
		scale = 0.8, rarity = "rare",
		bladeBase = 2.150, bladeTip = 3.850, bottom = -2.250,
		focus = Vector3.new(0.0177, 2.7121, 0.0121),
		aura = { offset = Vector3.new(0.0000, 3.0000, 0.0000), size = Vector3.new(0.8000, 1.7000, 0.8000) },
		objects = {
			{ name = "W_ember_staff", role = "mesh", offset = Vector3.new(0.0000, 0.6000, 0.0000), size = Vector3.new(0.8000, 5.7000, 0.8000) },
			{ name = "G1_ember_staff", role = "glow", offset = Vector3.new(0.0000, 3.0500, 0.0500), size = Vector3.new(0.8000, 1.6000, 0.5000), glow = Color3.fromHex("#FF7A1F") },
			{ name = "G2_ember_staff", role = "glow", offset = Vector3.new(0.0000, 2.5500, 0.0000), size = Vector3.new(0.6000, 0.2000, 0.6000), glow = Color3.fromHex("#FFF0B0") },
		},
	},
	warden_rod = {
		scale = 0.8, rarity = "rare",
		bladeBase = 2.150, bladeTip = 3.850, bottom = -2.250,
		focus = Vector3.new(0.0000, 2.7500, 0.0000),
		aura = { offset = Vector3.new(0.0000, 3.0000, 0.0000), size = Vector3.new(0.6000, 1.7000, 0.6000) },
		objects = {
			{ name = "W_warden_rod", role = "mesh", offset = Vector3.new(0.0000, 0.8000, 0.0000), size = Vector3.new(0.6000, 6.1000, 0.6000) },
			{ name = "G1_warden_rod", role = "glow", offset = Vector3.new(0.0000, 2.7500, 0.0000), size = Vector3.new(0.4000, 0.4000, 0.4000), glow = Color3.fromHex("#FFD45A") },
			{ name = "G2_warden_rod", role = "glow", offset = Vector3.new(0.0000, 2.7500, 0.0000), size = Vector3.new(0.2000, 0.2000, 0.2000), glow = Color3.fromHex("#FFFDEE") },
		},
	},
	gate_staff = {
		scale = 0.8, rarity = "epic",
		bladeBase = 2.150, bladeTip = 4.050, bottom = -2.250,
		focus = Vector3.new(-0.0015, 2.9909, 0.0045),
		aura = { offset = Vector3.new(0.0000, 3.1000, 0.0000), size = Vector3.new(1.2000, 1.9000, 0.6000) },
		objects = {
			{ name = "W_gate_staff", role = "mesh", offset = Vector3.new(0.0000, 0.7500, 0.0000), size = Vector3.new(1.2000, 6.0000, 0.4000) },
			{ name = "G1_gate_staff", role = "glow", offset = Vector3.new(0.0000, 3.1500, 0.0000), size = Vector3.new(0.4000, 1.8000, 0.6000), glow = Color3.fromHex("#6FB8FF") },
			{ name = "G2_gate_staff", role = "glow", offset = Vector3.new(0.0000, 2.9500, -0.0500), size = Vector3.new(0.2000, 0.6000, 0.1000), glow = Color3.fromHex("#E4F4FF") },
		},
	},
	beacon_staff = {
		scale = 0.8, rarity = "epic",
		bladeBase = 2.150, bladeTip = 4.150, bottom = -2.250,
		focus = Vector3.new(-0.0004, 2.7784, 0.0013),
		aura = { offset = Vector3.new(0.0000, 3.1500, 0.0000), size = Vector3.new(1.0000, 2.0000, 1.0000) },
		objects = {
			{ name = "W_beacon_staff", role = "mesh", offset = Vector3.new(0.0000, 0.1500, 0.0000), size = Vector3.new(1.0000, 4.8000, 1.0000) },
			{ name = "G1_beacon_staff", role = "glow", offset = Vector3.new(0.0000, 3.4500, 0.0000), size = Vector3.new(0.6000, 0.6000, 0.6000), glow = Color3.fromHex("#B8200F") },
			{ name = "G2_beacon_staff", role = "glow", offset = Vector3.new(0.0000, 2.7500, 0.0000), size = Vector3.new(0.8000, 1.4000, 0.8000), glow = Color3.fromHex("#FF5A1F") },
			{ name = "G3_beacon_staff", role = "glow", offset = Vector3.new(0.0000, 3.3000, 0.0000), size = Vector3.new(1.0000, 1.7000, 0.8000), glow = Color3.fromHex("#FFB536") },
		},
	},
	gatekeeper_scepter = {
		scale = 0.8, rarity = "legendary",
		bladeBase = 2.150, bladeTip = 4.050, bottom = -2.250,
		focus = Vector3.new(0.0000, 3.0000, 0.0000),
		aura = { offset = Vector3.new(0.0500, 3.1000, 0.0000), size = Vector3.new(1.7000, 1.9000, 0.4000) },
		objects = {
			{ name = "W_gatekeeper_scepter", role = "mesh", offset = Vector3.new(0.0000, 0.8500, 0.0000), size = Vector3.new(1.2000, 6.2000, 0.4000) },
			{ name = "G1_gatekeeper_scepter", role = "glow", offset = Vector3.new(0.0500, 2.3000, 0.0000), size = Vector3.new(1.7000, 3.5000, 0.2000), glow = Color3.fromHex("#FFD45A") },
			{ name = "G2_gatekeeper_scepter", role = "glow", offset = Vector3.new(0.0000, 3.4000, 0.0000), size = Vector3.new(0.8000, 1.3000, 0.2000), glow = Color3.fromHex("#FFFDEE") },
		},
	},
	reed_wand = {
		scale = 0.8, rarity = "common",
		bladeBase = 2.150, bladeTip = 3.850, bottom = -2.250,
		focus = Vector3.new(-0.0870, 3.5630, -0.0019),
		aura = { offset = Vector3.new(0.1500, 3.0000, 0.0000), size = Vector3.new(0.9000, 1.7000, 0.4000) },
		objects = {
			{ name = "W_reed_wand", role = "mesh", offset = Vector3.new(0.0500, 0.5000, 0.0000), size = Vector3.new(1.1000, 5.5000, 0.4000) },
			{ name = "G1_reed_wand", role = "glow", offset = Vector3.new(0.0000, 3.6000, 0.0000), size = Vector3.new(0.6000, 0.5000, 0.4000), glow = Color3.fromHex("#4FD6FF") },
			{ name = "G2_reed_wand", role = "glow", offset = Vector3.new(-0.1000, 3.4500, 0.0000), size = Vector3.new(0.4000, 0.2000, 0.4000), glow = Color3.fromHex("#EFFFFF") },
		},
	},
	mossy_staff = {
		scale = 0.8, rarity = "common",
		bladeBase = 2.150, bladeTip = 3.850, bottom = -2.250,
		focus = Vector3.new(0.0300, 2.7500, 0.3500),
		aura = { offset = Vector3.new(0.0000, 3.0000, 0.0500), size = Vector3.new(1.0000, 1.7000, 0.7000) },
		objects = {
			{ name = "W_mossy_staff", role = "mesh", offset = Vector3.new(0.0000, 0.7500, 0.0000), size = Vector3.new(1.0000, 6.0000, 0.6000) },
			{ name = "G1_mossy_staff", role = "glow", offset = Vector3.new(0.0000, 3.2000, 0.1000), size = Vector3.new(1.0000, 1.3000, 0.6000), glow = Color3.fromHex("#8EE04A") },
			{ name = "G2_mossy_staff", role = "glow", offset = Vector3.new(-0.0500, 2.8000, 0.3500), size = Vector3.new(0.1000, 0.1000, 0.1000), glow = Color3.fromHex("#F4FFC8") },
		},
	},
	tide_staff = {
		scale = 0.8, rarity = "rare",
		bladeBase = 2.150, bladeTip = 3.750, bottom = -2.250,
		focus = Vector3.new(0.0000, 2.9000, 0.0000),
		aura = { offset = Vector3.new(0.0000, 2.9500, 0.0500), size = Vector3.new(1.2000, 1.6000, 0.5000) },
		objects = {
			{ name = "W_tide_staff", role = "mesh", offset = Vector3.new(-0.1000, 0.7500, 0.0000), size = Vector3.new(1.0000, 6.0000, 0.4000) },
			{ name = "G1_tide_staff", role = "glow", offset = Vector3.new(0.2000, 2.6500, 0.0500), size = Vector3.new(0.8000, 0.8000, 0.5000), glow = Color3.fromHex("#4FD6FF") },
			{ name = "G2_tide_staff", role = "glow", offset = Vector3.new(0.0000, 2.9000, 0.0000), size = Vector3.new(0.2000, 0.1000, 0.2000), glow = Color3.fromHex("#EFFFFF") },
		},
	},
	thorn_rod = {
		scale = 0.8, rarity = "rare",
		bladeBase = 2.150, bladeTip = 3.950, bottom = -2.250,
		focus = Vector3.new(0.0000, 2.9120, 0.0000),
		aura = { offset = Vector3.new(0.0000, 3.0500, 0.0000), size = Vector3.new(0.8000, 1.8000, 0.8000) },
		objects = {
			{ name = "W_thorn_rod", role = "mesh", offset = Vector3.new(0.0500, 0.5500, 0.0000), size = Vector3.new(0.7000, 5.6000, 0.8000) },
			{ name = "G1_thorn_rod", role = "glow", offset = Vector3.new(0.0000, 3.4000, 0.0000), size = Vector3.new(0.8000, 1.1000, 0.6000), glow = Color3.fromHex("#6FCF5A") },
			{ name = "G2_thorn_rod", role = "glow", offset = Vector3.new(0.0000, 2.7500, 0.0000), size = Vector3.new(0.6000, 0.2000, 0.6000), glow = Color3.fromHex("#EAFFD6") },
		},
	},
	lotus_staff = {
		scale = 0.8, rarity = "epic",
		bladeBase = 2.150, bladeTip = 3.550, bottom = -2.250,
		focus = Vector3.new(0.0000, 2.6500, 0.0000),
		aura = { offset = Vector3.new(0.0000, 2.8500, 0.0000), size = Vector3.new(1.2000, 1.4000, 1.2000) },
		objects = {
			{ name = "W_lotus_staff", role = "mesh", offset = Vector3.new(0.0000, 0.3500, 0.0000), size = Vector3.new(1.2000, 5.2000, 1.2000) },
			{ name = "G1_lotus_staff", role = "glow", offset = Vector3.new(0.0000, 3.0000, 0.0000), size = Vector3.new(1.0000, 1.1000, 0.6000), glow = Color3.fromHex("#FF8FD0") },
		},
	},
	spore_staff = {
		scale = 0.8, rarity = "epic",
		bladeBase = 2.550, bladeTip = 4.150, bottom = -2.250,
		focus = Vector3.new(0.0000, 3.5000, 0.0000),
		aura = { offset = Vector3.new(-0.1000, 3.3500, 0.0000), size = Vector3.new(1.6000, 1.6000, 1.2000) },
		objects = {
			{ name = "W_spore_staff", role = "mesh", offset = Vector3.new(0.0000, 0.6000, 0.0000), size = Vector3.new(1.2000, 5.7000, 1.2000) },
			{ name = "G1_spore_staff", role = "glow", offset = Vector3.new(-0.1000, 3.7000, -0.0500), size = Vector3.new(1.6000, 0.9000, 0.9000), glow = Color3.fromHex("#C8E04A") },
			{ name = "G2_spore_staff", role = "glow", offset = Vector3.new(-0.0500, 3.2500, -0.1000), size = Vector3.new(0.9000, 0.2000, 0.8000), glow = Color3.fromHex("#FFFBD6") },
		},
	},
	gardener_crook = {
		scale = 0.8, rarity = "legendary",
		bladeBase = 2.350, bladeTip = 3.650, bottom = -2.250,
		focus = Vector3.new(0.7500, 1.9000, -0.0500),
		aura = { offset = Vector3.new(0.3000, 3.0000, 0.0000), size = Vector3.new(1.6000, 1.3000, 0.4000) },
		objects = {
			{ name = "W_gardener_crook", role = "mesh", offset = Vector3.new(0.3000, 0.7000, 0.0000), size = Vector3.new(1.6000, 5.9000, 0.4000) },
			{ name = "G1_gardener_crook", role = "glow", offset = Vector3.new(0.3000, 1.0000, 0.0000), size = Vector3.new(1.6000, 5.3000, 0.4000), glow = Color3.fromHex("#6FCF5A") },
			{ name = "G2_gardener_crook", role = "glow", offset = Vector3.new(0.8000, 1.8000, 0.0000), size = Vector3.new(0.4000, 0.1000, 0.4000), glow = Color3.fromHex("#EAFFD6") },
		},
	},
	bone_wand = {
		scale = 0.8, rarity = "common",
		bladeBase = 2.250, bladeTip = 3.350, bottom = -2.250,
		focus = Vector3.new(0.0000, 3.0000, 0.0000),
		aura = { offset = Vector3.new(0.0500, 2.8000, 0.0000), size = Vector3.new(0.7000, 1.1000, 0.4000) },
		objects = {
			{ name = "W_bone_wand", role = "mesh", offset = Vector3.new(0.0500, 0.5500, 0.0000), size = Vector3.new(0.7000, 5.6000, 0.4000) },
			{ name = "G1_bone_wand", role = "glow", offset = Vector3.new(0.0000, 3.0000, 0.0000), size = Vector3.new(0.2000, 0.3000, 0.2000), glow = Color3.fromHex("#E2D6B8") },
		},
	},
	antler_staff = {
		scale = 0.8, rarity = "common",
		bladeBase = 2.150, bladeTip = 3.850, bottom = -2.250,
		focus = Vector3.new(0.0000, 2.8333, 0.0000),
		aura = { offset = Vector3.new(0.0000, 3.0000, 0.0000), size = Vector3.new(1.6000, 1.7000, 0.4000) },
		objects = {
			{ name = "W_antler_staff", role = "mesh", offset = Vector3.new(0.0000, 0.8000, 0.0000), size = Vector3.new(1.6000, 6.1000, 0.4000) },
			{ name = "G1_antler_staff", role = "glow", offset = Vector3.new(0.0000, 2.9500, 0.0000), size = Vector3.new(0.2000, 0.2000, 0.2000), glow = Color3.fromHex("#6FFFD0") },
			{ name = "G2_antler_staff", role = "glow", offset = Vector3.new(0.0000, 2.7500, 0.0000), size = Vector3.new(0.4000, 0.2000, 0.4000), glow = Color3.fromHex("#EAFFF8") },
		},
	},
	howl_staff = {
		scale = 0.8, rarity = "rare",
		bladeBase = 2.150, bladeTip = 3.450, bottom = -2.250,
		focus = Vector3.new(-0.0096, 2.8043, 0.0053),
		aura = { offset = Vector3.new(0.0000, 2.8000, 0.0000), size = Vector3.new(1.2000, 1.3000, 0.4000) },
		objects = {
			{ name = "W_howl_staff", role = "mesh", offset = Vector3.new(0.0000, 0.6000, 0.0000), size = Vector3.new(1.2000, 5.7000, 0.6000) },
			{ name = "G1_howl_staff", role = "glow", offset = Vector3.new(0.0000, 3.0000, 0.0000), size = Vector3.new(0.4000, 0.5000, 0.4000), glow = Color3.fromHex("#6FFFD0") },
			{ name = "G2_howl_staff", role = "glow", offset = Vector3.new(0.0000, 2.6500, 0.0000), size = Vector3.new(0.4000, 0.2000, 0.4000), glow = Color3.fromHex("#EAFFF8") },
		},
	},
	trap_rod = {
		scale = 0.8, rarity = "rare",
		bladeBase = 2.150, bladeTip = 3.450, bottom = -2.250,
		focus = Vector3.new(0.0000, 2.8500, 0.0000),
		aura = { offset = Vector3.new(0.0000, 2.8000, 0.0000), size = Vector3.new(1.4000, 1.3000, 0.4000) },
		objects = {
			{ name = "W_trap_rod", role = "mesh", offset = Vector3.new(0.0000, 0.6000, 0.0000), size = Vector3.new(1.4000, 5.7000, 0.4000) },
			{ name = "G1_trap_rod", role = "glow", offset = Vector3.new(0.0000, 2.8500, 0.0000), size = Vector3.new(0.4000, 0.4000, 0.4000), glow = Color3.fromHex("#E2D6B8") },
		},
	},
	pack_staff = {
		scale = 0.8, rarity = "epic",
		bladeBase = 1.150, bladeTip = 4.250, bottom = -2.250,
		focus = Vector3.new(0.0309, 3.5368, 0.0074),
		aura = { offset = Vector3.new(0.0000, 2.7000, 0.0000), size = Vector3.new(0.8000, 3.1000, 0.8000) },
		objects = {
			{ name = "W_pack_staff", role = "mesh", offset = Vector3.new(0.0000, 0.4500, 0.0500), size = Vector3.new(0.6000, 5.4000, 0.5000) },
			{ name = "G1_pack_staff", role = "glow", offset = Vector3.new(0.0000, 2.8000, 0.0000), size = Vector3.new(0.8000, 2.5000, 0.8000), glow = Color3.fromHex("#6FFFD0") },
			{ name = "G2_pack_staff", role = "glow", offset = Vector3.new(0.0000, 3.8500, -0.0500), size = Vector3.new(0.8000, 0.8000, 0.3000), glow = Color3.fromHex("#EAFFF8") },
		},
	},
	moon_staff = {
		scale = 0.8, rarity = "epic",
		bladeBase = 2.150, bladeTip = 4.050, bottom = -2.250,
		focus = Vector3.new(0.2196, 3.0696, 0.0000),
		aura = { offset = Vector3.new(0.0500, 3.1000, 0.0000), size = Vector3.new(1.5000, 1.9000, 0.4000) },
		objects = {
			{ name = "W_moon_staff", role = "mesh", offset = Vector3.new(-0.1000, 0.7000, 0.0000), size = Vector3.new(1.2000, 5.9000, 0.4000) },
			{ name = "G1_moon_staff", role = "glow", offset = Vector3.new(0.0500, 3.2000, 0.0000), size = Vector3.new(1.5000, 1.7000, 0.4000), glow = Color3.fromHex("#A8C8FF") },
			{ name = "G2_moon_staff", role = "glow", offset = Vector3.new(0.0500, 3.2000, 0.0000), size = Vector3.new(1.3000, 1.5000, 0.2000), glow = Color3.fromHex("#F6F9FF") },
		},
	},
	huntmaster_staff = {
		scale = 0.8, rarity = "legendary",
		bladeBase = 2.150, bladeTip = 4.150, bottom = -2.250,
		focus = Vector3.new(0.0000, 3.1000, 0.0000),
		aura = { offset = Vector3.new(0.0500, 3.1500, 0.0000), size = Vector3.new(1.9000, 2.0000, 0.4000) },
		objects = {
			{ name = "W_huntmaster_staff", role = "mesh", offset = Vector3.new(0.0500, 0.8000, 0.0000), size = Vector3.new(1.9000, 6.1000, 0.6000) },
			{ name = "G1_huntmaster_staff", role = "glow", offset = Vector3.new(0.0000, 2.3500, 0.0000), size = Vector3.new(1.8000, 3.6000, 0.4000), glow = Color3.fromHex("#A8C8FF") },
			{ name = "G2_huntmaster_staff", role = "glow", offset = Vector3.new(0.0000, 3.1000, 0.0000), size = Vector3.new(0.2000, 0.1000, 0.2000), glow = Color3.fromHex("#F6F9FF") },
		},
	},
	poker_rod = {
		scale = 0.8, rarity = "common",
		bladeBase = 2.150, bladeTip = 3.450, bottom = -2.750,
		focus = Vector3.new(-0.0500, 2.8000, -0.0500),
		aura = { offset = Vector3.new(0.1500, 2.8000, 0.0000), size = Vector3.new(0.9000, 1.3000, 0.2000) },
		objects = {
			{ name = "W_poker_rod", role = "mesh", offset = Vector3.new(0.0000, -0.2000, 0.0000), size = Vector3.new(0.6000, 5.1000, 0.2000) },
			{ name = "G1_poker_rod", role = "glow", offset = Vector3.new(0.2000, 2.7000, 0.0000), size = Vector3.new(0.6000, 0.7000, 0.2000), glow = Color3.fromHex("#FF5A1F") },
			{ name = "G2_poker_rod", role = "glow", offset = Vector3.new(0.1500, 3.0500, 0.0000), size = Vector3.new(0.9000, 0.8000, 0.2000), glow = Color3.fromHex("#FFB536") },
			{ name = "G3_poker_rod", role = "glow", offset = Vector3.new(0.1500, 3.0000, -0.0500), size = Vector3.new(0.5000, 0.1000, 0.1000), glow = Color3.fromHex("#FFF4C0") },
		},
	},
	bellows_staff = {
		scale = 0.8, rarity = "rare",
		bladeBase = 1.750, bladeTip = 4.050, bottom = -2.250,
		focus = Vector3.new(-0.0500, 3.6000, -0.0500),
		aura = { offset = Vector3.new(0.0000, 2.9000, 0.0000), size = Vector3.new(1.0000, 2.3000, 0.6000) },
		objects = {
			{ name = "W_bellows_staff", role = "mesh", offset = Vector3.new(0.0000, 0.6000, 0.0000), size = Vector3.new(1.0000, 5.7000, 0.6000) },
			{ name = "G1_bellows_staff", role = "glow", offset = Vector3.new(0.0000, 3.8500, 0.0000), size = Vector3.new(0.4000, 0.4000, 0.4000), glow = Color3.fromHex("#FF5A1F") },
			{ name = "G2_bellows_staff", role = "glow", offset = Vector3.new(0.0000, 3.6000, 0.0000), size = Vector3.new(0.4000, 0.1000, 0.4000), glow = Color3.fromHex("#FFF4C0") },
		},
	},
	slag_rod = {
		scale = 0.8, rarity = "rare",
		bladeBase = 2.150, bladeTip = 3.450, bottom = -2.250,
		focus = Vector3.new(-0.0577, 3.2615, 0.0038),
		aura = { offset = Vector3.new(0.0000, 2.8000, 0.0000), size = Vector3.new(0.8000, 1.3000, 0.8000) },
		objects = {
			{ name = "W_slag_rod", role = "mesh", offset = Vector3.new(0.0000, 0.5500, 0.0000), size = Vector3.new(0.8000, 5.6000, 0.8000) },
			{ name = "G1_slag_rod", role = "glow", offset = Vector3.new(0.0000, 2.6000, 0.0500), size = Vector3.new(0.8000, 1.7000, 0.7000), glow = Color3.fromHex("#FF8A2A") },
		},
	},
	crucible_staff = {
		scale = 0.8, rarity = "epic",
		bladeBase = 2.050, bladeTip = 3.650, bottom = -2.250,
		focus = Vector3.new(0.0000, 2.7486, 0.0000),
		aura = { offset = Vector3.new(0.0000, 2.8500, 0.0000), size = Vector3.new(1.2000, 1.6000, 0.8000) },
		objects = {
			{ name = "W_crucible_staff", role = "mesh", offset = Vector3.new(0.0000, 0.4000, 0.0000), size = Vector3.new(1.2000, 5.3000, 0.8000) },
			{ name = "G1_crucible_staff", role = "glow", offset = Vector3.new(0.0000, 3.0000, 0.0000), size = Vector3.new(1.0000, 1.3000, 0.6000), glow = Color3.fromHex("#FF3A10") },
			{ name = "G2_crucible_staff", role = "glow", offset = Vector3.new(-0.1000, 3.0000, 0.0000), size = Vector3.new(0.4000, 0.3000, 0.6000), glow = Color3.fromHex("#FFE6A0") },
		},
	},
	anvil_rod = {
		scale = 0.8, rarity = "epic",
		bladeBase = 2.050, bladeTip = 4.050, bottom = -2.250,
		focus = Vector3.new(-0.0500, 3.2000, -0.0500),
		aura = { offset = Vector3.new(0.2000, 3.0500, 0.0000), size = Vector3.new(2.0000, 2.0000, 0.6000) },
		objects = {
			{ name = "W_anvil_rod", role = "mesh", offset = Vector3.new(0.2000, 0.3500, 0.0000), size = Vector3.new(1.8000, 5.2000, 0.6000) },
			{ name = "G1_anvil_rod", role = "glow", offset = Vector3.new(0.2000, 3.4000, 0.0000), size = Vector3.new(2.0000, 1.1000, 0.2000), glow = Color3.fromHex("#7FD8FF") },
			{ name = "G2_anvil_rod", role = "glow", offset = Vector3.new(0.1000, 3.5000, 0.0500), size = Vector3.new(0.4000, 1.1000, 0.1000), glow = Color3.fromHex("#FFFFFF") },
		},
	},
	founder_staff = {
		scale = 0.8, rarity = "legendary",
		bladeBase = 2.150, bladeTip = 4.250, bottom = -2.250,
		focus = Vector3.new(0.0000, 3.0500, 0.0000),
		aura = { offset = Vector3.new(0.0000, 3.2000, -0.0500), size = Vector3.new(2.0000, 2.1000, 0.7000) },
		objects = {
			{ name = "W_founder_staff", role = "mesh", offset = Vector3.new(0.0500, 0.8500, -0.1000), size = Vector3.new(1.5000, 6.2000, 0.6000) },
			{ name = "G1_founder_staff", role = "glow", offset = Vector3.new(0.0000, -0.1000, 0.0000), size = Vector3.new(0.2000, 3.1000, 0.2000), glow = Color3.fromHex("#FFB536") },
			{ name = "G2_founder_staff", role = "glow", offset = Vector3.new(0.0000, 3.3500, 0.0000), size = Vector3.new(2.0000, 1.8000, 0.6000), glow = Color3.fromHex("#FFE39A") },
			{ name = "G3_founder_staff", role = "glow", offset = Vector3.new(0.0000, 3.0500, 0.0000), size = Vector3.new(0.2000, 0.2000, 0.2000), glow = Color3.fromHex("#FFFFFF") },
		},
	},
	molten_scepter = {
		scale = 0.8, rarity = "legendary",
		bladeBase = 2.150, bladeTip = 3.950, bottom = -2.250,
		focus = Vector3.new(-0.0030, 2.9680, -0.0130),
		aura = { offset = Vector3.new(0.0000, 3.0500, 0.0000), size = Vector3.new(1.2000, 1.8000, 1.0000) },
		objects = {
			{ name = "W_molten_scepter", role = "mesh", offset = Vector3.new(0.0000, 0.5000, 0.0000), size = Vector3.new(1.0000, 5.5000, 1.0000) },
			{ name = "G1_molten_scepter", role = "glow", offset = Vector3.new(0.0000, 1.3000, 0.0000), size = Vector3.new(1.2000, 5.3000, 0.6000), glow = Color3.fromHex("#FF3A10") },
			{ name = "G2_molten_scepter", role = "glow", offset = Vector3.new(0.0000, 2.9500, 0.0000), size = Vector3.new(0.2000, 0.2000, 0.2000), glow = Color3.fromHex("#FFE6A0") },
		},
	},
	unfinished_staff = {
		scale = 0.8, rarity = "secret",
		bladeBase = 2.250, bladeTip = 4.150, bottom = -2.250,
		focus = Vector3.new(0.0000, 2.7684, 0.0000),
		aura = { offset = Vector3.new(-0.0500, 3.2000, 0.0000), size = Vector3.new(1.3000, 1.9000, 0.8000) },
		objects = {
			{ name = "W_unfinished_staff", role = "mesh", offset = Vector3.new(0.0000, 0.7500, 0.0000), size = Vector3.new(0.8000, 6.0000, 0.8000) },
			{ name = "G1_unfinished_staff", role = "glow", offset = Vector3.new(-0.0500, 1.8000, 0.0000), size = Vector3.new(0.1000, 0.5000, 0.2000), glow = Color3.fromHex("#FF5A1F") },
			{ name = "G2_unfinished_staff", role = "glow", offset = Vector3.new(-0.0500, 3.5500, -0.1000), size = Vector3.new(1.3000, 1.2000, 0.6000), glow = Color3.fromHex("#FFB536") },
			{ name = "G3_unfinished_staff", role = "glow", offset = Vector3.new(0.0000, 2.7000, 0.0000), size = Vector3.new(0.6000, 0.5000, 0.6000), glow = Color3.fromHex("#FFE39A") },
			{ name = "G4_unfinished_staff", role = "glow", offset = Vector3.new(0.0000, 2.9000, -0.0500), size = Vector3.new(0.6000, 0.1000, 0.5000), glow = Color3.fromHex("#FFFFFF") },
		},
	},
	quill_wand = {
		scale = 0.8, rarity = "common",
		bladeBase = 2.350, bladeTip = 3.750, bottom = -2.250,
		focus = Vector3.new(-0.0500, 3.6000, -0.0500),
		aura = { offset = Vector3.new(0.1000, 3.0500, 0.0500), size = Vector3.new(0.8000, 1.4000, 0.3000) },
		objects = {
			{ name = "W_quill_wand", role = "mesh", offset = Vector3.new(0.1000, 0.5500, 0.0000), size = Vector3.new(0.8000, 5.6000, 0.4000) },
			{ name = "G1_quill_wand", role = "glow", offset = Vector3.new(0.0000, 3.3000, 0.0000), size = Vector3.new(0.2000, 0.9000, 0.2000), glow = Color3.fromHex("#6A58D8") },
			{ name = "G2_quill_wand", role = "glow", offset = Vector3.new(0.0000, 3.6000, 0.0000), size = Vector3.new(0.2000, 0.1000, 0.2000), glow = Color3.fromHex("#D2C4FF") },
		},
	},
	page_staff = {
		scale = 0.8, rarity = "rare",
		bladeBase = 2.250, bladeTip = 3.650, bottom = -2.250,
		focus = Vector3.new(-0.0500, 3.0000, -0.0500),
		aura = { offset = Vector3.new(0.0000, 2.9500, 0.0000), size = Vector3.new(1.4000, 1.4000, 0.6000) },
		objects = {
			{ name = "W_page_staff", role = "mesh", offset = Vector3.new(0.0000, 0.3500, -0.0500), size = Vector3.new(1.4000, 5.2000, 0.5000) },
			{ name = "G1_page_staff", role = "glow", offset = Vector3.new(0.0500, 3.2500, 0.0000), size = Vector3.new(1.3000, 0.8000, 0.6000), glow = Color3.fromHex("#EFE6CC") },
			{ name = "G2_page_staff", role = "glow", offset = Vector3.new(0.0500, 3.2500, 0.0000), size = Vector3.new(1.3000, 0.8000, 0.2000), glow = Color3.fromHex("#FFFFF4") },
		},
	},
	hourglass_rod = {
		scale = 0.8, rarity = "rare",
		bladeBase = 2.150, bladeTip = 3.850, bottom = -2.250,
		focus = Vector3.new(-0.0500, 2.9000, -0.0500),
		aura = { offset = Vector3.new(0.0000, 3.0000, 0.0000), size = Vector3.new(0.8000, 1.7000, 0.8000) },
		objects = {
			{ name = "W_hourglass_rod", role = "mesh", offset = Vector3.new(0.0000, 0.8000, 0.0000), size = Vector3.new(0.8000, 6.1000, 0.8000) },
			{ name = "G1_hourglass_rod", role = "glow", offset = Vector3.new(0.0000, 2.8500, 0.0000), size = Vector3.new(0.6000, 1.0000, 0.6000), glow = Color3.fromHex("#FFD98A") },
			{ name = "G2_hourglass_rod", role = "glow", offset = Vector3.new(-0.0500, 2.7500, -0.0500), size = Vector3.new(0.5000, 0.8000, 0.5000), glow = Color3.fromHex("#FFF8DE") },
		},
	},
	tome_staff = {
		scale = 0.8, rarity = "epic",
		bladeBase = 2.250, bladeTip = 3.450, bottom = -2.250,
		focus = Vector3.new(-0.0500, 3.2000, -0.0500),
		aura = { offset = Vector3.new(0.0000, 2.8500, 0.0000), size = Vector3.new(1.6000, 1.2000, 1.0000) },
		objects = {
			{ name = "W_tome_staff", role = "mesh", offset = Vector3.new(0.0000, 0.3500, 0.0000), size = Vector3.new(1.6000, 5.2000, 0.8000) },
			{ name = "G1_tome_staff", role = "glow", offset = Vector3.new(0.0000, 3.0500, 0.0000), size = Vector3.new(1.4000, 0.8000, 1.0000), glow = Color3.fromHex("#8C6CFF") },
			{ name = "G2_tome_staff", role = "glow", offset = Vector3.new(0.0000, 3.3000, 0.0000), size = Vector3.new(1.0000, 0.3000, 1.0000), glow = Color3.fromHex("#F0EBFF") },
		},
	},
	clock_staff = {
		scale = 0.8, rarity = "epic",
		bladeBase = 2.150, bladeTip = 3.950, bottom = -2.250,
		focus = Vector3.new(-0.0500, 2.9000, -0.0500),
		aura = { offset = Vector3.new(0.0000, 3.0500, 0.0000), size = Vector3.new(1.4000, 1.8000, 0.4000) },
		objects = {
			{ name = "W_clock_staff", role = "mesh", offset = Vector3.new(0.0000, 0.8500, 0.0000), size = Vector3.new(1.4000, 6.2000, 0.4000) },
			{ name = "G1_clock_staff", role = "glow", offset = Vector3.new(0.1500, 2.4000, 0.0500), size = Vector3.new(0.3000, 1.7000, 0.5000), glow = Color3.fromHex("#6FE3FF") },
			{ name = "G2_clock_staff", role = "glow", offset = Vector3.new(-0.0500, 2.9000, 0.0000), size = Vector3.new(0.1000, 0.1000, 0.4000), glow = Color3.fromHex("#F2FFFF") },
		},
	},
	chronicler_staff = {
		scale = 0.8, rarity = "legendary",
		bladeBase = 2.050, bladeTip = 4.250, bottom = -2.250,
		focus = Vector3.new(-0.0500, 2.9000, -0.0500),
		aura = { offset = Vector3.new(0.1000, 3.1500, 0.0000), size = Vector3.new(1.2000, 2.2000, 0.8000) },
		objects = {
			{ name = "W_chronicler_staff", role = "mesh", offset = Vector3.new(0.0500, 1.0000, 0.0000), size = Vector3.new(0.9000, 6.5000, 0.8000) },
			{ name = "G1_chronicler_staff", role = "glow", offset = Vector3.new(0.1000, 2.2500, 0.0000), size = Vector3.new(1.2000, 3.4000, 0.6000), glow = Color3.fromHex("#6A58D8") },
		},
	},
	ink_scepter = {
		scale = 0.8, rarity = "legendary",
		bladeBase = 2.150, bladeTip = 3.850, bottom = -2.250,
		focus = Vector3.new(0.0006, 2.9051, 0.0000),
		aura = { offset = Vector3.new(0.0000, 3.0000, 0.0000), size = Vector3.new(1.2000, 1.7000, 1.0000) },
		objects = {
			{ name = "W_ink_scepter", role = "mesh", offset = Vector3.new(0.0000, 0.6500, 0.0000), size = Vector3.new(0.8000, 5.8000, 0.8000) },
			{ name = "G1_ink_scepter", role = "glow", offset = Vector3.new(0.0000, 2.5000, 0.0000), size = Vector3.new(1.2000, 2.7000, 1.0000), glow = Color3.fromHex("#6A58D8") },
			{ name = "G2_ink_scepter", role = "glow", offset = Vector3.new(0.0000, 2.9000, 0.0000), size = Vector3.new(0.2000, 0.3000, 0.2000), glow = Color3.fromHex("#D2C4FF") },
		},
	},
	memory_staff = {
		scale = 0.8, rarity = "secret",
		bladeBase = 2.150, bladeTip = 4.150, bottom = -2.250,
		focus = Vector3.new(0.0290, 2.8971, -0.0014),
		aura = { offset = Vector3.new(0.0000, 3.1500, 0.0000), size = Vector3.new(1.6000, 2.0000, 0.8000) },
		objects = {
			{ name = "W_memory_staff", role = "mesh", offset = Vector3.new(0.0000, 0.2000, 0.0000), size = Vector3.new(0.8000, 4.9000, 0.8000) },
			{ name = "G1_memory_staff", role = "glow", offset = Vector3.new(0.0000, 0.6500, 0.0000), size = Vector3.new(1.4000, 5.0000, 0.6000), glow = Color3.fromHex("#6FE3FF") },
			{ name = "G2_memory_staff", role = "glow", offset = Vector3.new(-0.0500, 3.2000, 0.0000), size = Vector3.new(0.9000, 0.7000, 0.8000), glow = Color3.fromHex("#B49CFF") },
			{ name = "G3_memory_staff", role = "glow", offset = Vector3.new(0.0000, 3.4500, 0.0000), size = Vector3.new(1.6000, 1.4000, 0.2000), glow = Color3.fromHex("#FFFFFF") },
		},
	},
}

]=], "WeaponMeshDataMage"))()

--[[
	AssembleMageWeapons — меши посохов мага (37 шт., этажи 1–5) → ReplicatedStorage.WeaponMeshes.
	Запускает Артём сам: Studio, Command Bar, режим Edit (НЕ во время Play).
	Один раз после импорта. Повторный запуск безопасен.

	До запуска:
	1. ReplicatedStorage.Shared.Config.WeaponMeshDataMage — пришёл из src через Rojo.
	2. File → Import 3D → tools/mage-weapons/assets/staffs_mage.glb, настройки не менять.
	   В Workspace появится модель staffs_mage со 111 MeshPart:
	   W_<посох> (с палитрой) у всех 37 и G1_/G2_/G3_/G4_<посох> (свечение навершия:
	   кристаллы, пламя, порталы, руны, искры).

	Что делает: переносит MeshPart в ReplicatedStorage.WeaponMeshes (туда же, где оружие
	воина; имена не пересекаются), ставит размер из WeaponMeshDataMage, отключает
	коллизии; у свечения убирает текстуру (цвет и Neon ставит VoxelWeaponBuilder).
	Пустую модель импорта удаляет. После — Ctrl+S: папка живёт только в файле места.
	Меши уже повёрнуты при экспорте (как оружие этажей 2–5): ImportYaw у папки не трогаем.
	Если посохи в руке смотрят навершием назад — у папки WeaponMeshes ImportYaw = 180.

	Без мешей посохи всё равно работают: VoxelWeaponBuilder строит запасной воксельный посох.

	Проверка в Play (сервер, Command Bar):
	  print(game.ServerStorage.KlinokDebug.Cmd:Invoke("staff memory_staff"))
]]
local RS = game:GetService("ReplicatedStorage")
local DATA = __DATA

local folder = RS:FindFirstChild("WeaponMeshes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WeaponMeshes"
	folder.Parent = RS
end
if folder:GetAttribute("ImportYaw") == nil then
	folder:SetAttribute("ImportYaw", 0)
end

local source = workspace:FindFirstChild("staffs_mage")

local function findMesh(name: string): MeshPart?
	local roots = { folder }
	if source then
		table.insert(roots, 1, source)
	end
	for _, root in ipairs(roots) do
		local fallback = nil
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("MeshPart") then
				if d.Name == name then
					return d
				end
				-- Импортер иногда дописывает имя материала: "W_apprentice_staff_palette".
				if not fallback and string.sub(d.Name, 1, #name + 1) == name .. "_" and not string.match(string.sub(d.Name, #name + 2), "^%d") then
					fallback = d
				end
			end
		end
		if fallback then
			return fallback
		end
	end
	return nil
end

local placed, missing, total = 0, 0, 0
for weaponId, weapon in pairs(DATA) do
	for _, o in ipairs(weapon.objects) do
		total += 1
		local mp = findMesh(o.name)
		if not mp then
			missing += 1
			warn(("[AssembleMageWeapons] %s: нет MeshPart %s"):format(weaponId, o.name))
			continue
		end
		local old = folder:FindFirstChild(o.name)
		if old and old ~= mp then
			old:Destroy()
		end
		mp.Name = o.name
		mp.Anchored = true
		mp.CanCollide = false
		mp.CanQuery = false
		mp.CanTouch = false
		mp.Massless = true
		mp.CastShadow = false
		mp.Size = o.size
		mp.CFrame = CFrame.new(0, -500, 0)
		pcall(function()
			mp.CollisionFidelity = Enum.CollisionFidelity.Box
		end)
		for _, c in ipairs(mp:GetChildren()) do
			if c:IsA("JointInstance") or c:IsA("WeldConstraint") then
				c:Destroy()
			end
		end
		if o.role == "glow" then
			mp.TextureID = ""
			mp.Material = Enum.Material.Neon
			mp.Color = o.glow or Color3.fromRGB(255, 181, 54)
			for _, c in ipairs(mp:GetChildren()) do
				if c:IsA("SurfaceAppearance") then
					c:Destroy()
				end
			end
		end
		mp.Parent = folder
		placed += 1
	end
end

if source and #source:GetDescendants() == 0 then
	source:Destroy()
elseif source then
	local left = 0
	for _, d in ipairs(source:GetDescendants()) do
		if d:IsA("MeshPart") then
			left += 1
		end
	end
	if left == 0 then
		source:Destroy()
	end
end

print(("[AssembleMageWeapons] готово: %d из %d MeshPart в ReplicatedStorage.WeaponMeshes, не найдено %d. Сохраните место (Ctrl+S)."):format(placed, total, missing))
