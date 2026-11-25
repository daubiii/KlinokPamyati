-- Сгенерировано export_weapons_floors.py 4. Меши оружия этажа 4: MeshPart из weapons_floor4.glb.
-- offset/size — в стадах относительно хвата (Attachment Grip у Root). Клинок по +Y.
-- Сборщик AssembleWeaponsFloors345.lua кладёт импортированные меши в ReplicatedStorage.WeaponMeshes;
-- VoxelWeaponBuilder строит модель из них, а без них — по-старому из вокселей.
return {
	cast_cleaver = {
		scale = 1.0, rarity = "common",
		bladeBase = 0.812, bladeTip = 3.438, bottom = -0.938,
		aura = { offset = Vector3.new(0.0000, 2.1250, 0.0000), size = Vector3.new(1.2500, 2.6250, 0.5000) },
		objects = {
			{ name = "W_cast_cleaver", role = "mesh", offset = Vector3.new(0.0000, 1.2500, 0.0000), size = Vector3.new(1.2500, 4.3750, 0.5000) },
		},
	},
	quench_blade = {
		scale = 0.86, rarity = "rare",
		bladeBase = 0.699, bladeTip = 4.354, bottom = -0.914,
		aura = { offset = Vector3.new(0.0000, 2.5263, -0.0537), size = Vector3.new(1.0750, 3.6550, 0.3225) },
		objects = {
			{ name = "W_quench_blade", role = "mesh", offset = Vector3.new(0.0000, 1.7200, 0.0000), size = Vector3.new(1.0750, 5.2675, 0.4300) },
		},
	},
	apprentice_hammer = {
		scale = 0.9, rarity = "rare",
		bladeBase = 2.194, bladeTip = 3.094, bottom = -1.294,
		aura = { offset = Vector3.new(0.0000, 2.6437, 0.0000), size = Vector3.new(2.2500, 0.9000, 0.9000) },
		objects = {
			{ name = "W_apprentice_hammer", role = "mesh", offset = Vector3.new(0.0000, 0.9000, 0.0000), size = Vector3.new(2.2500, 4.3875, 0.9000) },
		},
	},
	crucible_maul = {
		scale = 0.82, rarity = "epic",
		bladeBase = 1.999, bladeTip = 3.536, bottom = -1.281,
		aura = { offset = Vector3.new(0.0000, 2.7675, 0.0000), size = Vector3.new(1.6400, 1.5375, 1.4350) },
		objects = {
			{ name = "W_crucible_maul", role = "mesh", offset = Vector3.new(0.0000, 1.1275, 0.0000), size = Vector3.new(1.6400, 4.8175, 1.4350) },
			{ name = "G1_crucible_maul", role = "glow", offset = Vector3.new(-0.0512, 3.1262, 0.0000), size = Vector3.new(1.3325, 0.6150, 1.4350), glow = Color3.fromHex("#FF7A2B") },
			{ name = "G2_crucible_maul", role = "glow", offset = Vector3.new(-0.0512, 3.0750, 0.0000), size = Vector3.new(1.3325, 0.7175, 1.4350), glow = Color3.fromHex("#FFC857") },
			{ name = "G3_crucible_maul", role = "glow", offset = Vector3.new(0.0000, 3.3825, 0.0000), size = Vector3.new(0.4100, 0.1025, 0.4100), glow = Color3.fromHex("#FFF1C2") },
		},
	},
	searing_blade = {
		scale = 0.82, rarity = "epic",
		bladeBase = 0.666, bladeTip = 4.151, bottom = -0.769,
		aura = { offset = Vector3.new(0.0000, 2.4087, 0.0000), size = Vector3.new(1.2300, 3.4850, 0.6150) },
		objects = {
			{ name = "W_searing_blade", role = "mesh", offset = Vector3.new(0.0000, 1.6913, 0.0000), size = Vector3.new(1.2300, 4.9200, 0.6150) },
			{ name = "G1_searing_blade", role = "glow", offset = Vector3.new(0.1537, 2.4600, -0.1025), size = Vector3.new(0.5125, 1.3325, 0.2050), glow = Color3.fromHex("#FF7A2B") },
			{ name = "G2_searing_blade", role = "glow", offset = Vector3.new(0.0512, 3.4850, 0.0000), size = Vector3.new(0.7175, 1.3325, 0.4100), glow = Color3.fromHex("#FFC857") },
			{ name = "G3_searing_blade", role = "glow", offset = Vector3.new(0.0000, 3.7412, 0.0000), size = Vector3.new(0.4100, 0.4100, 0.4100), glow = Color3.fromHex("#FFF1C2") },
		},
	},
	anvil_hammer = {
		scale = 0.84, rarity = "legendary",
		bladeBase = 2.152, bladeTip = 4.357, bottom = -1.417,
		aura = { offset = Vector3.new(0.4725, 3.2550, 0.0000), size = Vector3.new(3.8850, 2.2050, 1.4700) },
		objects = {
			{ name = "W_anvil_hammer", role = "mesh", offset = Vector3.new(0.4725, 1.3650, -0.0525), size = Vector3.new(3.8850, 5.5650, 1.3650) },
			{ name = "G1_anvil_hammer", role = "glow", offset = Vector3.new(0.4725, 2.8350, -0.0525), size = Vector3.new(3.6750, 1.9950, 1.3650), glow = Color3.fromHex("#FF7A2B") },
			{ name = "G2_anvil_hammer", role = "glow", offset = Vector3.new(0.4725, 2.9925, 0.0000), size = Vector3.new(3.6750, 2.5200, 1.4700), glow = Color3.fromHex("#FFC857") },
			{ name = "G3_anvil_hammer", role = "glow", offset = Vector3.new(0.0525, 3.8850, 0.0000), size = Vector3.new(1.5750, 0.9450, 1.2600), glow = Color3.fromHex("#FFF1C2") },
		},
	},
	forge_heart_blade = {
		scale = 0.84, rarity = "legendary",
		bladeBase = 1.312, bladeTip = 5.723, bottom = -0.997,
		aura = { offset = Vector3.new(0.0000, 3.5175, -0.0525), size = Vector3.new(2.1000, 4.4100, 0.3150) },
		objects = {
			{ name = "W_forge_heart_blade", role = "mesh", offset = Vector3.new(0.0000, 2.3625, -0.0525), size = Vector3.new(2.3100, 6.7200, 1.1550) },
			{ name = "G1_forge_heart_blade", role = "glow", offset = Vector3.new(0.0000, 2.9925, 0.0000), size = Vector3.new(1.0500, 5.2500, 0.6300), glow = Color3.fromHex("#FF7A2B") },
			{ name = "G2_forge_heart_blade", role = "glow", offset = Vector3.new(0.2625, 3.3075, -0.0525), size = Vector3.new(1.5750, 4.2000, 0.3150), glow = Color3.fromHex("#FFC857") },
			{ name = "G3_forge_heart_blade", role = "glow", offset = Vector3.new(0.0000, 2.9925, 0.0000), size = Vector3.new(0.4200, 4.8300, 0.4200), glow = Color3.fromHex("#FFF1C2") },
		},
	},
	slag_scythe = {
		scale = 0.82, rarity = "legendary",
		bladeBase = 4.869, bladeTip = 5.996, bottom = -1.179,
		aura = { offset = Vector3.new(-1.0250, 5.4325, 0.0000), size = Vector3.new(2.6650, 1.1275, 0.8200) },
		objects = {
			{ name = "W_slag_scythe", role = "mesh", offset = Vector3.new(-1.5375, 2.4087, 0.0000), size = Vector3.new(4.1000, 7.1750, 0.6150) },
			{ name = "G1_slag_scythe", role = "glow", offset = Vector3.new(-1.8450, 4.5100, 0.0000), size = Vector3.new(3.0750, 1.5375, 0.4100), glow = Color3.fromHex("#FF7A2B") },
			{ name = "G2_slag_scythe", role = "glow", offset = Vector3.new(-1.7425, 4.4075, -0.0512), size = Vector3.new(2.8700, 1.3325, 0.3075), glow = Color3.fromHex("#FFC857") },
			{ name = "G3_slag_scythe", role = "glow", offset = Vector3.new(0.0000, 5.0737, 0.0000), size = Vector3.new(0.2050, 0.2050, 0.8200), glow = Color3.fromHex("#FFF1C2") },
		},
	},
	unfinished_blade = {
		scale = 0.88, rarity = "secret",
		bladeBase = 0.825, bladeTip = 5.995, bottom = -1.375,
		aura = { offset = Vector3.new(0.0000, 3.4100, 0.0000), size = Vector3.new(1.9800, 5.1700, 0.8800) },
		objects = {
			{ name = "W_unfinished_blade", role = "mesh", offset = Vector3.new(0.0000, 3.4100, 0.0000), size = Vector3.new(1.9800, 5.1700, 0.8800) },
			{ name = "G1_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 0.6600, 0.0000), size = Vector3.new(0.6600, 4.0700, 0.6600), glow = Color3.fromHex("#6FE3FF") },
			{ name = "G2_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 3.3550, -0.0550), size = Vector3.new(1.1000, 0.8800, 0.3300), glow = Color3.fromHex("#FF6A1A") },
			{ name = "G3_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 4.2900, -0.0550), size = Vector3.new(0.8800, 0.9900, 0.3300), glow = Color3.fromHex("#FF8A2A") },
			{ name = "G4_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 5.3900, -0.0550), size = Vector3.new(0.6600, 1.2100, 0.3300), glow = Color3.fromHex("#FFA63A") },
			{ name = "G5_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 1.9250, 0.0000), size = Vector3.new(0.8800, 1.9800, 0.6600), glow = Color3.fromHex("#FFB347") },
			{ name = "G6_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 1.3200, -0.0550), size = Vector3.new(1.3200, 0.1100, 0.1100), glow = Color3.fromHex("#FFF1C2") },
		},
	},
}
