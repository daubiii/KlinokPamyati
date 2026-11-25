-- Сгенерировано tools/hero-armor/export_hero.py. Не править руками: правки — в генераторе.
-- Броня героя-воина из мешей (map/hero_armor.glb). offset/size — в стадах в осях части тела R15
-- (X вправо, Y вверх, перед −Z) при Part.Size.Y = refY; при другом размере всё масштабируется.
-- AssembleHeroArmor.lua кладёт импортированные MeshPart в ReplicatedStorage.HeroArmorMeshes,
-- HeroArmorBuilder собирает из них облик. Цвета body/glow — из воксельных моделей (как WeaponMeshData).
-- cape: сегменты плаща сверху вниз, hinge — шарнир у верхней кромки (в осях UpperTorso).
return {
	voxel = 0.1250,
	refY = {
		Head = 1.2,
		UpperTorso = 1.6,
		LowerTorso = 0.4,
		RightUpperArm = 1.169,
		LeftUpperArm = 1.169,
		RightLowerArm = 1.052,
		LeftLowerArm = 1.052,
		RightHand = 0.3,
		LeftHand = 0.3,
		RightUpperLeg = 1.217,
		LeftUpperLeg = 1.217,
		RightLowerLeg = 1.193,
		LeftLowerLeg = 1.193,
		RightFoot = 0.3,
		LeftFoot = 0.3,
	},
	sets = {
		wanderer = {
			rarity = "common",
			body = { cloth = Color3.fromRGB(90, 80, 72), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_wanderer_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1250, 0.1250), size = Vector3.new(3.0000, 2.0000, 2.3750) },
				{ name = "HG_wanderer_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6250), size = Vector3.new(0.7500, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_wanderer_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, -0.0625, 0.1875), size = Vector3.new(2.2500, 1.8750, 2.6250) },
				{ name = "HA_wanderer_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.2500, 0.3750, 0.0625), size = Vector3.new(1.5000, 1.0000, 1.2500) },
				{ name = "HA_wanderer_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.1875, 0.4375, 0.0625), size = Vector3.new(1.3750, 0.8750, 1.5000) },
				{ name = "HA_wanderer_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, 0.0000, 0.0625), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HA_wanderer_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, 0.0000, 0.0625), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HA_wanderer_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, 0.0625), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_wanderer_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, 0.0625), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_wanderer_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.3125, -0.1875), size = Vector3.new(2.7500, 1.1250, 2.1250) },
				{ name = "HA_wanderer_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.1250, 0.2500, 0.0312), size = Vector3.new(1.2500, 1.2500, 1.2500) },
				{ name = "HA_wanderer_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(-0.0625, -0.1250, 0.0312), size = Vector3.new(1.1250, 0.2500, 1.2500) },
				{ name = "HA_wanderer_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0625, 0.0625, -0.0938), size = Vector3.new(1.1250, 1.3750, 1.5000) },
				{ name = "HA_wanderer_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(-0.0625, 0.0625, -0.0938), size = Vector3.new(1.1250, 1.3750, 1.5000) },
				{ name = "HA_wanderer_BootR", part = "RightFoot", offset = Vector3.new(0.1875, 0.1250, -0.0938), size = Vector3.new(1.3750, 0.7500, 2.0000) },
				{ name = "HA_wanderer_BootL", part = "LeftFoot", offset = Vector3.new(-0.1875, 0.1250, -0.0938), size = Vector3.new(1.3750, 0.7500, 2.0000) },
			},
			cape = {
				{ name = "HA_wanderer_Cape1", offset = Vector3.new(-0.4375, 0.5000, 0.8125), size = Vector3.new(0.6250, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.8750, 0.8125), glows = {
				} },
				{ name = "HA_wanderer_Cape2", offset = Vector3.new(-0.4375, -0.1875, 0.8750), size = Vector3.new(0.6250, 0.8750, 0.2500), hinge = Vector3.new(0.0000, 0.1250, 0.8750), glows = {
				} },
				{ name = "HA_wanderer_Cape3", offset = Vector3.new(-0.4375, -0.8750, 0.9375), size = Vector3.new(0.6250, 0.7500, 0.1250), hinge = Vector3.new(0.0000, -0.6250, 0.9375), glows = {
				} },
			},
		},
		rusty_guard = {
			rarity = "common",
			body = { cloth = Color3.fromRGB(94, 42, 34), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_rusty_guard_Helm", part = "Head", offset = Vector3.new(0.0000, 0.1250, 0.0625), size = Vector3.new(2.5000, 2.0000, 2.5000) },
				{ name = "HG_rusty_guard_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.6250), size = Vector3.new(0.7500, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_rusty_guard_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, -0.1250), size = Vector3.new(2.2500, 1.7500, 1.7500) },
				{ name = "HA_rusty_guard_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.3750, 0.1250, 0.0625), size = Vector3.new(2.0000, 1.2500, 1.5000) },
				{ name = "HA_rusty_guard_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.0625, 0.1250, 0.0625), size = Vector3.new(1.6250, 1.0000, 1.5000) },
				{ name = "HA_rusty_guard_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, 0.0000, 0.0625), size = Vector3.new(1.5000, 0.7500, 1.5000) },
				{ name = "HA_rusty_guard_BracerL", part = "LeftLowerArm", offset = Vector3.new(-0.0625, 0.0000, 0.0625), size = Vector3.new(1.3750, 0.7500, 1.2500) },
				{ name = "HA_rusty_guard_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, 0.0625), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_rusty_guard_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, 0.0625), size = Vector3.new(1.2500, 0.5000, 1.2500) },
				{ name = "HA_rusty_guard_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.6250, -0.0625), size = Vector3.new(2.7500, 1.7500, 1.8750) },
				{ name = "HG_rusty_guard_Belt_1", part = "LowerTorso", offset = Vector3.new(-1.0625, -0.6875, 0.6875), size = Vector3.new(0.3750, 0.3750, 0.3750), glow = Color3.fromRGB(255, 181, 71) },
				{ name = "HA_rusty_guard_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0625, 0.0625, 0.0312), size = Vector3.new(1.1250, 1.1250, 1.2500) },
				{ name = "HA_rusty_guard_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(-0.0625, 0.0625, 0.0312), size = Vector3.new(1.1250, 1.1250, 1.2500) },
				{ name = "HA_rusty_guard_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.1250, 0.0625, -0.0938), size = Vector3.new(1.2500, 1.3750, 1.5000) },
				{ name = "HA_rusty_guard_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(-0.1250, 0.0625, -0.0938), size = Vector3.new(1.2500, 1.3750, 1.5000) },
				{ name = "HA_rusty_guard_BootR", part = "RightFoot", offset = Vector3.new(0.1250, 0.0625, -0.1562), size = Vector3.new(1.2500, 0.6250, 1.8750) },
				{ name = "HA_rusty_guard_BootL", part = "LeftFoot", offset = Vector3.new(-0.1250, 0.0625, -0.1562), size = Vector3.new(1.2500, 0.6250, 1.8750) },
			},
			cape = {
				{ name = "HA_rusty_guard_Cape1", offset = Vector3.new(-0.5625, 0.4375, 0.8125), size = Vector3.new(1.3750, 0.8750, 0.1250), hinge = Vector3.new(0.0000, 0.8750, 0.8125), glows = {
				} },
				{ name = "HA_rusty_guard_Cape2", offset = Vector3.new(-0.5625, -0.3750, 0.9375), size = Vector3.new(1.3750, 1.0000, 0.3750), hinge = Vector3.new(0.0000, 0.0000, 0.8125), glows = {
				} },
				{ name = "HA_rusty_guard_Cape3", offset = Vector3.new(-0.6875, -1.1250, 1.0625), size = Vector3.new(0.8750, 0.7500, 0.1250), hinge = Vector3.new(0.0000, -0.8750, 1.0625), glows = {
				} },
			},
		},
		gate_guard = {
			rarity = "rare",
			body = { cloth = Color3.fromRGB(62, 74, 68), leather = Color3.fromRGB(74, 52, 38), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_gate_guard_Helm", part = "Head", offset = Vector3.new(0.0000, 0.3750, 0.1875), size = Vector3.new(1.7500, 2.5000, 2.2500) },
				{ name = "HG_gate_guard_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.0625, -0.7500), size = Vector3.new(0.7500, 0.1250, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
			},
			armor = {
				{ name = "HA_gate_guard_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, -0.1875), size = Vector3.new(2.2500, 1.7500, 1.6250) },
				{ name = "HA_gate_guard_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.2500, 0.1875, 0.0625), size = Vector3.new(1.7500, 1.3750, 1.7500) },
				{ name = "HA_gate_guard_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.2500, 0.1875, 0.0625), size = Vector3.new(1.7500, 1.3750, 1.7500) },
				{ name = "HA_gate_guard_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0625, 0.0000, 0.0000), size = Vector3.new(1.6250, 0.7500, 1.6250) },
				{ name = "HA_gate_guard_BracerL", part = "LeftLowerArm", offset = Vector3.new(-0.0625, 0.0000, 0.0000), size = Vector3.new(1.6250, 0.7500, 1.6250) },
				{ name = "HA_gate_guard_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_gate_guard_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_gate_guard_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.6875, -0.1250), size = Vector3.new(2.7500, 1.8750, 2.2500) },
				{ name = "HA_gate_guard_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.1250, 0.0625, -0.0938), size = Vector3.new(1.2500, 1.3750, 1.5000) },
				{ name = "HA_gate_guard_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(-0.1250, 0.0625, -0.0938), size = Vector3.new(1.2500, 1.3750, 1.5000) },
				{ name = "HA_gate_guard_BootR", part = "RightFoot", offset = Vector3.new(0.1250, 0.0625, -0.1562), size = Vector3.new(1.2500, 0.6250, 1.8750) },
				{ name = "HA_gate_guard_BootL", part = "LeftFoot", offset = Vector3.new(-0.1250, 0.0625, -0.1562), size = Vector3.new(1.2500, 0.6250, 1.8750) },
			},
			cape = {
				{ name = "HA_gate_guard_Cape1", offset = Vector3.new(0.0000, 0.5000, 0.8125), size = Vector3.new(2.0000, 0.7500, 0.1250), hinge = Vector3.new(0.0000, 0.8750, 0.8125), glows = {
				} },
				{ name = "HA_gate_guard_Cape2", offset = Vector3.new(0.0000, -0.1875, 0.9375), size = Vector3.new(2.0000, 0.8750, 0.3750), hinge = Vector3.new(0.0000, 0.1250, 0.8125), glows = {
				} },
				{ name = "HA_gate_guard_Cape3", offset = Vector3.new(0.0000, -0.9375, 1.0625), size = Vector3.new(2.2500, 0.8750, 0.3750), hinge = Vector3.new(0.0000, -0.6250, 1.0625), glows = {
				} },
				{ name = "HA_gate_guard_Cape4", offset = Vector3.new(0.0000, -1.6875, 1.1875), size = Vector3.new(2.5000, 0.8750, 0.3750), hinge = Vector3.new(0.0000, -1.3750, 1.1250), glows = {
				} },
				{ name = "HA_gate_guard_Cape5", offset = Vector3.new(0.0000, -2.3125, 1.1875), size = Vector3.new(2.5000, 0.6250, 0.3750), hinge = Vector3.new(0.0000, -2.1250, 1.1875), glows = {
				} },
			},
		},
		shade_knight = {
			rarity = "epic",
			body = { cloth = Color3.fromRGB(34, 24, 46), leather = Color3.fromRGB(30, 21, 48), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_shade_knight_Helm", part = "Head", offset = Vector3.new(0.0000, 0.5000, 0.0000), size = Vector3.new(3.2500, 2.5000, 1.8750) },
				{ name = "HG_shade_knight_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.5625, -1.0000), size = Vector3.new(0.2500, 0.1250, 0.1250), glow = Color3.fromRGB(138, 230, 255) },
				{ name = "HG_shade_knight_Helm_2", part = "Head", offset = Vector3.new(0.0000, 0.1250, -0.8750), size = Vector3.new(1.2500, 0.2500, 0.1250), glow = Color3.fromRGB(181, 124, 255) },
			},
			armor = {
				{ name = "HA_shade_knight_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.3125, 0.0000), size = Vector3.new(2.2500, 2.1250, 2.0000) },
				{ name = "HG_shade_knight_Chest_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.5000, -1.0625), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(138, 230, 255) },
				{ name = "HG_shade_knight_Chest_2", part = "UpperTorso", offset = Vector3.new(0.0000, -0.2500, -0.8125), size = Vector3.new(1.7500, 0.7500, 0.1250), glow = Color3.fromRGB(181, 124, 255) },
				{ name = "HA_shade_knight_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.5625, 0.6875, 0.0625), size = Vector3.new(2.3750, 2.3750, 1.7500) },
				{ name = "HA_shade_knight_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.3750, 0.5000, 0.0625), size = Vector3.new(2.0000, 2.0000, 1.7500) },
				{ name = "HG_shade_knight_PauldronL_1", part = "LeftUpperArm", offset = Vector3.new(-1.0000, 0.8750, -0.1250), size = Vector3.new(0.5000, 1.0000, 0.6250), glow = Color3.fromRGB(138, 230, 255) },
				{ name = "HA_shade_knight_BracerR", part = "RightLowerArm", offset = Vector3.new(0.2500, 0.1250, 0.1875), size = Vector3.new(2.0000, 1.0000, 2.0000) },
				{ name = "HG_shade_knight_BracerR_1", part = "RightLowerArm", offset = Vector3.new(0.0000, -0.1875, -0.7500), size = Vector3.new(0.2500, 0.1250, 0.1250), glow = Color3.fromRGB(181, 124, 255) },
				{ name = "HA_shade_knight_BracerL", part = "LeftLowerArm", offset = Vector3.new(-0.2500, 0.1250, 0.1875), size = Vector3.new(2.0000, 1.0000, 2.0000) },
				{ name = "HG_shade_knight_BracerL_1", part = "LeftLowerArm", offset = Vector3.new(0.0000, -0.1875, -0.7500), size = Vector3.new(0.2500, 0.1250, 0.1250), glow = Color3.fromRGB(181, 124, 255) },
				{ name = "HA_shade_knight_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.8750, 1.3750) },
				{ name = "HA_shade_knight_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, -0.1875, 0.0000), size = Vector3.new(1.2500, 0.8750, 1.3750) },
				{ name = "HA_shade_knight_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.8125, -0.1250), size = Vector3.new(2.7500, 2.1250, 2.0000) },
				{ name = "HG_shade_knight_Belt_1", part = "LowerTorso", offset = Vector3.new(-0.0625, -0.5000, -1.0000), size = Vector3.new(0.3750, 1.0000, 0.2500), glow = Color3.fromRGB(181, 124, 255) },
				{ name = "HA_shade_knight_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.0625, 0.0000, -0.0938), size = Vector3.new(1.1250, 1.0000, 1.5000) },
				{ name = "HA_shade_knight_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(-0.0625, 0.0000, -0.0938), size = Vector3.new(1.1250, 1.0000, 1.5000) },
				{ name = "HA_shade_knight_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0625, 0.0625, -0.2812), size = Vector3.new(1.1250, 1.3750, 1.8750) },
				{ name = "HG_shade_knight_GreaveR_1", part = "RightLowerLeg", offset = Vector3.new(0.0000, -0.1875, -0.7812), size = Vector3.new(0.2500, 0.1250, 0.1250), glow = Color3.fromRGB(181, 124, 255) },
				{ name = "HA_shade_knight_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(-0.0625, 0.0625, -0.2812), size = Vector3.new(1.1250, 1.3750, 1.8750) },
				{ name = "HG_shade_knight_GreaveL_1", part = "LeftLowerLeg", offset = Vector3.new(0.0000, -0.1875, -0.7812), size = Vector3.new(0.2500, 0.1250, 0.1250), glow = Color3.fromRGB(181, 124, 255) },
				{ name = "HA_shade_knight_BootR", part = "RightFoot", offset = Vector3.new(0.1250, 0.0625, -0.2188), size = Vector3.new(1.2500, 0.6250, 2.5000) },
				{ name = "HA_shade_knight_BootL", part = "LeftFoot", offset = Vector3.new(-0.1250, 0.0625, -0.2188), size = Vector3.new(1.2500, 0.6250, 2.5000) },
			},
			cape = {
				{ name = "HA_shade_knight_Cape1", offset = Vector3.new(0.0000, 0.4375, 0.8125), size = Vector3.new(2.0000, 0.8750, 0.1250), hinge = Vector3.new(0.0000, 0.8750, 0.8125), glows = {
				} },
				{ name = "HA_shade_knight_Cape2", offset = Vector3.new(0.0000, -0.3750, 1.0000), size = Vector3.new(2.2500, 1.0000, 0.5000), hinge = Vector3.new(0.0000, 0.0000, 0.8125), glows = {
					{ name = "HG_shade_knight_Cape2_1", offset = Vector3.new(0.0625, -0.8125, 1.1875), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(181, 124, 255) },
				} },
				{ name = "HA_shade_knight_Cape3", offset = Vector3.new(0.0000, -1.2500, 1.1250), size = Vector3.new(2.5000, 1.0000, 0.2500), hinge = Vector3.new(0.0000, -0.8750, 1.1250), glows = {
					{ name = "HG_shade_knight_Cape3_1", offset = Vector3.new(0.0625, -0.8125, 1.1875), size = Vector3.new(0.1250, 0.1250, 0.1250), glow = Color3.fromRGB(181, 124, 255) },
				} },
				{ name = "HA_shade_knight_Cape4", offset = Vector3.new(0.0000, -2.1250, 1.1250), size = Vector3.new(2.5000, 1.0000, 0.2500), hinge = Vector3.new(0.0000, -1.7500, 1.0625), glows = {
				} },
				{ name = "HA_shade_knight_Cape5", offset = Vector3.new(-0.1250, -2.8125, 1.1875), size = Vector3.new(2.2500, 0.6250, 0.1250), hinge = Vector3.new(0.0000, -2.6250, 1.1875), glows = {
				} },
			},
		},
		gatekeeper = {
			rarity = "legendary",
			body = { cloth = Color3.fromRGB(110, 48, 36), leather = Color3.fromRGB(107, 74, 50), skin = Color3.fromRGB(184, 165, 142) },
			helm = {
				{ name = "HA_gatekeeper_Helm", part = "Head", offset = Vector3.new(0.0000, 0.5000, 0.0625), size = Vector3.new(1.7500, 2.5000, 1.7500) },
				{ name = "HG_gatekeeper_Helm_1", part = "Head", offset = Vector3.new(0.0000, 0.1250, -0.6250), size = Vector3.new(0.7500, 0.2500, 0.1250), glow = Color3.fromRGB(111, 227, 255) },
				{ name = "HG_gatekeeper_Helm_2", part = "Head", offset = Vector3.new(0.0000, 1.1250, -0.7500), size = Vector3.new(0.2500, 0.2500, 0.1250), glow = Color3.fromRGB(255, 181, 71) },
			},
			armor = {
				{ name = "HA_gatekeeper_Chest", part = "UpperTorso", offset = Vector3.new(0.0000, 0.1250, -0.0625), size = Vector3.new(2.5000, 1.7500, 1.8750) },
				{ name = "HG_gatekeeper_Chest_1", part = "UpperTorso", offset = Vector3.new(0.0000, 0.0000, -0.9375), size = Vector3.new(0.2500, 0.5000, 0.1250), glow = Color3.fromRGB(255, 181, 71) },
				{ name = "HA_gatekeeper_PauldronR", part = "RightUpperArm", offset = Vector3.new(0.2500, 0.3125, 0.0625), size = Vector3.new(1.7500, 1.6250, 1.7500) },
				{ name = "HA_gatekeeper_PauldronL", part = "LeftUpperArm", offset = Vector3.new(-0.2500, 0.3125, 0.0625), size = Vector3.new(1.7500, 1.6250, 1.7500) },
				{ name = "HA_gatekeeper_BracerR", part = "RightLowerArm", offset = Vector3.new(0.0000, 0.0625, 0.0625), size = Vector3.new(1.7500, 0.8750, 1.7500) },
				{ name = "HA_gatekeeper_BracerL", part = "LeftLowerArm", offset = Vector3.new(0.0000, 0.0625, 0.0625), size = Vector3.new(1.7500, 0.8750, 1.7500) },
				{ name = "HA_gatekeeper_GauntletR", part = "RightHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_gatekeeper_GauntletL", part = "LeftHand", offset = Vector3.new(0.0000, 0.0000, 0.0000), size = Vector3.new(1.2500, 0.5000, 1.3750) },
				{ name = "HA_gatekeeper_Belt", part = "LowerTorso", offset = Vector3.new(0.0000, -0.6250, -0.0625), size = Vector3.new(2.7500, 1.7500, 1.8750) },
				{ name = "HA_gatekeeper_CuisseR", part = "RightUpperLeg", offset = Vector3.new(0.1250, 0.1875, 0.0312), size = Vector3.new(1.2500, 1.1250, 1.5000) },
				{ name = "HA_gatekeeper_CuisseL", part = "LeftUpperLeg", offset = Vector3.new(-0.1250, 0.1875, 0.0312), size = Vector3.new(1.2500, 1.1250, 1.5000) },
				{ name = "HA_gatekeeper_GreaveR", part = "RightLowerLeg", offset = Vector3.new(0.0625, 0.1250, -0.0938), size = Vector3.new(1.1250, 1.5000, 1.5000) },
				{ name = "HA_gatekeeper_GreaveL", part = "LeftLowerLeg", offset = Vector3.new(-0.0625, 0.1250, -0.0938), size = Vector3.new(1.1250, 1.5000, 1.5000) },
				{ name = "HA_gatekeeper_BootR", part = "RightFoot", offset = Vector3.new(0.1250, 0.0625, -0.1562), size = Vector3.new(1.2500, 0.6250, 1.8750) },
				{ name = "HA_gatekeeper_BootL", part = "LeftFoot", offset = Vector3.new(-0.1250, 0.0625, -0.1562), size = Vector3.new(1.2500, 0.6250, 1.8750) },
			},
			cape = {
				{ name = "HA_gatekeeper_Cape1", offset = Vector3.new(0.0000, 0.3750, 0.8750), size = Vector3.new(2.2500, 0.7500, 0.2500), hinge = Vector3.new(0.0000, 0.7500, 0.8125), glows = {
				} },
				{ name = "HA_gatekeeper_Cape2", offset = Vector3.new(0.0000, -0.3125, 0.9375), size = Vector3.new(2.2500, 0.8750, 0.3750), hinge = Vector3.new(0.0000, 0.0000, 0.8750), glows = {
				} },
				{ name = "HA_gatekeeper_Cape3", offset = Vector3.new(0.0000, -1.0625, 1.0000), size = Vector3.new(2.5000, 0.8750, 0.2500), hinge = Vector3.new(0.0000, -0.7500, 1.0000), glows = {
				} },
				{ name = "HA_gatekeeper_Cape4", offset = Vector3.new(0.0000, -1.8125, 1.0625), size = Vector3.new(2.5000, 0.8750, 0.3750), hinge = Vector3.new(0.0000, -1.5000, 1.1250), glows = {
				} },
				{ name = "HA_gatekeeper_Cape5", offset = Vector3.new(0.0000, -2.3125, 1.0625), size = Vector3.new(2.5000, 0.3750, 0.1250), hinge = Vector3.new(0.0000, -2.2500, 1.0625), glows = {
				} },
			},
		},
	},
}
