-- Сгенерировано tools/armor-floors/export_floors.py. Не править руками: правки — в генераторе (floor_sets.py).
-- Броня этажей 2–5 из мешей (armor_floor<N>.glb): воин — шлем (helm) и латы (armor) с плащом,
-- маг — шляпа (helm) и накидка (armor) с плащом. Формат как у HeroArmorMeshData: offset/size — в стадах
-- в осях части тела R15 (X вправо, Y вверх, перед −Z) при Part.Size.Y = refY.
-- HeroArmorBuilder подмешивает эти комплекты к броне этажа 1.
return {
	voxel = 0.1250,
	sets = {
		gardener = {
			rarity = "common",
			floor = 2,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_gardener_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1875, 0.0000), size = Vector3.new(2.5000, 1.3750, 2.5000) },
				{ name = "HG_gardener_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_gardener_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, 0.0625), size = Vector3.new(2.2500, 1.7500, 1.3750) },
				{ name = "HA_gardener_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.1250, 0.2500, 0.0000), size = Vector3.new(1.5000, 1.0000, 1.5000) },
				{ name = "HA_gardener_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_gardener_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_gardener_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.1250, 0.2500, 0.0000), size = Vector3.new(1.5000, 1.0000, 1.5000) },
				{ name = "HA_gardener_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_gardener_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_gardener_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3125, -0.0625), size = Vector3.new(2.2500, 0.8750, 1.3750) },
				{ name = "HA_gardener_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.1875, -0.2500), size = Vector3.new(1.2500, 0.6250, 0.7500) },
				{ name = "HA_gardener_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_gardener_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0000, -0.1250), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_gardener_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.1875, -0.2500), size = Vector3.new(1.2500, 0.6250, 0.7500) },
				{ name = "HA_gardener_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_gardener_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0000, -0.1250), size = Vector3.new(1.2500, 0.5000, 1.2500) },
			},
			cape = {
			},
		},
		sluice_guard = {
			rarity = "rare",
			floor = 2,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_sluice_guard_Helm", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.0625), size = Vector3.new(2.0000, 1.3750, 2.1250) },
				{ name = "HG_sluice_guard_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.5625), size = Vector3.new(0.7500, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_sluice_guard_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, 0.0000), size = Vector3.new(2.2500, 1.7500, 1.5000) },
				{ name = "HA_sluice_guard_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_sluice_guard_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_sluice_guard_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_sluice_guard_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_sluice_guard_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_sluice_guard_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_sluice_guard_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(2.2500, 0.8750, 1.5000) },
				{ name = "HA_sluice_guard_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.8750, 0.8750) },
				{ name = "HA_sluice_guard_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_sluice_guard_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0625, -0.1250), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_sluice_guard_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.8750, 0.8750) },
				{ name = "HA_sluice_guard_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_sluice_guard_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0625, -0.1250), size = Vector3.new(1.2500, 0.6250, 1.2500) },
			},
			cape = {
				{ name = "HA_sluice_guard_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.8125), size = Vector3.new(1.7500, 0.6250, 0.1250), hinge = Vector3.new(0.0000, 0.7400, 0.8125), glows = {
				} },
				{ name = "HA_sluice_guard_Cape2", offset = Vector3.new(0.0000, -0.1875, 0.8125), size = Vector3.new(1.7500, 0.6250, 0.1250), hinge = Vector3.new(0.0000, 0.0933, 0.8125), glows = {
				} },
				{ name = "HA_sluice_guard_Cape3", offset = Vector3.new(0.0000, -0.8750, 0.8750), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -0.5533, 0.8750), glows = {
				} },
			},
		},
		thorn_knight = {
			rarity = "epic",
			floor = 2,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_thorn_knight_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1250, -0.1250), size = Vector3.new(2.0000, 1.7500, 1.7500) },
				{ name = "HG_thorn_knight_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.7500, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_thorn_knight_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(2.5000, 1.7500, 1.6250) },
				{ name = "HG_thorn_knight_Chest_1", part = "UpperTorso", offset = Vector3.new(-0.0625, 0.0625, -0.0625), size = Vector3.new(2.3750, 0.6250, 0.3750), glow = Color3.fromRGB(255, 122, 154) },
				{ name = "HA_thorn_knight_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.2500, 0.1875, 0.0000), size = Vector3.new(1.7500, 1.6250, 2.0000) },
				{ name = "HA_thorn_knight_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_thorn_knight_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_thorn_knight_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.2500, 0.1875, 0.0000), size = Vector3.new(1.7500, 1.6250, 2.0000) },
				{ name = "HA_thorn_knight_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_thorn_knight_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_thorn_knight_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(2.2500, 0.8750, 1.5000) },
				{ name = "HA_thorn_knight_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_thorn_knight_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_thorn_knight_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_thorn_knight_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_thorn_knight_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_thorn_knight_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 0.5000, 1.3750) },
			},
			cape = {
				{ name = "HA_thorn_knight_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.8125), size = Vector3.new(2.0000, 0.6250, 0.1250), hinge = Vector3.new(0.0000, 0.7600, 0.8125), glows = {
				} },
				{ name = "HA_thorn_knight_Cape2", offset = Vector3.new(0.0000, -0.2500, 0.7500), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0950, 0.7500), glows = {
				} },
				{ name = "HA_thorn_knight_Cape3", offset = Vector3.new(0.0625, -0.9375, 0.8125), size = Vector3.new(2.1250, 0.6250, 0.3750), hinge = Vector3.new(0.0000, -0.5700, 0.8125), glows = {
				} },
				{ name = "HA_thorn_knight_Cape4", offset = Vector3.new(0.0625, -1.5000, 0.8125), size = Vector3.new(2.1250, 0.5000, 0.3750), hinge = Vector3.new(0.0000, -1.2350, 0.8125), glows = {
				} },
			},
		},
		rose_warden = {
			rarity = "legendary",
			floor = 2,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_rose_warden_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1250, -0.1250), size = Vector3.new(1.5000, 1.7500, 1.7500) },
				{ name = "HG_rose_warden_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.7500, 0.1250, 0.1250), glow = Color3.fromRGB(95, 208, 192) },
			},
			armor = {
				{ name = "HA_rose_warden_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(2.5000, 1.7500, 1.6250) },
				{ name = "HG_rose_warden_Chest_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6875, -0.3750), size = Vector3.new(2.5000, 0.1250, 0.7500), glow = Color3.fromRGB(95, 208, 192) },
				{ name = "HA_rose_warden_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.2500, 0.1250, 0.0000), size = Vector3.new(1.7500, 1.5000, 2.0000) },
				{ name = "HG_rose_warden_PauldronR_1", part = "RightUpperArm", offset = Vector3.new(0.0625, 0.8125, 0.0000), size = Vector3.new(1.1250, 0.1250, 1.0000), glow = Color3.fromRGB(95, 208, 192) },
				{ name = "HA_rose_warden_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_rose_warden_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_rose_warden_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.2500, 0.1250, 0.0000), size = Vector3.new(1.7500, 1.5000, 2.0000) },
				{ name = "HG_rose_warden_PauldronL_1", part = "LeftUpperArm", offset = Vector3.new(-0.0625, 0.8125, 0.0000), size = Vector3.new(1.1250, 0.1250, 1.0000), glow = Color3.fromRGB(95, 208, 192) },
				{ name = "HA_rose_warden_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_rose_warden_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_rose_warden_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3750, 0.0000), size = Vector3.new(2.2500, 1.0000, 1.5000) },
				{ name = "HA_rose_warden_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_rose_warden_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_rose_warden_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.6250, 1.3750) },
				{ name = "HA_rose_warden_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_rose_warden_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_rose_warden_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.6250, 1.3750) },
			},
			cape = {
				{ name = "HA_rose_warden_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.7800, 0.8125), glows = {
					{ name = "HG_rose_warden_Cape1_1", offset = Vector3.new(0.0000, 0.2500, 0.8125), size = Vector3.new(0.2500, 0.5000, 0.1250), glow = Color3.fromRGB(95, 208, 192) },
				} },
				{ name = "HA_rose_warden_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0350, 0.7500), glows = {
					{ name = "HG_rose_warden_Cape2_1", offset = Vector3.new(0.0000, -0.3750, 0.8125), size = Vector3.new(0.2500, 0.7500, 0.1250), glow = Color3.fromRGB(95, 208, 192) },
				} },
				{ name = "HA_rose_warden_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -0.7100, 0.8125), glows = {
					{ name = "HG_rose_warden_Cape3_1", offset = Vector3.new(0.0000, -1.0000, 0.8125), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(95, 208, 192) },
				} },
				{ name = "HA_rose_warden_Cape4", offset = Vector3.new(0.0000, -1.8125, 0.8125), size = Vector3.new(2.2500, 0.6250, 0.3750), hinge = Vector3.new(0.0000, -1.4550, 0.8125), glows = {
				} },
			},
		},
		herbalist = {
			rarity = "common",
			floor = 2,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_herbalist_Hat", part = "Head", offset = Vector3.new(0.0000, 0.6875, 0.0000), size = Vector3.new(2.2500, 1.8750, 2.2500) },
				{ name = "HG_herbalist_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_herbalist_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5000, -0.0625), size = Vector3.new(2.2500, 0.7500, 1.3750) },
				{ name = "HA_herbalist_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_herbalist_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_herbalist_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_herbalist_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_herbalist_Belt", part = "LowerTorso", offset = Vector3.new(0.0625, -0.1250, -0.0625), size = Vector3.new(2.3750, 0.5000, 1.3750) },
			},
			cape = {
				{ name = "HA_herbalist_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.7500), size = Vector3.new(1.7500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.7000, 0.7500), glows = {
				} },
				{ name = "HA_herbalist_Cape2", offset = Vector3.new(0.0000, -0.3125, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.0500, 0.7500), glows = {
				} },
			},
		},
		dew = {
			rarity = "rare",
			floor = 2,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_dew_Hat", part = "Head", offset = Vector3.new(0.0000, 0.8125, -0.0625), size = Vector3.new(2.0000, 2.1250, 2.1250) },
				{ name = "HG_dew_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_dew_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0625), size = Vector3.new(2.2500, 0.7500, 1.3750) },
				{ name = "HA_dew_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_dew_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_dew_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_dew_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_dew_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(2.2500, 0.2500, 1.2500) },
			},
			cape = {
				{ name = "HA_dew_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.7400, 0.7500), glows = {
					{ name = "HG_dew_Cape1_1", offset = Vector3.new(-0.5000, 0.4375, 0.6875), size = Vector3.new(0.5000, 0.3750, 0.1250), glow = Color3.fromRGB(95, 208, 192) },
				} },
				{ name = "HA_dew_Cape2", offset = Vector3.new(0.0000, -0.1875, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.0933, 0.7500), glows = {
					{ name = "HG_dew_Cape2_1", offset = Vector3.new(-0.5000, -0.2500, 0.7500), size = Vector3.new(0.5000, 0.5000, 0.2500), glow = Color3.fromRGB(95, 208, 192) },
				} },
				{ name = "HA_dew_Cape3", offset = Vector3.new(0.0000, -0.8750, 0.7500), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -0.5533, 0.7500), glows = {
					{ name = "HG_dew_Cape3_1", offset = Vector3.new(-0.3125, -0.6875, 0.7500), size = Vector3.new(0.3750, 0.3750, 0.2500), glow = Color3.fromRGB(95, 208, 192) },
				} },
			},
		},
		lotus = {
			rarity = "epic",
			floor = 2,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_lotus_Hat", part = "Head", offset = Vector3.new(0.0625, 0.8125, 0.0625), size = Vector3.new(2.6250, 2.1250, 2.6250) },
				{ name = "HG_lotus_Hat_1", part = "Head", offset = Vector3.new(-0.0625, 0.3750, -0.0625), size = Vector3.new(2.6250, 0.7500, 2.6250), glow = Color3.fromRGB(95, 208, 192) },
			},
			armor = {
				{ name = "HA_lotus_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0000), size = Vector3.new(2.2500, 1.0000, 1.5000) },
				{ name = "HG_lotus_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5000, -0.8125), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(95, 208, 192) },
				{ name = "HA_lotus_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_lotus_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_lotus_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_lotus_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_lotus_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.1875, -0.0625), size = Vector3.new(2.2500, 0.6250, 1.3750) },
			},
			cape = {
				{ name = "HA_lotus_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.7500), size = Vector3.new(2.0000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.7600, 0.7500), glows = {
				} },
				{ name = "HA_lotus_Cape2", offset = Vector3.new(0.0000, -0.2500, 0.7500), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0950, 0.7500), glows = {
					{ name = "HG_lotus_Cape2_1", offset = Vector3.new(0.0000, -0.5000, 0.7500), size = Vector3.new(1.2500, 0.2500, 0.2500), glow = Color3.fromRGB(95, 208, 192) },
				} },
				{ name = "HA_lotus_Cape3", offset = Vector3.new(0.0000, -0.9375, 0.7500), size = Vector3.new(2.2500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, -0.5700, 0.7500), glows = {
					{ name = "HG_lotus_Cape3_1", offset = Vector3.new(0.0000, -0.9375, 0.7500), size = Vector3.new(1.2500, 0.6250, 0.2500), glow = Color3.fromRGB(95, 208, 192) },
				} },
				{ name = "HA_lotus_Cape4", offset = Vector3.new(0.0000, -1.5625, 0.7500), size = Vector3.new(2.2500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, -1.2350, 0.7500), glows = {
					{ name = "HG_lotus_Cape4_1", offset = Vector3.new(0.0000, -1.5625, 0.7500), size = Vector3.new(1.2500, 0.6250, 0.2500), glow = Color3.fromRGB(95, 208, 192) },
				} },
			},
		},
		gardener_mage = {
			rarity = "legendary",
			floor = 2,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_gardener_mage_Hat", part = "Head", offset = Vector3.new(0.0000, 0.6875, 0.0000), size = Vector3.new(2.2500, 1.8750, 2.2500) },
				{ name = "HG_gardener_mage_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.6250, -0.1875), size = Vector3.new(1.0000, 1.2500, 1.1250), glow = Color3.fromRGB(95, 208, 192) },
				{ name = "HG_gardener_mage_Hat_2", part = "Head", offset = Vector3.new(0.0000, 1.6875, 0.0000), size = Vector3.new(0.2500, 0.1250, 0.2500), glow = Color3.fromRGB(255, 122, 154) },
			},
			armor = {
				{ name = "HA_gardener_mage_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0625), size = Vector3.new(2.2500, 1.2500, 1.6250) },
				{ name = "HG_gardener_mage_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5000, -0.8125), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(255, 122, 154) },
				{ name = "HA_gardener_mage_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_gardener_mage_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_gardener_mage_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_gardener_mage_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_gardener_mage_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.2500, -0.0625), size = Vector3.new(2.2500, 0.7500, 1.3750) },
			},
			cape = {
				{ name = "HA_gardener_mage_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.7800, 0.8125), glows = {
					{ name = "HG_gardener_mage_Cape1_1", offset = Vector3.new(0.0000, 0.2500, 0.8125), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(95, 208, 192) },
				} },
				{ name = "HA_gardener_mage_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0225, 0.7500), glows = {
					{ name = "HG_gardener_mage_Cape2_1", offset = Vector3.new(0.0000, -0.3125, 0.8125), size = Vector3.new(0.2500, 0.6250, 0.1250), glow = Color3.fromRGB(95, 208, 192) },
				} },
				{ name = "HA_gardener_mage_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -0.7350, 0.8125), glows = {
					{ name = "HG_gardener_mage_Cape3_1", offset = Vector3.new(0.0000, -1.0000, 0.8125), size = Vector3.new(0.2500, 0.5000, 0.1250), glow = Color3.fromRGB(95, 208, 192) },
				} },
				{ name = "HA_gardener_mage_Cape4", offset = Vector3.new(0.0000, -1.8750, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -1.4925, 0.8125), glows = {
					{ name = "HG_gardener_mage_Cape4_1", offset = Vector3.new(0.0000, -1.5625, 0.8125), size = Vector3.new(0.2500, 0.1250, 0.1250), glow = Color3.fromRGB(95, 208, 192) },
				} },
			},
		},
		kennelman = {
			rarity = "common",
			floor = 3,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_kennelman_Helm", part = "Head", offset = Vector3.new(0.0000, 0.0625, 0.0000), size = Vector3.new(1.7500, 1.3750, 1.7500) },
				{ name = "HG_kennelman_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_kennelman_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, 0.0000), size = Vector3.new(2.2500, 1.7500, 1.5000) },
				{ name = "HA_kennelman_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.1250, 0.3125, 0.0000), size = Vector3.new(1.5000, 1.1250, 1.5000) },
				{ name = "HA_kennelman_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_kennelman_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_kennelman_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.1250, 0.3125, 0.0000), size = Vector3.new(1.5000, 1.1250, 1.5000) },
				{ name = "HA_kennelman_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_kennelman_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_kennelman_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.2500, -0.0625), size = Vector3.new(2.2500, 0.7500, 1.3750) },
				{ name = "HA_kennelman_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.1250, -0.2500), size = Vector3.new(1.2500, 0.7500, 0.7500) },
				{ name = "HA_kennelman_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.0625, -0.0625), size = Vector3.new(1.2500, 1.1250, 1.3750) },
				{ name = "HA_kennelman_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0625, -0.1250), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_kennelman_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.1250, -0.2500), size = Vector3.new(1.2500, 0.7500, 0.7500) },
				{ name = "HA_kennelman_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.0625, -0.0625), size = Vector3.new(1.2500, 1.1250, 1.3750) },
				{ name = "HA_kennelman_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0625, -0.1250), size = Vector3.new(1.2500, 0.6250, 1.2500) },
			},
			cape = {
			},
		},
		huntsman = {
			rarity = "rare",
			floor = 3,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_huntsman_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1875, 0.0000), size = Vector3.new(2.2500, 1.1250, 2.2500) },
				{ name = "HG_huntsman_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_huntsman_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(2.2500, 1.7500, 1.6250) },
				{ name = "HA_huntsman_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_huntsman_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_huntsman_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_huntsman_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_huntsman_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_huntsman_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_huntsman_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(2.2500, 0.8750, 1.5000) },
				{ name = "HA_huntsman_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.8750, 0.8750) },
				{ name = "HA_huntsman_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_huntsman_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0625, -0.1250), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_huntsman_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.8750, 0.8750) },
				{ name = "HA_huntsman_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_huntsman_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0625, -0.1250), size = Vector3.new(1.2500, 0.6250, 1.2500) },
			},
			cape = {
				{ name = "HA_huntsman_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.8125), size = Vector3.new(1.7500, 0.6250, 0.1250), hinge = Vector3.new(0.0000, 0.7400, 0.8125), glows = {
				} },
				{ name = "HA_huntsman_Cape2", offset = Vector3.new(0.0000, -0.1875, 0.8125), size = Vector3.new(1.7500, 0.6250, 0.1250), hinge = Vector3.new(0.0000, 0.1267, 0.8125), glows = {
				} },
				{ name = "HA_huntsman_Cape3", offset = Vector3.new(0.0000, -0.8125, 0.8125), size = Vector3.new(2.0000, 0.6250, 0.1250), hinge = Vector3.new(0.0000, -0.4867, 0.8125), glows = {
				} },
			},
		},
		bear_hunter = {
			rarity = "epic",
			floor = 3,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_bear_hunter_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1875, -0.1250), size = Vector3.new(1.7500, 1.8750, 2.0000) },
				{ name = "HG_bear_hunter_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.5625), size = Vector3.new(0.7500, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_bear_hunter_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1875, 0.0000), size = Vector3.new(2.5000, 1.8750, 2.2500) },
				{ name = "HA_bear_hunter_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_bear_hunter_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_bear_hunter_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, -0.0625, -0.0625), size = Vector3.new(1.2500, 0.6250, 1.3750) },
				{ name = "HA_bear_hunter_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_bear_hunter_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_bear_hunter_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, -0.0625, -0.0625), size = Vector3.new(1.2500, 0.6250, 1.3750) },
				{ name = "HA_bear_hunter_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(2.2500, 0.8750, 1.5000) },
				{ name = "HA_bear_hunter_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_bear_hunter_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_bear_hunter_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.6250, 1.3750) },
				{ name = "HA_bear_hunter_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_bear_hunter_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_bear_hunter_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.6250, 1.3750) },
			},
			cape = {
				{ name = "HA_bear_hunter_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.7500), size = Vector3.new(2.0000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.8000, 0.7500), glows = {
				} },
				{ name = "HA_bear_hunter_Cape2", offset = Vector3.new(0.0000, -0.1875, 0.7500), size = Vector3.new(2.0000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.1500, 0.7500), glows = {
				} },
				{ name = "HA_bear_hunter_Cape3", offset = Vector3.new(0.0000, -0.8125, 0.8125), size = Vector3.new(2.2500, 0.6250, 0.3750), hinge = Vector3.new(0.0000, -0.5000, 0.8125), glows = {
				} },
				{ name = "HA_bear_hunter_Cape4", offset = Vector3.new(0.0000, -1.3750, 0.8125), size = Vector3.new(2.2500, 0.5000, 0.3750), hinge = Vector3.new(0.0000, -1.1500, 0.8125), glows = {
				} },
			},
		},
		royal_hunt = {
			rarity = "legendary",
			floor = 3,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_royal_hunt_Helm", part = "Head", offset = Vector3.new(0.0000, 0.4375, -0.1250), size = Vector3.new(2.2500, 2.3750, 1.7500) },
				{ name = "HG_royal_hunt_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6250), size = Vector3.new(0.7500, 0.1250, 0.2500), glow = Color3.fromRGB(255, 176, 74) },
			},
			armor = {
				{ name = "HA_royal_hunt_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, 0.0000), size = Vector3.new(2.5000, 1.7500, 2.0000) },
				{ name = "HG_royal_hunt_Chest_1", part = "UpperTorso", offset = Vector3.new(-0.0625, -0.6875, 0.5625), size = Vector3.new(0.8750, 0.1250, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				{ name = "HA_royal_hunt_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.2500, 0.1250, 0.0000), size = Vector3.new(1.7500, 1.5000, 2.0000) },
				{ name = "HA_royal_hunt_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_royal_hunt_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_royal_hunt_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.2500, 0.1250, 0.0000), size = Vector3.new(1.7500, 1.5000, 2.0000) },
				{ name = "HA_royal_hunt_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_royal_hunt_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_royal_hunt_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3750, 0.0000), size = Vector3.new(2.2500, 1.0000, 1.5000) },
				{ name = "HA_royal_hunt_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_royal_hunt_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_royal_hunt_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.6250, 1.3750) },
				{ name = "HA_royal_hunt_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_royal_hunt_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_royal_hunt_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.6250, 1.3750) },
			},
			cape = {
				{ name = "HA_royal_hunt_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.8000, 0.8125), glows = {
					{ name = "HG_royal_hunt_Cape1_1", offset = Vector3.new(0.0000, 0.4375, 0.8125), size = Vector3.new(0.2500, 0.6250, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				} },
				{ name = "HA_royal_hunt_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.0500, 0.8125), glows = {
					{ name = "HG_royal_hunt_Cape2_1", offset = Vector3.new(0.0000, -0.3750, 0.8125), size = Vector3.new(0.2500, 0.7500, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				} },
				{ name = "HA_royal_hunt_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8750), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -0.7000, 0.8750), glows = {
					{ name = "HG_royal_hunt_Cape3_1", offset = Vector3.new(0.0000, -1.1250, 0.8125), size = Vector3.new(0.2500, 0.5000, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				} },
				{ name = "HA_royal_hunt_Cape4", offset = Vector3.new(0.0000, -1.8125, 0.8750), size = Vector3.new(2.5000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, -1.4500, 0.8750), glows = {
				} },
			},
		},
		tracker = {
			rarity = "common",
			floor = 3,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_tracker_Hat", part = "Head", offset = Vector3.new(0.0000, 0.6250, 0.0000), size = Vector3.new(2.2500, 1.7500, 2.2500) },
				{ name = "HG_tracker_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_tracker_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0625), size = Vector3.new(2.2500, 0.7500, 1.6250) },
				{ name = "HA_tracker_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_tracker_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_tracker_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_tracker_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_tracker_Belt", part = "LowerTorso", offset = Vector3.new(-0.0625, -0.0625, 0.0000), size = Vector3.new(2.3750, 0.3750, 1.2500) },
			},
			cape = {
				{ name = "HA_tracker_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.7500), size = Vector3.new(1.7500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.7000, 0.7500), glows = {
				} },
				{ name = "HA_tracker_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.7500), size = Vector3.new(1.7500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0000, 0.7500), glows = {
				} },
			},
		},
		moon_call = {
			rarity = "rare",
			floor = 3,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_moon_call_Hat", part = "Head", offset = Vector3.new(0.0000, 0.8125, -0.0625), size = Vector3.new(2.0000, 2.1250, 2.1250) },
				{ name = "HG_moon_call_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HG_moon_call_Hat_2", part = "Head", offset = Vector3.new(-0.3125, 1.0625, 0.0625), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
			},
			armor = {
				{ name = "HA_moon_call_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0625), size = Vector3.new(2.2500, 0.7500, 1.3750) },
				{ name = "HA_moon_call_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_moon_call_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_moon_call_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_moon_call_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_moon_call_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(2.2500, 0.2500, 1.2500) },
			},
			cape = {
				{ name = "HA_moon_call_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.7400, 0.7500), glows = {
				} },
				{ name = "HA_moon_call_Cape2", offset = Vector3.new(0.0000, -0.1875, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.1267, 0.7500), glows = {
					{ name = "HG_moon_call_Cape2_1", offset = Vector3.new(-0.3125, -0.2500, 0.8125), size = Vector3.new(0.1250, 0.2500, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				} },
				{ name = "HA_moon_call_Cape3", offset = Vector3.new(0.0000, -0.8125, 0.7500), size = Vector3.new(2.0000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, -0.4867, 0.7500), glows = {
					{ name = "HG_moon_call_Cape3_1", offset = Vector3.new(-0.8125, -0.8125, 0.6875), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				} },
			},
		},
		ghost_pack = {
			rarity = "epic",
			floor = 3,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_ghost_pack_Hat", part = "Head", offset = Vector3.new(0.0000, 0.5000, 0.0625), size = Vector3.new(2.5000, 1.5000, 2.3750) },
				{ name = "HG_ghost_pack_Hat_1", part = "Head", offset = Vector3.new(-0.0625, 0.6250, -0.1250), size = Vector3.new(1.1250, 1.2500, 1.5000), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_ghost_pack_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5000, 0.0625), size = Vector3.new(2.2500, 1.2500, 1.6250) },
				{ name = "HG_ghost_pack_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.0625, 0.5625, -0.8125), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HA_ghost_pack_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_ghost_pack_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_ghost_pack_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_ghost_pack_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_ghost_pack_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.2500, -0.0625), size = Vector3.new(2.2500, 0.7500, 1.3750) },
			},
			cape = {
				{ name = "HA_ghost_pack_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.7800, 0.8125), glows = {
				} },
				{ name = "HA_ghost_pack_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0350, 0.7500), glows = {
				} },
				{ name = "HA_ghost_pack_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -0.7100, 0.8125), glows = {
					{ name = "HG_ghost_pack_Cape3_1", offset = Vector3.new(0.0000, -1.3750, 0.8125), size = Vector3.new(1.2500, 0.2500, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				} },
				{ name = "HA_ghost_pack_Cape4", offset = Vector3.new(0.0000, -1.8125, 0.8125), size = Vector3.new(2.2500, 0.6250, 0.3750), hinge = Vector3.new(0.0000, -1.4550, 0.8125), glows = {
					{ name = "HG_ghost_pack_Cape4_1", offset = Vector3.new(0.0000, -1.6875, 0.8750), size = Vector3.new(1.2500, 0.3750, 0.2500), glow = Color3.fromRGB(111, 227, 255) },
				} },
			},
		},
		huntmaster = {
			rarity = "legendary",
			floor = 3,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_huntmaster_Hat", part = "Head", offset = Vector3.new(0.0000, 0.8750, 0.0000), size = Vector3.new(2.2500, 2.2500, 2.2500) },
				{ name = "HG_huntmaster_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.8750, -0.3125), size = Vector3.new(1.2500, 1.7500, 0.8750), glow = Color3.fromRGB(255, 176, 74) },
			},
			armor = {
				{ name = "HA_huntmaster_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0625), size = Vector3.new(2.2500, 1.2500, 1.6250) },
				{ name = "HG_huntmaster_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5000, -0.8125), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				{ name = "HA_huntmaster_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_huntmaster_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_huntmaster_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_huntmaster_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_huntmaster_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.2500, -0.0625), size = Vector3.new(2.2500, 0.7500, 1.3750) },
			},
			cape = {
				{ name = "HA_huntmaster_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.7800, 0.8125), glows = {
					{ name = "HG_huntmaster_Cape1_1", offset = Vector3.new(0.0000, 0.1875, 0.8125), size = Vector3.new(0.2500, 0.3750, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				} },
				{ name = "HA_huntmaster_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0225, 0.7500), glows = {
					{ name = "HG_huntmaster_Cape2_1", offset = Vector3.new(0.0000, -0.5000, 0.8125), size = Vector3.new(0.2500, 0.5000, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				} },
				{ name = "HA_huntmaster_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -0.7350, 0.8125), glows = {
					{ name = "HG_huntmaster_Cape3_1", offset = Vector3.new(0.0000, -1.0625, 0.8125), size = Vector3.new(0.2500, 0.6250, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				} },
				{ name = "HA_huntmaster_Cape4", offset = Vector3.new(0.0000, -1.8750, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -1.4925, 0.8125), glows = {
					{ name = "HG_huntmaster_Cape4_1", offset = Vector3.new(0.0000, -1.5625, 0.8125), size = Vector3.new(0.2500, 0.1250, 0.1250), glow = Color3.fromRGB(255, 176, 74) },
				} },
			},
		},
		apprentice_smith = {
			rarity = "common",
			floor = 4,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_apprentice_smith_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.5000, 0.7500, 1.6250) },
				{ name = "HG_apprentice_smith_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_apprentice_smith_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.0625, 0.0000), size = Vector3.new(2.2500, 1.6250, 1.2500) },
				{ name = "HA_apprentice_smith_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.0625, 0.3125, 0.0000), size = Vector3.new(1.3750, 0.8750, 1.2500) },
				{ name = "HA_apprentice_smith_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HA_apprentice_smith_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_apprentice_smith_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.0625, 0.3125, 0.0000), size = Vector3.new(1.3750, 0.8750, 1.2500) },
				{ name = "HA_apprentice_smith_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HA_apprentice_smith_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_apprentice_smith_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3750, -0.0625), size = Vector3.new(2.2500, 1.0000, 1.3750) },
				{ name = "HA_apprentice_smith_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.1875, -0.2500), size = Vector3.new(1.2500, 0.6250, 0.7500) },
				{ name = "HA_apprentice_smith_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_apprentice_smith_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_apprentice_smith_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.1875, -0.2500), size = Vector3.new(1.2500, 0.6250, 0.7500) },
				{ name = "HA_apprentice_smith_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_apprentice_smith_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 0.5000, 1.3750) },
			},
			cape = {
			},
		},
		caster = {
			rarity = "rare",
			floor = 4,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_caster_Helm", part = "Head", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.5000, 1.5000, 1.6250) },
				{ name = "HG_caster_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.5625), size = Vector3.new(0.7500, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_caster_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, 0.0000), size = Vector3.new(2.5000, 1.7500, 1.5000) },
				{ name = "HA_caster_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_caster_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_caster_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_caster_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_caster_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_caster_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_caster_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(2.2500, 0.8750, 1.5000) },
				{ name = "HA_caster_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_caster_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_caster_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_caster_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_caster_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_caster_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 0.5000, 1.3750) },
			},
			cape = {
				{ name = "HA_caster_Cape1", offset = Vector3.new(0.0000, 0.3125, 0.8125), size = Vector3.new(1.7500, 0.8750, 0.1250), hinge = Vector3.new(0.0000, 0.7400, 0.8125), glows = {
				} },
				{ name = "HA_caster_Cape2", offset = Vector3.new(0.0000, -0.5625, 0.8125), size = Vector3.new(1.7500, 0.8750, 0.1250), hinge = Vector3.new(0.0000, -0.1300, 0.8125), glows = {
				} },
			},
		},
		scale_knight = {
			rarity = "epic",
			floor = 4,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_scale_knight_Helm", part = "Head", offset = Vector3.new(0.0000, 0.2500, -0.0625), size = Vector3.new(2.0000, 2.0000, 1.8750) },
				{ name = "HG_scale_knight_Helm_1", part = "Head", offset = Vector3.new(0.1875, -0.1875, -0.1875), size = Vector3.new(1.1250, 0.6250, 1.1250), glow = Color3.fromRGB(255, 138, 42) },
			},
			armor = {
				{ name = "HA_scale_knight_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(2.5000, 1.7500, 1.6250) },
				{ name = "HG_scale_knight_Chest_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1875, -0.0625), size = Vector3.new(2.5000, 1.6250, 1.3750), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.2500, 0.3750, 0.0000), size = Vector3.new(1.7500, 2.0000, 2.0000) },
				{ name = "HG_scale_knight_PauldronR_1", part = "RightUpperArm", offset = Vector3.new(0.2500, 0.0000, 0.0000), size = Vector3.new(1.7500, 1.2500, 1.2500), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HG_scale_knight_BracerR_1", part = "RightLowerArm", offset = Vector3.new(-0.3750, -0.3125, -0.3125), size = Vector3.new(0.5000, 0.3750, 0.6250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HG_scale_knight_GauntletR_1", part = "RightHand", offset = Vector3.new(-0.1875, -0.1875, -0.5625), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.2500, 0.3750, 0.0000), size = Vector3.new(1.7500, 2.0000, 2.0000) },
				{ name = "HG_scale_knight_PauldronL_1", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.0000, -0.1250), size = Vector3.new(1.2500, 1.2500, 1.5000), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HG_scale_knight_BracerL_1", part = "LeftLowerArm", offset = Vector3.new(-0.3750, -0.3125, -0.3125), size = Vector3.new(0.5000, 0.3750, 0.6250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HG_scale_knight_GauntletL_1", part = "LeftHand", offset = Vector3.new(-0.1875, -0.1875, -0.5625), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(2.2500, 0.8750, 1.5000) },
				{ name = "HG_scale_knight_Belt_1", part = "LowerTorso", offset = Vector3.new(0.0000, -0.2500, -0.1875), size = Vector3.new(2.2500, 0.7500, 1.1250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HG_scale_knight_CuisseR_1", part = "RightUpperLeg", offset = Vector3.new(-0.3750, -0.3125, -0.3125), size = Vector3.new(0.5000, 0.3750, 0.6250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HG_scale_knight_GreaveR_1", part = "RightLowerLeg", offset = Vector3.new(-0.3750, -0.3125, -0.3125), size = Vector3.new(0.5000, 0.3750, 0.6250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HG_scale_knight_BootR_1", part = "RightFoot", offset = Vector3.new(-0.0625, -0.1875, 0.4375), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HG_scale_knight_CuisseL_1", part = "LeftUpperLeg", offset = Vector3.new(-0.3750, -0.3125, -0.3125), size = Vector3.new(0.5000, 0.3750, 0.6250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HG_scale_knight_GreaveL_1", part = "LeftLowerLeg", offset = Vector3.new(-0.3750, -0.3125, -0.3125), size = Vector3.new(0.5000, 0.3750, 0.6250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_scale_knight_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HG_scale_knight_BootL_1", part = "LeftFoot", offset = Vector3.new(-0.0625, -0.1875, 0.4375), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
			},
			cape = {
				{ name = "HA_scale_knight_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.8125), size = Vector3.new(2.0000, 0.6250, 0.1250), hinge = Vector3.new(0.0000, 0.7600, 0.8125), glows = {
				} },
				{ name = "HA_scale_knight_Cape2", offset = Vector3.new(0.0000, -0.2500, 0.7500), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0950, 0.7500), glows = {
				} },
				{ name = "HA_scale_knight_Cape3", offset = Vector3.new(0.0625, -0.9375, 0.8125), size = Vector3.new(2.1250, 0.6250, 0.3750), hinge = Vector3.new(0.0000, -0.5700, 0.8125), glows = {
				} },
				{ name = "HA_scale_knight_Cape4", offset = Vector3.new(0.1250, -1.5000, 0.8125), size = Vector3.new(2.0000, 0.5000, 0.3750), hinge = Vector3.new(0.0000, -1.2350, 0.8125), glows = {
					{ name = "HG_scale_knight_Cape4_1", offset = Vector3.new(0.3125, -1.4375, 0.8750), size = Vector3.new(1.3750, 0.3750, 0.2500), glow = Color3.fromRGB(255, 138, 42) },
				} },
			},
		},
		elder_founder = {
			rarity = "legendary",
			floor = 4,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_elder_founder_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1250, -0.1250), size = Vector3.new(1.5000, 1.7500, 1.7500) },
				{ name = "HG_elder_founder_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.4375, -0.0625), size = Vector3.new(1.0000, 0.8750, 1.1250), glow = Color3.fromRGB(255, 200, 87) },
			},
			armor = {
				{ name = "HA_elder_founder_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(2.5000, 1.7500, 1.6250) },
				{ name = "HG_elder_founder_Chest_1", part = "UpperTorso", offset = Vector3.new(0.0625, 0.1250, -0.6250), size = Vector3.new(2.1250, 1.5000, 0.5000), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HG_elder_founder_Chest_2", part = "UpperTorso", offset = Vector3.new(0.0625, 0.8125, -0.6875), size = Vector3.new(0.8750, 0.1250, 0.1250), glow = Color3.fromRGB(255, 200, 87) },
				{ name = "HA_elder_founder_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.2500, 0.1875, 0.0000), size = Vector3.new(1.7500, 1.6250, 2.0000) },
				{ name = "HG_elder_founder_PauldronR_1", part = "RightUpperArm", offset = Vector3.new(0.5625, 0.4375, -0.6875), size = Vector3.new(1.1250, 0.8750, 0.6250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_elder_founder_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HG_elder_founder_BracerR_1", part = "RightLowerArm", offset = Vector3.new(0.0625, -0.1250, -0.5625), size = Vector3.new(0.1250, 0.5000, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_elder_founder_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_elder_founder_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.2500, 0.1875, 0.0000), size = Vector3.new(1.7500, 1.6250, 2.0000) },
				{ name = "HG_elder_founder_PauldronL_1", part = "LeftUpperArm", offset = Vector3.new(-0.4375, 0.4375, -0.6250), size = Vector3.new(1.1250, 0.8750, 0.5000), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_elder_founder_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HG_elder_founder_BracerL_1", part = "LeftLowerArm", offset = Vector3.new(0.0625, -0.1250, -0.5625), size = Vector3.new(0.1250, 0.5000, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_elder_founder_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_elder_founder_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3750, 0.0000), size = Vector3.new(2.2500, 1.0000, 1.5000) },
				{ name = "HA_elder_founder_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HG_elder_founder_CuisseR_1", part = "RightUpperLeg", offset = Vector3.new(0.0625, 0.0000, -0.5625), size = Vector3.new(0.1250, 0.7500, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_elder_founder_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.1250), size = Vector3.new(1.2500, 1.2500, 1.5000) },
				{ name = "HG_elder_founder_GreaveR_1", part = "RightLowerLeg", offset = Vector3.new(0.0625, -0.1250, -0.5625), size = Vector3.new(0.1250, 0.5000, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_elder_founder_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.6250, 1.3750) },
				{ name = "HA_elder_founder_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HG_elder_founder_CuisseL_1", part = "LeftUpperLeg", offset = Vector3.new(0.0625, 0.0000, -0.5625), size = Vector3.new(0.1250, 0.7500, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_elder_founder_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.1250), size = Vector3.new(1.2500, 1.2500, 1.5000) },
				{ name = "HG_elder_founder_GreaveL_1", part = "LeftLowerLeg", offset = Vector3.new(0.0625, -0.1250, -0.5625), size = Vector3.new(0.1250, 0.5000, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HA_elder_founder_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.6250, 1.3750) },
			},
			cape = {
				{ name = "HA_elder_founder_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.8000, 0.8125), glows = {
				} },
				{ name = "HA_elder_founder_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.0500, 0.8125), glows = {
				} },
				{ name = "HA_elder_founder_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8750), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -0.7000, 0.8750), glows = {
				} },
				{ name = "HA_elder_founder_Cape4", offset = Vector3.new(-0.0625, -1.8125, 0.8750), size = Vector3.new(2.3750, 0.6250, 0.2500), hinge = Vector3.new(0.0000, -1.4500, 0.8750), glows = {
					{ name = "HG_elder_founder_Cape4_1", offset = Vector3.new(0.0625, -1.8125, 0.8750), size = Vector3.new(2.3750, 0.6250, 0.2500), glow = Color3.fromRGB(255, 138, 42) },
				} },
			},
		},
		stoker = {
			rarity = "common",
			floor = 4,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_stoker_Hat", part = "Head", offset = Vector3.new(0.0000, 0.6875, 0.0625), size = Vector3.new(2.0000, 1.8750, 2.1250) },
				{ name = "HG_stoker_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HG_stoker_Hat_2", part = "Head", offset = Vector3.new(0.0625, 1.1875, 0.0625), size = Vector3.new(0.3750, 0.3750, 0.8750), glow = Color3.fromRGB(255, 138, 42) },
			},
			armor = {
				{ name = "HA_stoker_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5625, -0.0625), size = Vector3.new(2.2500, 0.6250, 1.3750) },
				{ name = "HA_stoker_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_stoker_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_stoker_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_stoker_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_stoker_Belt", part = "LowerTorso", offset = Vector3.new(0.0625, -0.0625, 0.0000), size = Vector3.new(2.3750, 0.3750, 1.2500) },
			},
			cape = {
				{ name = "HA_stoker_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.7500), size = Vector3.new(1.7500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.7000, 0.7500), glows = {
				} },
				{ name = "HA_stoker_Cape2", offset = Vector3.new(0.0000, -0.3125, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.0500, 0.7500), glows = {
				} },
			},
		},
		bellows = {
			rarity = "rare",
			floor = 4,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_bellows_Hat", part = "Head", offset = Vector3.new(0.0000, 0.8125, -0.0625), size = Vector3.new(2.0000, 2.1250, 2.1250) },
				{ name = "HG_bellows_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_bellows_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0625), size = Vector3.new(2.2500, 0.7500, 1.3750) },
				{ name = "HA_bellows_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_bellows_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_bellows_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_bellows_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_bellows_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(2.2500, 0.2500, 1.2500) },
			},
			cape = {
				{ name = "HA_bellows_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.7400, 0.7500), glows = {
				} },
				{ name = "HA_bellows_Cape2", offset = Vector3.new(0.0000, -0.1875, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.1267, 0.7500), glows = {
				} },
				{ name = "HA_bellows_Cape3", offset = Vector3.new(0.0000, -0.8125, 0.7500), size = Vector3.new(2.0000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, -0.4867, 0.7500), glows = {
					{ name = "HG_bellows_Cape3_1", offset = Vector3.new(0.0625, -0.8750, 0.7500), size = Vector3.new(1.3750, 0.2500, 0.2500), glow = Color3.fromRGB(255, 138, 42) },
				} },
			},
		},
		crucible = {
			rarity = "epic",
			floor = 4,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_crucible_Hat", part = "Head", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(2.5000, 1.3750, 2.5000) },
				{ name = "HG_crucible_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.8750, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HG_crucible_Hat_2", part = "Head", offset = Vector3.new(0.0000, 0.5625, -0.2500), size = Vector3.new(0.5000, 1.1250, 1.0000), glow = Color3.fromRGB(255, 200, 87) },
			},
			armor = {
				{ name = "HA_crucible_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5625, 0.0000), size = Vector3.new(2.2500, 1.1250, 1.5000) },
				{ name = "HG_crucible_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6875, 0.0000), size = Vector3.new(2.2500, 0.8750, 1.2500), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HG_crucible_Mantle_2", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, -0.8125), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(255, 200, 87) },
				{ name = "HA_crucible_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_crucible_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_crucible_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_crucible_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_crucible_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(2.2500, 0.2500, 1.2500) },
			},
			cape = {
				{ name = "HA_crucible_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.7500), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.7600, 0.7500), glows = {
				} },
				{ name = "HA_crucible_Cape2", offset = Vector3.new(0.0000, -0.3125, 0.7500), size = Vector3.new(2.0000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.0450, 0.7500), glows = {
				} },
				{ name = "HA_crucible_Cape3", offset = Vector3.new(0.0000, -1.0000, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -0.6700, 0.7500), glows = {
					{ name = "HG_crucible_Cape3_1", offset = Vector3.new(0.0000, -1.2500, 0.7500), size = Vector3.new(2.2500, 0.2500, 0.2500), glow = Color3.fromRGB(255, 138, 42) },
				} },
				{ name = "HA_crucible_Cape4", offset = Vector3.new(0.0625, -1.7500, 0.7500), size = Vector3.new(2.1250, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -1.3850, 0.7500), glows = {
					{ name = "HG_crucible_Cape4_1", offset = Vector3.new(0.0000, -1.6875, 0.7500), size = Vector3.new(2.2500, 0.6250, 0.2500), glow = Color3.fromRGB(255, 138, 42) },
				} },
			},
		},
		founder = {
			rarity = "legendary",
			floor = 4,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_founder_Hat", part = "Head", offset = Vector3.new(0.0000, 0.6250, 0.0000), size = Vector3.new(2.2500, 1.7500, 2.2500) },
				{ name = "HG_founder_Hat_1", part = "Head", offset = Vector3.new(-0.0625, 1.0625, 0.0000), size = Vector3.new(1.1250, 0.6250, 1.2500), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HG_founder_Hat_2", part = "Head", offset = Vector3.new(0.0000, 0.9375, -0.3125), size = Vector3.new(0.5000, 1.8750, 0.8750), glow = Color3.fromRGB(255, 200, 87) },
			},
			armor = {
				{ name = "HA_founder_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0625), size = Vector3.new(2.2500, 1.2500, 1.6250) },
				{ name = "HG_founder_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.7500, 0.0000), size = Vector3.new(2.2500, 1.0000, 1.2500), glow = Color3.fromRGB(255, 138, 42) },
				{ name = "HG_founder_Mantle_2", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5000, -0.8125), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(255, 200, 87) },
				{ name = "HA_founder_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_founder_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_founder_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_founder_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_founder_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(2.2500, 0.2500, 1.2500) },
			},
			cape = {
				{ name = "HA_founder_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.7800, 0.8125), glows = {
					{ name = "HG_founder_Cape1_1", offset = Vector3.new(0.0000, 0.1875, 0.8125), size = Vector3.new(0.2500, 0.3750, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				} },
				{ name = "HA_founder_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0225, 0.7500), glows = {
					{ name = "HG_founder_Cape2_1", offset = Vector3.new(0.0000, -0.3750, 0.8125), size = Vector3.new(0.2500, 0.5000, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				} },
				{ name = "HA_founder_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -0.7350, 0.8125), glows = {
					{ name = "HG_founder_Cape3_1", offset = Vector3.new(0.0000, -1.0625, 0.8125), size = Vector3.new(0.2500, 0.6250, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
				} },
				{ name = "HA_founder_Cape4", offset = Vector3.new(0.0000, -1.8750, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -1.4925, 0.8125), glows = {
					{ name = "HG_founder_Cape4_1", offset = Vector3.new(0.0000, -1.5625, 0.8125), size = Vector3.new(0.2500, 0.1250, 0.1250), glow = Color3.fromRGB(255, 138, 42) },
					{ name = "HG_founder_Cape4_2", offset = Vector3.new(0.0625, -1.9375, 0.8750), size = Vector3.new(2.1250, 0.3750, 0.2500), glow = Color3.fromRGB(255, 200, 87) },
				} },
			},
		},
		scribe = {
			rarity = "common",
			floor = 5,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_scribe_Helm", part = "Head", offset = Vector3.new(0.0625, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.5000) },
				{ name = "HG_scribe_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_scribe_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, 0.0000), size = Vector3.new(2.2500, 1.7500, 1.5000) },
				{ name = "HA_scribe_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.1250, 0.2500, 0.0000), size = Vector3.new(1.5000, 1.0000, 1.5000) },
				{ name = "HA_scribe_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_scribe_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_scribe_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.1250, 0.2500, 0.0000), size = Vector3.new(1.5000, 1.0000, 1.5000) },
				{ name = "HA_scribe_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_scribe_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_scribe_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.2500, -0.0625), size = Vector3.new(2.2500, 0.7500, 1.3750) },
				{ name = "HA_scribe_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.1250, -0.2500), size = Vector3.new(1.2500, 0.7500, 0.7500) },
				{ name = "HA_scribe_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_scribe_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0000, -0.1250), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_scribe_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.1250, -0.2500), size = Vector3.new(1.2500, 0.7500, 0.7500) },
				{ name = "HA_scribe_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_scribe_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0000, -0.1250), size = Vector3.new(1.2500, 0.5000, 1.2500) },
			},
			cape = {
			},
		},
		binder = {
			rarity = "rare",
			floor = 5,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_binder_Helm", part = "Head", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.5000, 1.5000, 1.8750) },
				{ name = "HG_binder_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6250), size = Vector3.new(0.7500, 0.1250, 0.2500), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_binder_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, 0.0000), size = Vector3.new(2.5000, 1.7500, 1.5000) },
				{ name = "HA_binder_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_binder_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_binder_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_binder_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_binder_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.2500, 0.7500, 1.2500) },
				{ name = "HA_binder_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_binder_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(2.2500, 0.8750, 1.5000) },
				{ name = "HA_binder_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_binder_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_binder_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0625, -0.1250), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_binder_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_binder_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_binder_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0625, -0.1250), size = Vector3.new(1.2500, 0.6250, 1.2500) },
			},
			cape = {
				{ name = "HA_binder_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(1.7500, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.7600, 0.8125), glows = {
				} },
				{ name = "HA_binder_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.0067, 0.8125), glows = {
				} },
				{ name = "HA_binder_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8750), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -0.7467, 0.8750), glows = {
				} },
			},
		},
		seal_keeper = {
			rarity = "epic",
			floor = 5,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_seal_keeper_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1875, -0.1250), size = Vector3.new(1.7500, 1.8750, 1.7500) },
				{ name = "HG_seal_keeper_Helm_1", part = "Head", offset = Vector3.new(0.0000, -0.1875, -0.1250), size = Vector3.new(1.5000, 0.6250, 1.7500), glow = Color3.fromRGB(142, 200, 255) },
			},
			armor = {
				{ name = "HA_seal_keeper_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(2.5000, 1.7500, 1.6250) },
				{ name = "HG_seal_keeper_Chest_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6875, -0.0625), size = Vector3.new(2.5000, 0.1250, 1.3750), glow = Color3.fromRGB(142, 200, 255) },
				{ name = "HA_seal_keeper_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_seal_keeper_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HA_seal_keeper_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_seal_keeper_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.1875, 0.1250, 0.0000), size = Vector3.new(1.6250, 1.5000, 1.7500) },
				{ name = "HA_seal_keeper_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HA_seal_keeper_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_seal_keeper_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(2.2500, 0.8750, 1.5000) },
				{ name = "HA_seal_keeper_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_seal_keeper_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_seal_keeper_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_seal_keeper_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_seal_keeper_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(1.2500, 1.2500, 1.3750) },
				{ name = "HA_seal_keeper_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 0.5000, 1.3750) },
			},
			cape = {
				{ name = "HA_seal_keeper_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.8125), size = Vector3.new(2.0000, 0.6250, 0.1250), hinge = Vector3.new(0.0000, 0.7600, 0.8125), glows = {
				} },
				{ name = "HA_seal_keeper_Cape2", offset = Vector3.new(0.0000, -0.2500, 0.7500), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0950, 0.7500), glows = {
				} },
				{ name = "HA_seal_keeper_Cape3", offset = Vector3.new(0.0000, -0.9375, 0.7500), size = Vector3.new(2.2500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, -0.5700, 0.7500), glows = {
				} },
				{ name = "HA_seal_keeper_Cape4", offset = Vector3.new(0.0000, -1.5000, 0.8125), size = Vector3.new(2.2500, 0.5000, 0.3750), hinge = Vector3.new(0.0000, -1.2350, 0.8125), glows = {
					{ name = "HG_seal_keeper_Cape4_1", offset = Vector3.new(0.1250, -1.5000, 0.8750), size = Vector3.new(2.0000, 0.5000, 0.2500), glow = Color3.fromRGB(142, 200, 255) },
				} },
			},
		},
		chief_chronicler = {
			rarity = "legendary",
			floor = 5,
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_chief_chronicler_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1250, -0.1250), size = Vector3.new(1.5000, 1.7500, 1.7500) },
				{ name = "HG_chief_chronicler_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.6250, -0.0625), size = Vector3.new(1.5000, 1.2500, 1.6250), glow = Color3.fromRGB(142, 200, 255) },
			},
			armor = {
				{ name = "HA_chief_chronicler_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(2.5000, 1.7500, 1.6250) },
				{ name = "HG_chief_chronicler_Chest_1", part = "UpperTorso", offset = Vector3.new(-0.1250, 0.3125, -0.6875), size = Vector3.new(0.7500, 0.8750, 0.3750), glow = Color3.fromRGB(142, 200, 255) },
				{ name = "HA_chief_chronicler_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.2500, 0.3125, 0.0000), size = Vector3.new(1.7500, 1.8750, 2.0000) },
				{ name = "HA_chief_chronicler_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HG_chief_chronicler_BracerR_1", part = "RightLowerArm", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.2500, 1.2500), glow = Color3.fromRGB(142, 200, 255) },
				{ name = "HA_chief_chronicler_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_chief_chronicler_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.2500, 0.3125, 0.0000), size = Vector3.new(1.7500, 1.8750, 2.0000) },
				{ name = "HA_chief_chronicler_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1250, 0.0000), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HG_chief_chronicler_BracerL_1", part = "LeftLowerArm", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.2500, 1.2500), glow = Color3.fromRGB(142, 200, 255) },
				{ name = "HA_chief_chronicler_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, -0.0625), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_chief_chronicler_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3750, 0.0000), size = Vector3.new(2.2500, 1.0000, 1.5000) },
				{ name = "HA_chief_chronicler_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_chief_chronicler_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.1250), size = Vector3.new(1.2500, 1.2500, 1.5000) },
				{ name = "HA_chief_chronicler_BootR", part = "RightFoot", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.6250, 1.3750) },
				{ name = "HA_chief_chronicler_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(0.0000, 0.0000, -0.1875), size = Vector3.new(1.2500, 1.0000, 0.8750) },
				{ name = "HA_chief_chronicler_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(0.0000, 0.1250, -0.1250), size = Vector3.new(1.2500, 1.2500, 1.5000) },
				{ name = "HA_chief_chronicler_BootL", part = "LeftFoot", offset = Vector3.new(0.0000, 0.0625, -0.1875), size = Vector3.new(1.2500, 0.6250, 1.3750) },
			},
			cape = {
				{ name = "HA_chief_chronicler_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.8000, 0.8125), glows = {
					{ name = "HG_chief_chronicler_Cape1_1", offset = Vector3.new(0.0625, 0.0625, 0.8125), size = Vector3.new(1.6250, 0.1250, 0.1250), glow = Color3.fromRGB(142, 200, 255) },
				} },
				{ name = "HA_chief_chronicler_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.0500, 0.8125), glows = {
					{ name = "HG_chief_chronicler_Cape2_1", offset = Vector3.new(0.0625, -0.5000, 0.8125), size = Vector3.new(1.6250, 0.5000, 0.1250), glow = Color3.fromRGB(142, 200, 255) },
				} },
				{ name = "HA_chief_chronicler_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8750), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -0.7000, 0.8750), glows = {
					{ name = "HG_chief_chronicler_Cape3_1", offset = Vector3.new(0.0000, -1.2500, 0.8750), size = Vector3.new(1.7500, 0.5000, 0.2500), glow = Color3.fromRGB(142, 200, 255) },
				} },
				{ name = "HA_chief_chronicler_Cape4", offset = Vector3.new(0.0000, -1.8125, 0.8750), size = Vector3.new(2.5000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, -1.4500, 0.8750), glows = {
				} },
			},
		},
		copyist = {
			rarity = "common",
			floor = 5,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_copyist_Hat", part = "Head", offset = Vector3.new(0.0000, 0.6875, 0.0625), size = Vector3.new(2.2500, 1.8750, 2.1250) },
				{ name = "HG_copyist_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_copyist_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5625, -0.0625), size = Vector3.new(2.2500, 0.6250, 1.3750) },
				{ name = "HA_copyist_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_copyist_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_copyist_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_copyist_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_copyist_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.0625, -0.0625), size = Vector3.new(2.2500, 0.3750, 1.3750) },
			},
			cape = {
				{ name = "HA_copyist_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.7500), size = Vector3.new(1.7500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.7000, 0.7500), glows = {
				} },
				{ name = "HA_copyist_Cape2", offset = Vector3.new(0.0000, -0.3125, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.0500, 0.7500), glows = {
				} },
			},
		},
		pages = {
			rarity = "rare",
			floor = 5,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_pages_Hat", part = "Head", offset = Vector3.new(0.0000, 0.8125, 0.0000), size = Vector3.new(2.2500, 2.1250, 2.2500) },
				{ name = "HG_pages_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_pages_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0625), size = Vector3.new(2.2500, 0.7500, 1.3750) },
				{ name = "HA_pages_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_pages_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_pages_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_pages_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_pages_Belt", part = "LowerTorso", offset = Vector3.new(-0.0625, -0.1875, 0.0000), size = Vector3.new(2.3750, 0.6250, 1.2500) },
			},
			cape = {
				{ name = "HA_pages_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.7400, 0.7500), glows = {
					{ name = "HG_pages_Cape1_1", offset = Vector3.new(-0.0625, 0.1875, 0.6875), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(142, 200, 255) },
				} },
				{ name = "HA_pages_Cape2", offset = Vector3.new(0.0000, -0.1875, 0.7500), size = Vector3.new(1.7500, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.0933, 0.7500), glows = {
					{ name = "HG_pages_Cape2_1", offset = Vector3.new(0.1250, -0.1875, 0.7500), size = Vector3.new(0.5000, 0.6250, 0.2500), glow = Color3.fromRGB(142, 200, 255) },
				} },
				{ name = "HA_pages_Cape3", offset = Vector3.new(0.0000, -0.8750, 0.7500), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -0.5533, 0.7500), glows = {
					{ name = "HG_pages_Cape3_1", offset = Vector3.new(-0.0625, -0.7500, 0.7500), size = Vector3.new(0.3750, 0.2500, 0.2500), glow = Color3.fromRGB(142, 200, 255) },
				} },
			},
		},
		clockkeeper = {
			rarity = "epic",
			floor = 5,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_clockkeeper_Hat", part = "Head", offset = Vector3.new(0.0000, 0.8750, 0.0000), size = Vector3.new(2.5000, 2.2500, 2.5000) },
				{ name = "HG_clockkeeper_Hat_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6875), size = Vector3.new(0.5000, 0.1250, 0.1250), glow = Color3.fromRGB(142, 200, 255) },
			},
			armor = {
				{ name = "HA_clockkeeper_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5625, 0.0000), size = Vector3.new(2.2500, 1.1250, 1.5000) },
				{ name = "HG_clockkeeper_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, -0.8125), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(142, 200, 255) },
				{ name = "HA_clockkeeper_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_clockkeeper_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_clockkeeper_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_clockkeeper_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_clockkeeper_Belt", part = "LowerTorso", offset = Vector3.new(0.0625, -0.2500, 0.0000), size = Vector3.new(2.3750, 0.7500, 1.2500) },
			},
			cape = {
				{ name = "HA_clockkeeper_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.7500), size = Vector3.new(2.0000, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.7600, 0.7500), glows = {
				} },
				{ name = "HA_clockkeeper_Cape2", offset = Vector3.new(0.0000, -0.3125, 0.7500), size = Vector3.new(2.0000, 0.6250, 0.2500), hinge = Vector3.new(0.0000, 0.0450, 0.7500), glows = {
					{ name = "HG_clockkeeper_Cape2_1", offset = Vector3.new(-0.5625, -0.4375, 0.8125), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(142, 200, 255) },
				} },
				{ name = "HA_clockkeeper_Cape3", offset = Vector3.new(0.0000, -1.0000, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -0.6700, 0.7500), glows = {
					{ name = "HG_clockkeeper_Cape3_1", offset = Vector3.new(-0.4375, -1.0000, 0.7500), size = Vector3.new(1.3750, 0.7500, 0.2500), glow = Color3.fromRGB(142, 200, 255) },
				} },
				{ name = "HA_clockkeeper_Cape4", offset = Vector3.new(0.0000, -1.7500, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, -1.3850, 0.7500), glows = {
				} },
			},
		},
		memory_scribe = {
			rarity = "legendary",
			floor = 5,
			class = "mage",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_memory_scribe_Hat", part = "Head", offset = Vector3.new(0.0000, 0.8125, 0.0000), size = Vector3.new(2.2500, 2.1250, 2.2500) },
				{ name = "HG_memory_scribe_Hat_1", part = "Head", offset = Vector3.new(0.0000, 1.0625, -0.3125), size = Vector3.new(0.5000, 2.1250, 0.8750), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HG_memory_scribe_Hat_2", part = "Head", offset = Vector3.new(0.0000, 1.1875, 0.0000), size = Vector3.new(1.0000, 0.6250, 1.0000), glow = Color3.fromRGB(142, 200, 255) },
			},
			armor = {
				{ name = "HA_memory_scribe_Mantle", part = "UpperTorso", offset = Vector3.new(0.0000, 0.6250, 0.0625), size = Vector3.new(2.2500, 1.2500, 1.6250) },
				{ name = "HG_memory_scribe_Mantle_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5000, -0.8125), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HA_memory_scribe_ShoulderR", part = "RightUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_memory_scribe_CuffR", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_memory_scribe_ShoulderL", part = "LeftUpperArm", offset = Vector3.new(0.0000, 0.4375, 0.0000), size = Vector3.new(1.2500, 0.6250, 1.2500) },
				{ name = "HA_memory_scribe_CuffL", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.3125, 0.0000), size = Vector3.new(1.2500, 0.3750, 1.2500) },
				{ name = "HA_memory_scribe_Belt", part = "LowerTorso", offset = Vector3.new(0.0625, -0.2500, -0.0625), size = Vector3.new(2.3750, 0.7500, 1.3750) },
				{ name = "HG_memory_scribe_Belt_1", part = "LowerTorso", offset = Vector3.new(1.3125, -0.3125, 0.0625), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			cape = {
				{ name = "HA_memory_scribe_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.7800, 0.8125), glows = {
					{ name = "HG_memory_scribe_Cape1_1", offset = Vector3.new(0.0625, 0.0625, 0.8125), size = Vector3.new(1.6250, 0.1250, 0.1250), glow = Color3.fromRGB(142, 200, 255) },
				} },
				{ name = "HA_memory_scribe_Cape2", offset = Vector3.new(0.0000, -0.3750, 0.7500), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.0225, 0.7500), glows = {
					{ name = "HG_memory_scribe_Cape2_1", offset = Vector3.new(0.0000, -0.5000, 0.7500), size = Vector3.new(1.7500, 0.5000, 0.2500), glow = Color3.fromRGB(142, 200, 255) },
				} },
				{ name = "HA_memory_scribe_Cape3", offset = Vector3.new(0.0000, -1.1250, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -0.7350, 0.8125), glows = {
					{ name = "HG_memory_scribe_Cape3_1", offset = Vector3.new(0.0625, -1.2500, 0.8125), size = Vector3.new(1.6250, 0.5000, 0.3750), glow = Color3.fromRGB(142, 200, 255) },
				} },
				{ name = "HA_memory_scribe_Cape4", offset = Vector3.new(0.0000, -1.8750, 0.8125), size = Vector3.new(2.2500, 0.7500, 0.3750), hinge = Vector3.new(0.0000, -1.4925, 0.8125), glows = {
				} },
			},
		},
	},
}
