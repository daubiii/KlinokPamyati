-- Сгенерировано export_weapons.py (Claude). Меши оружия этажа 1: MeshPart из weapons_floor1.obj.
-- offset/size — в стадах относительно хвата (Attachment Grip у Root). Клинок по +Y.
-- Сборщик AssembleWeapons.lua кладёт импортированные меши в ReplicatedStorage.WeaponMeshes;
-- VoxelWeaponBuilder строит модель из них, а без них — по-старому из вокселей.
return {
	rusty_sword = {
		scale = 0.95, rarity = "common",
		bladeBase = 0.534, bladeTip = 3.859, bottom = -1.009,
		objects = {
			{ name = "W_rusty_sword", role = "mesh", offset = Vector3.new(0.0000, 1.4250, 0.0000), size = Vector3.new(1.4250, 4.8688, 0.4750) },
		},
	},
	iron_falchion = {
		scale = 0.82, rarity = "common",
		bladeBase = 0.461, bladeTip = 4.151, bottom = -1.179,
		objects = {
			{ name = "W_iron_falchion", role = "mesh", offset = Vector3.new(0.0000, 1.4863, -0.0512), size = Vector3.new(1.6400, 5.3300, 0.3075) },
		},
	},
	forge_hammer = {
		scale = 1.0, rarity = "common",
		bladeBase = 2.562, bladeTip = 3.812, bottom = -1.438,
		objects = {
			{ name = "W_forge_hammer", role = "mesh", offset = Vector3.new(0.0000, 1.1875, -0.0625), size = Vector3.new(2.2500, 5.2500, 1.1250) },
		},
	},
	guard_blade = {
		scale = 0.82, rarity = "rare",
		bladeBase = 0.359, bladeTip = 4.254, bottom = -1.076,
		objects = {
			{ name = "W_guard_blade", role = "mesh", offset = Vector3.new(-0.0513, 1.5888, -0.0512), size = Vector3.new(1.7425, 5.3300, 0.7175) },
		},
	},
	guard_hammer = {
		scale = 0.95, rarity = "rare",
		bladeBase = 2.434, bladeTip = 3.859, bottom = -1.484,
		objects = {
			{ name = "W_guard_hammer", role = "mesh", offset = Vector3.new(0.0000, 1.1875, -0.0594), size = Vector3.new(2.3750, 5.3438, 1.5437) },
		},
	},
	vortex_blade = {
		scale = 0.92, rarity = "epic",
		bladeBase = 0.633, bladeTip = 3.853, bottom = -1.438,
		objects = {
			{ name = "W_vortex_blade", role = "mesh", offset = Vector3.new(0.2300, 1.0350, 0.0000), size = Vector3.new(2.3000, 4.9450, 0.6900) },
			{ name = "G1_vortex_blade", role = "glow", offset = Vector3.new(0.0575, 1.3225, 0.0000), size = Vector3.new(2.8750, 5.0600, 0.6900), glow = Color3.fromHex("#FFB536") },
			{ name = "G2_vortex_blade", role = "glow", offset = Vector3.new(0.2875, 2.0700, 0.0000), size = Vector3.new(2.1850, 2.8750, 0.6900), glow = Color3.fromHex("#FFE39A") },
		},
	},
	shattered_hammer = {
		scale = 0.85, rarity = "epic",
		bladeBase = 1.859, bladeTip = 4.091, bottom = -1.328,
		objects = {
			{ name = "W_shattered_hammer", role = "mesh", offset = Vector3.new(0.0000, 1.1156, -0.0531), size = Vector3.new(2.1250, 4.8875, 1.1687) },
			{ name = "G1_shattered_hammer", role = "glow", offset = Vector3.new(0.0000, 1.4875, -0.0531), size = Vector3.new(2.7625, 5.2062, 1.3813), glow = Color3.fromHex("#FFB536") },
			{ name = "G2_shattered_hammer", role = "glow", offset = Vector3.new(0.0000, 2.8687, -0.0531), size = Vector3.new(1.2750, 0.9562, 1.3813), glow = Color3.fromHex("#FFE39A") },
		},
	},
	gatekeeper_key = {
		scale = 0.68, rarity = "legendary",
		bladeBase = 0.298, bladeTip = 5.653, bottom = -1.318,
		objects = {
			{ name = "W_gatekeeper_key", role = "mesh", offset = Vector3.new(0.0000, 1.9550, 0.0000), size = Vector3.new(1.8700, 6.5450, 0.5100) },
			{ name = "G1_gatekeeper_key", role = "glow", offset = Vector3.new(0.1275, 2.3375, 0.0000), size = Vector3.new(1.9550, 6.6300, 0.5100), glow = Color3.fromHex("#FFB536") },
			{ name = "G2_gatekeeper_key", role = "glow", offset = Vector3.new(0.0000, 2.4650, 0.0000), size = Vector3.new(0.3400, 3.8250, 0.6800), glow = Color3.fromHex("#FFE39A") },
		},
	},
}
