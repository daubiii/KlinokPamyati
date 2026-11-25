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
