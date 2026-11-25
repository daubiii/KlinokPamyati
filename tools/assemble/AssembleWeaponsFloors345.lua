-- СГЕНЕРИРОВАНО tools/make-assemble.js
-- Оригинал требует модуль конфига через require; в потоке MCP это запрещено
-- (Capabilities: Network), поэтому исходник модуля встроен и грузится loadstring.

local __RAW = {
	[3] = [=[
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

]=],
	[4] = [=[
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
			{ name = "W_unfinished_blade", role = "mesh", offset = Vector3.new(0.0000, 0.9350, 0.0000), size = Vector3.new(1.9800, 3.7400, 0.8800) },
			{ name = "G1_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 0.6600, 0.0000), size = Vector3.new(0.6600, 4.0700, 0.6600), glow = Color3.fromHex("#6FE3FF") },
			{ name = "G2_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 3.3550, -0.0550), size = Vector3.new(1.1000, 0.8800, 0.3300), glow = Color3.fromHex("#FF6A1A") },
			{ name = "G3_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 4.2900, -0.0550), size = Vector3.new(0.8800, 0.9900, 0.3300), glow = Color3.fromHex("#FF8A2A") },
			{ name = "G4_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 5.3900, -0.0550), size = Vector3.new(0.6600, 1.2100, 0.3300), glow = Color3.fromHex("#FFA63A") },
			{ name = "G5_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 1.9250, 0.0000), size = Vector3.new(0.8800, 1.9800, 0.6600), glow = Color3.fromHex("#FFB347") },
			{ name = "G6_unfinished_blade", role = "glow", offset = Vector3.new(0.0000, 1.3200, -0.0550), size = Vector3.new(1.3200, 0.1100, 0.1100), glow = Color3.fromHex("#FFF1C2") },
		},
	},
}

]=],
	[5] = [=[
-- Сгенерировано export_weapons_floors.py 5. Меши оружия этажа 5: MeshPart из weapons_floor5.glb.
-- offset/size — в стадах относительно хвата (Attachment Grip у Root). Клинок по +Y.
-- Сборщик AssembleWeaponsFloors345.lua кладёт импортированные меши в ReplicatedStorage.WeaponMeshes;
-- VoxelWeaponBuilder строит модель из них, а без них — по-старому из вокселей.
return {
	paper_knife = {
		scale = 1.0, rarity = "common",
		bladeBase = 0.812, bladeTip = 4.062, bottom = -0.938,
		aura = { offset = Vector3.new(0.0000, 2.4375, 0.0000), size = Vector3.new(0.7500, 3.2500, 0.2500) },
		objects = {
			{ name = "W_paper_knife", role = "mesh", offset = Vector3.new(0.0000, 1.5625, 0.0000), size = Vector3.new(0.7500, 5.0000, 0.5000) },
		},
	},
	tome_hammer = {
		scale = 0.86, rarity = "rare",
		bladeBase = 2.096, bladeTip = 3.386, bottom = -1.236,
		aura = { offset = Vector3.new(0.0000, 2.7412, 0.0000), size = Vector3.new(1.7200, 1.2900, 1.0750) },
		objects = {
			{ name = "W_tome_hammer", role = "mesh", offset = Vector3.new(0.0000, 1.0750, 0.0000), size = Vector3.new(1.7200, 4.6225, 1.0750) },
			{ name = "G1_tome_hammer", role = "glow", offset = Vector3.new(0.0537, 2.6875, 0.4838), size = Vector3.new(0.1075, 0.1075, 0.1075), glow = Color3.fromHex("#B49CFF") },
		},
	},
	bookmark_blade = {
		scale = 0.86, rarity = "rare",
		bladeBase = 0.054, bladeTip = 4.139, bottom = -1.021,
		aura = { offset = Vector3.new(-0.0538, 2.0962, 0.0000), size = Vector3.new(1.1825, 4.0850, 0.4300) },
		objects = {
			{ name = "W_bookmark_blade", role = "mesh", offset = Vector3.new(-0.1075, 1.5587, 0.0000), size = Vector3.new(1.2900, 5.1600, 0.4300) },
		},
	},
	quill_blade = {
		scale = 0.84, rarity = "epic",
		bladeBase = 0.787, bladeTip = 4.462, bottom = -0.892,
		aura = { offset = Vector3.new(0.0525, 2.6250, 0.0000), size = Vector3.new(1.1550, 3.6750, 0.4200) },
		objects = {
			{ name = "W_quill_blade", role = "mesh", offset = Vector3.new(0.0000, 1.7850, 0.0000), size = Vector3.new(1.0500, 5.3550, 0.4200) },
			{ name = "G1_quill_blade", role = "glow", offset = Vector3.new(0.0000, 2.7300, 0.0000), size = Vector3.new(0.2100, 3.2550, 0.4200), glow = Color3.fromHex("#9B7BFF") },
			{ name = "G2_quill_blade", role = "glow", offset = Vector3.new(0.5775, 1.8900, 0.0525), size = Vector3.new(0.1050, 0.1050, 0.1050), glow = Color3.fromHex("#B49CFF") },
		},
	},
	seal_hammer = {
		scale = 0.84, rarity = "epic",
		bladeBase = 2.152, bladeTip = 2.992, bottom = -1.208,
		aura = { offset = Vector3.new(-0.1050, 2.5725, 0.0000), size = Vector3.new(2.1000, 0.8400, 0.8400) },
		objects = {
			{ name = "W_seal_hammer", role = "mesh", offset = Vector3.new(-0.1050, 0.8925, 0.0000), size = Vector3.new(2.1000, 4.2000, 0.8400) },
			{ name = "G1_seal_hammer", role = "glow", offset = Vector3.new(0.8925, 2.5725, 0.0000), size = Vector3.new(0.1050, 0.6300, 0.6300), glow = Color3.fromHex("#9B7BFF") },
			{ name = "G2_seal_hammer", role = "glow", offset = Vector3.new(0.8925, 2.6250, 0.0000), size = Vector3.new(0.1050, 0.5250, 0.4200), glow = Color3.fromHex("#B49CFF") },
		},
	},
	hourglass_maul = {
		scale = 0.86, rarity = "legendary",
		bladeBase = 1.989, bladeTip = 3.709, bottom = -1.129,
		aura = { offset = Vector3.new(0.0000, 2.8487, 0.0000), size = Vector3.new(2.7950, 1.7200, 1.9350) },
		objects = {
			{ name = "W_hourglass_maul", role = "mesh", offset = Vector3.new(0.0000, 1.2363, -0.0538), size = Vector3.new(2.7950, 4.7300, 1.8275) },
			{ name = "G1_hourglass_maul", role = "glow", offset = Vector3.new(0.0000, 2.7412, 0.0000), size = Vector3.new(0.2150, 1.9350, 1.9350), glow = Color3.fromHex("#9B7BFF") },
			{ name = "G2_hourglass_maul", role = "glow", offset = Vector3.new(0.0000, 2.7412, 0.0000), size = Vector3.new(2.7950, 1.0750, 1.0750), glow = Color3.fromHex("#B49CFF") },
			{ name = "G3_hourglass_maul", role = "glow", offset = Vector3.new(0.0000, 2.6875, -0.0537), size = Vector3.new(2.7950, 0.1075, 0.1075), glow = Color3.fromHex("#F2F6FF") },
			{ name = "G4_hourglass_maul", role = "glow", offset = Vector3.new(0.0000, 2.6338, 0.0000), size = Vector3.new(2.1500, 0.6450, 0.8600), glow = Color3.fromHex("#FFD98A") },
		},
	},
	ink_blade = {
		scale = 0.84, rarity = "legendary",
		bladeBase = 0.787, bladeTip = 5.513, bottom = -0.997,
		aura = { offset = Vector3.new(-0.1575, 3.1500, 0.0000), size = Vector3.new(1.1550, 4.7250, 0.4200) },
		objects = {
			{ name = "W_ink_blade", role = "mesh", offset = Vector3.new(-0.1050, 2.2575, 0.0000), size = Vector3.new(1.2600, 6.5100, 0.6300) },
			{ name = "G1_ink_blade", role = "glow", offset = Vector3.new(0.0000, 2.2050, -0.0525), size = Vector3.new(0.4200, 6.1950, 0.3150), glow = Color3.fromHex("#9B7BFF") },
			{ name = "G2_ink_blade", role = "glow", offset = Vector3.new(-0.1050, 3.1500, -0.0525), size = Vector3.new(0.6300, 4.5150, 0.3150), glow = Color3.fromHex("#B49CFF") },
			{ name = "G3_ink_blade", role = "glow", offset = Vector3.new(0.1575, 3.1500, -0.0525), size = Vector3.new(0.5250, 4.5150, 0.1050), glow = Color3.fromHex("#F2F6FF") },
		},
	},
	oblivion_scythe = {
		scale = 0.82, rarity = "legendary",
		bladeBase = 4.869, bladeTip = 5.689, bottom = -1.179,
		aura = { offset = Vector3.new(-0.6150, 5.2787, 0.0000), size = Vector3.new(3.0750, 0.8200, 0.6150) },
		objects = {
			{ name = "W_oblivion_scythe", role = "mesh", offset = Vector3.new(-1.3838, 2.2550, 0.0000), size = Vector3.new(4.6125, 6.8675, 0.6150) },
			{ name = "G1_oblivion_scythe", role = "glow", offset = Vector3.new(-1.6400, 4.5100, 0.0000), size = Vector3.new(2.8700, 1.1275, 0.4100), glow = Color3.fromHex("#9B7BFF") },
			{ name = "G2_oblivion_scythe", role = "glow", offset = Vector3.new(0.5637, 5.2787, 0.0000), size = Vector3.new(0.7175, 0.6150, 0.2050), glow = Color3.fromHex("#B49CFF") },
			{ name = "G3_oblivion_scythe", role = "glow", offset = Vector3.new(-1.6400, 4.2537, 0.0000), size = Vector3.new(2.8700, 0.8200, 0.2050), glow = Color3.fromHex("#B8E3FF") },
		},
	},
	memory_blade = {
		scale = 0.84, rarity = "secret",
		bladeBase = 0.892, bladeTip = 5.933, bottom = -1.312,
		aura = { offset = Vector3.new(0.0000, 3.4125, 0.0000), size = Vector3.new(1.8900, 5.0400, 0.4200) },
		objects = {
			{ name = "W_memory_blade", role = "mesh", offset = Vector3.new(0.0000, 2.3100, 0.0000), size = Vector3.new(1.8900, 7.2450, 0.4200) },
			{ name = "G1_memory_blade", role = "glow", offset = Vector3.new(-0.0525, 2.1525, 0.0000), size = Vector3.new(1.5750, 6.9300, 0.4200), glow = Color3.fromHex("#6FE3FF") },
			{ name = "G2_memory_blade", role = "glow", offset = Vector3.new(-0.0525, 1.1025, 0.0000), size = Vector3.new(0.7350, 0.6300, 0.4200), glow = Color3.fromHex("#B49CFF") },
			{ name = "G3_memory_blade", role = "glow", offset = Vector3.new(-0.0525, 2.6775, 0.0000), size = Vector3.new(1.7850, 5.6700, 0.4200), glow = Color3.fromHex("#D6F8FF") },
		},
	},
}

]=],
}
local __FLOOR_DATA = {}
for __floor, __src in pairs(__RAW) do
	local __ok, __data = pcall(loadstring, __src, "WeaponMeshDataFloor" .. __floor)
	if __ok and type(__data) == "function" then
		local __ran, __result = pcall(__data)
		if __ran then
			__FLOOR_DATA[__floor] = __result
		end
	end
end

--[[
	AssembleWeaponsFloors345 — меши оружия этажей 3, 4, 5 → ReplicatedStorage.WeaponMeshes.
	Запускает Артём сам: Studio, Command Bar, режим Edit (НЕ во время Play).
	Повторный запуск безопасен; можно импортировать и собрать этажи по одному.

	До запуска:
	1. ReplicatedStorage.Shared.Config.WeaponMeshDataFloor3/4/5 — пришли из src через Rojo.
	2. File → Import 3D → weapons_floor3.glb, weapons_floor4.glb, weapons_floor5.glb (настройки не менять).
	   В Workspace появятся модели weapons_floor3 / weapons_floor4 / weapons_floor5:
	   W_<оружие> (с палитрой) у каждого оружия + G1_…G5_<оружие> (свечение) у эпиков, легендарок и секреток.

	Что делает: переносит MeshPart в ReplicatedStorage.WeaponMeshes, ставит размер из данных,
	отключает коллизии; у свечения убирает текстуру (цвет и Neon ставит VoxelWeaponBuilder).
	Пустые модели импорта удаляет. После — Ctrl+S: папка живёт только в файле места.
]]
local RS = game:GetService("ReplicatedStorage")
local Config = RS.Shared.Config

local folder = RS:FindFirstChild("WeaponMeshes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WeaponMeshes"
	folder.Parent = RS
end
if folder:GetAttribute("ImportYaw") == nil then
	folder:SetAttribute("ImportYaw", 0)
end

local function findMesh(roots, name: string): MeshPart?
	for _, root in ipairs(roots) do
		local fallback = nil
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("MeshPart") then
				if d.Name == name then
					return d
				end
				-- Импортер иногда дописывает имя материала: "W_paper_knife_palette".
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

local grand = { placed = 0, total = 0, missing = 0 }
for floor = 3, 5 do
	local module = Config:FindFirstChild("WeaponMeshDataFloor" .. floor)
	if not module then
		warn(("[AssembleWeaponsFloors345] нет модуля WeaponMeshDataFloor%d — этаж пропущен"):format(floor))
		continue
	end
	local DATA = __FLOOR_DATA[floor]
	local source = workspace:FindFirstChild("weapons_floor" .. floor)
	local roots = { folder }
	if source then
		table.insert(roots, 1, source)
	end
	local placed, missing, total = 0, 0, 0
	for weaponId, weapon in pairs(DATA) do
		for _, o in ipairs(weapon.objects) do
			total += 1
			local mp = findMesh(roots, o.name)
			if not mp then
				missing += 1
				warn(("[AssembleWeaponsFloors345] этаж %d, %s: нет MeshPart %s"):format(floor, weaponId, o.name))
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
	if source then
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
	print(("[AssembleWeaponsFloors345] этаж %d: %d из %d MeshPart, не найдено %d%s"):format(
		floor, placed, total, missing, source and "" or " (модели импорта weapons_floor" .. floor .. " нет — взяты уже лежащие в WeaponMeshes)"))
	grand.placed += placed
	grand.total += total
	grand.missing += missing
end
print(("[AssembleWeaponsFloors345] готово: %d из %d, не найдено %d. Сохраните место (Ctrl+S)."):format(grand.placed, grand.total, grand.missing))
