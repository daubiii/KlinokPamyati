-- Сгенерировано tools/mage-armor/export_mage.py. Не править руками: правки — в генераторе (mage_sets.py).
-- Броня мага из мешей (mage_armor.glb): шляпы (слот helm) и накидки (слот armor) с плащами.
-- Формат как у HeroArmorMeshData: offset/size — в стадах в осях части тела R15 (X вправо, Y вверх,
-- перед −Z) при Part.Size.Y = refY. HeroArmorBuilder подмешивает эти комплекты к броне воина.
-- Ноги, кисти и большая часть рук не закрыты — виден основной облик героя (body).
return {
	voxel = 0.1250,
	sets = {
		novice = {
			rarity = "common",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_novice_Hat", part = "Head", offset = Vector3.new(0.0000, 0.7500, 0.0000), size = Vector3.new(2.2500, 2.0000, 2.2500) },
				{ name = "HG_novice_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_novice_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5625, 0.0625), size = Vector3.new(2.2500, 0.8750, 1.6250) },
				{ name = "HA_novice_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_novice_WrapR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3750, 0.0000), size = Vector3.new(1.2500, 0.2500, 1.2500) },
				{ name = "HA_novice_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_novice_WrapL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3750, 0.0000), size = Vector3.new(1.2500, 0.2500, 1.2500) },
				{ name = "HA_novice_Belt", part = "LowerTorso", offset = Vector3.new(0.0625, -0.1250, 0.0000), size = Vector3.new(2.3750, 0.5000, 1.5000) },
			},
			cape = {
				{ name = "HA_novice_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.7000, 0.7500), glows = {
				} },
				{ name = "HA_novice_Cape2", offset = Vector3.new(0.0000, -0.1875, 0.7500), size = Vector3.new(2.0000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.1000, 0.7500), glows = {
				} },
			},
		},
		reader = {
			rarity = "common",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_reader_Hat", part = "Head", offset = Vector3.new(0.0000, 0.8750, 0.0000), size = Vector3.new(2.0000, 2.2500, 2.0000) },
				{ name = "HG_reader_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_reader_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.3125, -0.0625), size = Vector3.new(2.2500, 1.3750, 1.6250) },
				{ name = "HA_reader_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.5000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_reader_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3750, 0.0000), size = Vector3.new(1.2500, 0.2500, 1.2500) },
				{ name = "HA_reader_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.5000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_reader_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3750, 0.0000), size = Vector3.new(1.2500, 0.2500, 1.2500) },
				{ name = "HA_reader_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(2.5000, 0.6250, 1.2500) },
			},
			cape = {
				{ name = "HA_reader_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.7500), size = Vector3.new(1.5000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.7400, 0.7500), glows = {
				} },
				{ name = "HA_reader_Cape2", offset = Vector3.new(0.0000, -0.1250, 0.7500), size = Vector3.new(1.5000, 0.5000, 0.2500), hinge = Vector3.new(0.0000, 0.1767, 0.7500), glows = {
				} },
				{ name = "HA_reader_Cape3", offset = Vector3.new(0.0000, -0.6250, 0.7500), size = Vector3.new(1.5000, 0.5000, 0.2500), hinge = Vector3.new(0.0000, -0.3867, 0.7500), glows = {
				} },
			},
		},
		chronicler = {
			rarity = "rare",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_chronicler_Hat", part = "Head", offset = Vector3.new(0.0000, 0.8750, 0.0000), size = Vector3.new(2.5000, 2.2500, 2.5000) },
				{ name = "HG_chronicler_Hat_1", part = "Head", offset = Vector3.new(0.1250, 0.4375, 0.0000), size = Vector3.new(2.2500, 0.8750, 2.5000), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_chronicler_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5625, 0.0000), size = Vector3.new(2.2500, 1.1250, 1.5000) },
				{ name = "HG_chronicler_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, -0.8125), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HA_chronicler_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.3750, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_chronicler_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.5000, 0.3750, 1.5000) },
				{ name = "HA_chronicler_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.3750, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_chronicler_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.5000, 0.3750, 1.5000) },
				{ name = "HA_chronicler_Belt", part = "LowerTorso", offset = Vector3.new(-0.0625, -0.2500, -0.0625), size = Vector3.new(2.3750, 0.7500, 1.3750) },
				{ name = "HG_chronicler_Belt_1", part = "LowerTorso", offset = Vector3.new(-1.3125, -0.3125, 0.0625), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			cape = {
				{ name = "HA_chronicler_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.7500), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.7600, 0.7500), glows = {
				} },
				{ name = "HA_chronicler_Cape2", offset = Vector3.new(0.0000, -0.3125, 0.7500), size = Vector3.new(2.0000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.0450, 0.7500), glows = {
					{ name = "HG_chronicler_Cape2_1", offset = Vector3.new(-0.8125, -0.3125, 0.6875), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				} },
				{ name = "HA_chronicler_Cape3", offset = Vector3.new(0.0000, -1.0000, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -0.6700, 0.7500), glows = {
					{ name = "HG_chronicler_Cape3_1", offset = Vector3.new(-0.3750, -1.0000, 0.7500), size = Vector3.new(0.7500, 0.7500, 0.2500), glow = Color3.fromRGB(111, 227, 255) },
				} },
				{ name = "HA_chronicler_Cape4", offset = Vector3.new(0.0000, -1.7500, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -1.3850, 0.7500), glows = {
					{ name = "HG_chronicler_Cape4_1", offset = Vector3.new(-0.2500, -1.5000, 0.7500), size = Vector3.new(0.5000, 0.2500, 0.2500), glow = Color3.fromRGB(111, 227, 255) },
				} },
			},
		},
		oblivion = {
			rarity = "epic",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_oblivion_Hat", part = "Head", offset = Vector3.new(0.0625, 0.6875, 0.0000), size = Vector3.new(2.6250, 1.8750, 2.5000) },
				{ name = "HG_oblivion_Hat_1", part = "Head", offset = Vector3.new(-0.0625, 0.6875, 0.0625), size = Vector3.new(1.6250, 1.3750, 1.6250), glow = Color3.fromRGB(180, 140, 255) },
			},
			armor = {
				{ name = "HA_oblivion_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5000, 0.0625), size = Vector3.new(2.2500, 1.2500, 1.6250) },
				{ name = "HG_oblivion_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.0625, 0.5625, -0.8125), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(180, 140, 255) },
				{ name = "HA_oblivion_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.3750, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_oblivion_WrapR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HG_oblivion_WrapR_1", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.1250, 1.2500), glow = Color3.fromRGB(180, 140, 255) },
				{ name = "HA_oblivion_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.3750, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_oblivion_WrapL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HG_oblivion_WrapL_1", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.1250, 1.2500), glow = Color3.fromRGB(180, 140, 255) },
				{ name = "HA_oblivion_Belt", part = "LowerTorso", offset = Vector3.new(-0.0625, -0.2500, -0.0625), size = Vector3.new(2.3750, 0.7500, 1.3750) },
				{ name = "HG_oblivion_Belt_1", part = "LowerTorso", offset = Vector3.new(-1.1875, -0.3750, 0.0000), size = Vector3.new(0.1250, 0.2500, 0.2500), glow = Color3.fromRGB(180, 140, 255) },
			},
			cape = {
				{ name = "HA_oblivion_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.7800, 0.8125), glows = {
				} },
				{ name = "HA_oblivion_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0225, 0.7500), glows = {
				} },
				{ name = "HA_oblivion_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -0.7350, 0.8125), glows = {
					{ name = "HG_oblivion_Cape3_1", offset = Vector3.new(0.0000, -1.3750, 0.8125), size = Vector3.new(1.2500, 0.2500, 0.1250), glow = Color3.fromRGB(180, 140, 255) },
				} },
				{ name = "HA_oblivion_Cape4", offset = Vector3.new(0.0000, -1.8125, 0.8125), size = Vector3.new(2.2500, 0.6250, 0.3750), hinge = Vector3.new(0.0000, -1.4925, 0.8125), glows = {
					{ name = "HG_oblivion_Cape4_1", offset = Vector3.new(0.0000, -1.6875, 0.8125), size = Vector3.new(1.2500, 0.3750, 0.3750), glow = Color3.fromRGB(180, 140, 255) },
				} },
			},
		},
		archivist = {
			rarity = "legendary",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_archivist_Hat", part = "Head", offset = Vector3.new(0.0000, 0.8750, 0.0000), size = Vector3.new(2.2500, 2.2500, 2.2500) },
				{ name = "HG_archivist_Hat_1", part = "Head", offset = Vector3.new(0.0000, 1.1250, -0.0625), size = Vector3.new(1.2500, 2.2500, 1.3750), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_archivist_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0625), size = Vector3.new(2.2500, 1.2500, 1.6250) },
				{ name = "HG_archivist_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.1875, 0.3750, -0.1250), size = Vector3.new(0.6250, 0.5000, 1.5000), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HA_archivist_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0625, 0.5625, 0.0000), size = Vector3.new(1.3750, 0.6250, 1.2500) },
				{ name = "HG_archivist_ShoulderR_1", part = "RightUpperArm", offset = Vector3.new(0.0625, 0.8125, 0.0000), size = Vector3.new(0.6250, 0.1250, 1.2500), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HA_archivist_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.5000, 0.3750, 1.5000) },
				{ name = "HG_archivist_CuffR_1", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1875, -0.0625), size = Vector3.new(1.2500, 0.1250, 1.1250), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HA_archivist_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(-0.0625, 0.5625, 0.0000), size = Vector3.new(1.3750, 0.6250, 1.2500) },
				{ name = "HG_archivist_ShoulderL_1", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.8125, 0.0000), size = Vector3.new(0.5000, 0.1250, 1.2500), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HA_archivist_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.5000, 0.3750, 1.5000) },
				{ name = "HG_archivist_CuffL_1", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1875, -0.0625), size = Vector3.new(1.2500, 0.1250, 1.1250), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HA_archivist_Belt", part = "LowerTorso", offset = Vector3.new(0.0625, -0.1250, 0.0625), size = Vector3.new(2.3750, 1.0000, 1.6250) },
				{ name = "HG_archivist_Belt_1", part = "LowerTorso", offset = Vector3.new(1.3125, -0.3125, 0.0625), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			cape = {
				{ name = "HA_archivist_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.7800, 0.8125), glows = {
					{ name = "HG_archivist_Cape1_1", offset = Vector3.new(0.0000, 0.1875, 0.8125), size = Vector3.new(0.2500, 0.3750, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				} },
				{ name = "HA_archivist_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0225, 0.7500), glows = {
					{ name = "HG_archivist_Cape2_1", offset = Vector3.new(0.0000, -0.3750, 0.8125), size = Vector3.new(0.2500, 0.7500, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				} },
				{ name = "HA_archivist_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -0.7350, 0.8125), glows = {
					{ name = "HG_archivist_Cape3_1", offset = Vector3.new(0.0000, -1.0625, 0.8125), size = Vector3.new(0.2500, 0.6250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				} },
				{ name = "HA_archivist_Cape4", offset = Vector3.new(0.0000, -1.8750, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -1.4925, 0.8125), glows = {
				} },
			},
		},
	},
}
