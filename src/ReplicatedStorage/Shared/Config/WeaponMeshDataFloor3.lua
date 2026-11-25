-- Сгенерировано export_weapons_floors.py 3. Меши оружия этажа 3: MeshPart из weapons_floor3.glb.
-- offset/size — в стадах относительно хвата (Attachment Grip у Root). Клинок по +Y.
-- Сборщик AssembleWeaponsFloors345.lua кладёт импортированные меши в ReplicatedStorage.WeaponMeshes;
-- VoxelWeaponBuilder строит модель из них, а без них — по-старому из вокселей.
return {
	hunt_cleaver = {
		scale = 1.0, rarity = "common",
		bladeBase = 0.812, bladeTip = 3.312, bottom = -0.938,
		aura = { offset = Vector3.new(0.0000, 2.0625, 0.0000), size = Vector3.new(1.2500, 2.5000, 0.5000) },
		objects = {
			{ name = "W_hunt_cleaver", role = "mesh", offset = Vector3.new(0.0000, 1.1875, 0.0000), size = Vector3.new(1.2500, 4.2500, 0.5000) },
		},
	},
	hunt_broadsword = {
		scale = 0.86, rarity = "rare",
		bladeBase = 0.591, bladeTip = 4.354, bottom = -1.129,
		aura = { offset = Vector3.new(0.0000, 2.4725, 0.0000), size = Vector3.new(1.5050, 3.7625, 0.4300) },
		objects = {
			{ name = "W_hunt_broadsword", role = "mesh", offset = Vector3.new(0.0000, 1.6125, 0.0000), size = Vector3.new(1.5050, 5.4825, 0.4300) },
		},
	},
	bear_mace = {
		scale = 0.9, rarity = "rare",
		bladeBase = 2.081, bladeTip = 4.219, bottom = -1.406,
		aura = { offset = Vector3.new(-0.0563, 3.1500, -0.0563), size = Vector3.new(2.3625, 2.1375, 2.3625) },
		objects = {
			{ name = "W_bear_mace", role = "mesh", offset = Vector3.new(-0.0563, 1.4062, -0.0563), size = Vector3.new(2.3625, 5.6250, 2.3625) },
		},
	},
	pack_fang = {
		scale = 0.8, rarity = "epic",
		bladeBase = 0.250, bladeTip = 4.650, bottom = -0.850,
		aura = { offset = Vector3.new(0.1000, 2.4500, 0.0000), size = Vector3.new(1.4000, 4.4000, 0.6000) },
		objects = {
			{ name = "W_pack_fang", role = "mesh", offset = Vector3.new(0.0500, 1.9000, 0.0000), size = Vector3.new(1.5000, 5.5000, 0.6000) },
			{ name = "G1_pack_fang", role = "glow", offset = Vector3.new(0.2000, 1.7000, -0.0500), size = Vector3.new(0.6000, 4.9000, 0.5000), glow = Color3.fromHex("#FFB347") },
			{ name = "G2_pack_fang", role = "glow", offset = Vector3.new(0.6500, 4.4500, -0.0500), size = Vector3.new(0.3000, 0.4000, 0.1000), glow = Color3.fromHex("#FFE2A0") },
		},
	},
	trap_maul = {
		scale = 0.8, rarity = "epic",
		bladeBase = 1.850, bladeTip = 3.650, bottom = -1.250,
		aura = { offset = Vector3.new(0.0000, 2.7500, 0.0000), size = Vector3.new(2.2000, 1.8000, 0.8000) },
		objects = {
			{ name = "W_trap_maul", role = "mesh", offset = Vector3.new(0.0000, 1.2000, 0.0000), size = Vector3.new(2.2000, 4.9000, 0.8000) },
			{ name = "G1_trap_maul", role = "glow", offset = Vector3.new(-0.0500, 2.7000, 0.0000), size = Vector3.new(1.3000, 1.1000, 0.4000), glow = Color3.fromHex("#FF5A3C") },
			{ name = "G2_trap_maul", role = "glow", offset = Vector3.new(0.0000, 2.6500, 0.0000), size = Vector3.new(0.2000, 0.2000, 0.2000), glow = Color3.fromHex("#FFE2A0") },
		},
	},
	royal_scythe = {
		scale = 0.82, rarity = "legendary",
		bladeBase = 4.869, bladeTip = 6.919, bottom = -1.486,
		aura = { offset = Vector3.new(-0.6663, 5.8937, -0.0513), size = Vector3.new(2.9725, 2.0500, 0.5125) },
		objects = {
			{ name = "W_royal_scythe", role = "mesh", offset = Vector3.new(-1.4350, 2.7162, 0.0000), size = Vector3.new(4.5100, 8.4050, 0.4100) },
			{ name = "G1_royal_scythe", role = "glow", offset = Vector3.new(0.0000, 5.0737, -0.0513), size = Vector3.new(0.2050, 0.2050, 0.5125), glow = Color3.fromHex("#FF5A3C") },
			{ name = "G2_royal_scythe", role = "glow", offset = Vector3.new(-1.6912, 1.9475, -0.0512), size = Vector3.new(3.5875, 5.4325, 0.3075), glow = Color3.fromHex("#FFB347") },
			{ name = "G3_royal_scythe", role = "glow", offset = Vector3.new(-1.8450, 4.4075, 0.0000), size = Vector3.new(3.2800, 1.3325, 0.4100), glow = Color3.fromHex("#FFE2A0") },
		},
	},
	falconer_saber = {
		scale = 0.86, rarity = "legendary",
		bladeBase = 0.806, bladeTip = 5.536, bottom = -1.021,
		aura = { offset = Vector3.new(0.0000, 3.1713, -0.0537), size = Vector3.new(3.0100, 4.7300, 0.3225) },
		objects = {
			{ name = "W_falconer_saber", role = "mesh", offset = Vector3.new(0.0000, 2.2575, 0.0000), size = Vector3.new(3.0100, 6.5575, 0.6450) },
			{ name = "G1_falconer_saber", role = "glow", offset = Vector3.new(0.0000, -0.7525, -0.0537), size = Vector3.new(0.4300, 0.1075, 0.1075), glow = Color3.fromHex("#FF5A3C") },
			{ name = "G2_falconer_saber", role = "glow", offset = Vector3.new(0.3225, 3.0100, -0.0537), size = Vector3.new(0.8600, 3.7625, 0.3225), glow = Color3.fromHex("#FFB347") },
			{ name = "G3_falconer_saber", role = "glow", offset = Vector3.new(0.0000, 2.5262, 0.0000), size = Vector3.new(3.0100, 3.8700, 0.8600), glow = Color3.fromHex("#FFE2A0") },
		},
	},
}
