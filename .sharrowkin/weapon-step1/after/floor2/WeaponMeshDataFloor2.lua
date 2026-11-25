-- Сгенерировано export_weapons_floor2.py (Claude). Меши оружия этажа 2: MeshPart из weapons_floor2.obj.
-- offset/size — в стадах относительно хвата (Attachment Grip у Root). Клинок по +Y.
-- Сборщик AssembleWeapons.lua кладёт импортированные меши в ReplicatedStorage.WeaponMeshes;
-- VoxelWeaponBuilder строит модель из них, а без них — по-старому из вокселей.
return {
	garden_machete = {
		scale = 1.0, rarity = "common",
		bladeBase = 0.812, bladeTip = 3.438, bottom = -0.812,
		objects = {
			{ name = "W_garden_machete", role = "mesh", offset = Vector3.new(0.0000, 1.3125, 0.0000), size = Vector3.new(1.2500, 4.2500, 0.5000) },
		},
	},
	reed_saber = {
		scale = 0.9, rarity = "common",
		bladeBase = 0.731, bladeTip = 4.331, bottom = -0.844,
		objects = {
			{ name = "W_reed_saber", role = "mesh", offset = Vector3.new(0.1688, 1.7437, 0.0000), size = Vector3.new(1.4625, 5.1750, 0.9000) },
		},
	},
	mud_mallet = {
		scale = 0.9, rarity = "common",
		bladeBase = 2.306, bladeTip = 3.656, bottom = -1.294,
		objects = {
			{ name = "W_mud_mallet", role = "mesh", offset = Vector3.new(0.0000, 1.1812, -0.0562), size = Vector3.new(2.2500, 4.9500, 1.4625) },
		},
	},
	thorn_blade = {
		scale = 0.82, rarity = "rare",
		bladeBase = 0.256, bladeTip = 4.459, bottom = -0.974,
		objects = {
			{ name = "W_thorn_blade", role = "mesh", offset = Vector3.new(0.0000, 1.7425, -0.0512), size = Vector3.new(1.6400, 5.4325, 0.7175) },
		},
	},
	root_hammer = {
		scale = 0.88, rarity = "rare",
		bladeBase = 1.815, bladeTip = 4.565, bottom = -1.375,
		objects = {
			{ name = "W_root_hammer", role = "mesh", offset = Vector3.new(0.0000, 1.5950, -0.0550), size = Vector3.new(2.4200, 5.9400, 1.4300) },
		},
	},
	reaper_blade = {
		scale = 0.78, rarity = "epic",
		bladeBase = 0.341, bladeTip = 5.216, bottom = -1.024,
		objects = {
			{ name = "W_reaper_blade", role = "mesh", offset = Vector3.new(0.1463, 2.0475, 0.0000), size = Vector3.new(2.6325, 6.1425, 0.5850) },
			{ name = "G1_reaper_blade", role = "glow", offset = Vector3.new(0.1950, 2.1938, -0.0487), size = Vector3.new(2.7300, 6.0450, 0.4875), glow = Color3.fromHex("#5FD0C0") },
			{ name = "G2_reaper_blade", role = "glow", offset = Vector3.new(0.5363, 2.5350, 0.0975), size = Vector3.new(1.0725, 3.8025, 0.3900), glow = Color3.fromHex("#B8F2E6") },
		},
	},
	tidal_hammer = {
		scale = 0.82, rarity = "epic",
		bladeBase = 1.794, bladeTip = 4.869, bottom = -1.281,
		objects = {
			{ name = "W_tidal_hammer", role = "mesh", offset = Vector3.new(0.0000, 1.4863, -0.0512), size = Vector3.new(2.4600, 5.5350, 1.3325) },
			{ name = "G1_tidal_hammer", role = "glow", offset = Vector3.new(0.0000, 3.2287, -0.0513), size = Vector3.new(3.0750, 3.0750, 1.5375), glow = Color3.fromHex("#5FD0C0") },
			{ name = "G2_tidal_hammer", role = "glow", offset = Vector3.new(0.0000, 3.3312, -0.0513), size = Vector3.new(3.0750, 3.0750, 1.5375), glow = Color3.fromHex("#B8F2E6") },
		},
	},
	gardener_shears = {
		scale = 0.7, rarity = "legendary",
		bladeBase = 0.044, bladeTip = 5.731, bottom = -1.006,
		objects = {
			{ name = "W_gardener_shears", role = "mesh", offset = Vector3.new(0.0438, 2.1875, 0.0000), size = Vector3.new(2.5375, 6.3875, 0.7000) },
			{ name = "G1_gardener_shears", role = "glow", offset = Vector3.new(0.0000, 3.5000, 0.0000), size = Vector3.new(2.8000, 4.2875, 0.1750), glow = Color3.fromHex("#5FD0C0") },
			{ name = "G2_gardener_shears", role = "glow", offset = Vector3.new(0.0000, 3.5437, 0.0000), size = Vector3.new(2.8000, 4.3750, 0.7000), glow = Color3.fromHex("#B8F2E6") },
		},
	},
}
