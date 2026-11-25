--!nonstrict
-- Breakables
-- Разрушаемые декорации этажей 4–5 (механика по записке Артёма): что ломается,
-- сколько выдерживает, чем рассыпается. Сгенерировано из отчётов Blender
-- (props4b/props5_report.json), числа прочности и материалы — правятся здесь.
--
-- Модели: ReplicatedStorage.BreakableMeshes.<тип> — целая MeshPart <тип> и
-- обломки <тип>_frag1…N (опора — центр низа, без коллайдеров). Расстановка —
-- Floor4Breakables / Floor5Breakables (ID вида Brk_X_<зона>_NN).
--
--   hp        прочность (урон удара игрока по серверной дуге)
--   material  wood | metal | stone | paper | leather — звук, пыль, щепа
--   size      габарит целой модели (коллайдер = этот бокс), center — его центр от опоры
--   frags     обломки: имя, центр от опоры, размер (для разлёта на клиенте)
--   glow      светящаяся деталь (Neon): гаснет вместе с предметом

local V = Vector3.new

local Breakables = {}

-- Общие настройки (правятся на тестах).
Breakables.Settings = {
	enabled = true,
	hitSlop = 0.6, -- запас к дальности удара игрока, стад
	collide = true, -- целый предмет — препятствие (невидимый бокс)
	respawn = 0, -- 0 — не восстанавливаются до пересборки этажа; >0 — через N с
	debrisLife = 2.6, -- сколько живут обломки на клиенте, с
	debrisFade = 0.8, -- последние N с — растворение
	debrisMax = 120, -- предел одновременно летящих обломков у клиента
	fxRange = 140, -- дальше — без обломков, только звук
	kick = 18, -- сила разлёта обломков
	kickUp = 14,
	hitShake = 0.12, -- дрожь предмета от неразрушающего удара, стад
	hpScale = 1.0, -- общий множитель прочности
	floors = { [4] = true, [5] = true },
}

-- Материалы: звук удара и разрушения (имена Sfx), цвета пыли и щепы.
Breakables.Materials = {
	wood = { hit = "breakWoodHit", broke = "breakWood", dust = Color3.fromRGB(122, 98, 72), chip = Color3.fromRGB(150, 112, 72) },
	metal = { hit = "breakMetalHit", broke = "breakMetal", dust = Color3.fromRGB(90, 84, 92), chip = Color3.fromRGB(160, 150, 150) },
	stone = { hit = "breakStoneHit", broke = "breakStone", dust = Color3.fromRGB(120, 112, 118), chip = Color3.fromRGB(96, 90, 96) },
	paper = { hit = "breakPaperHit", broke = "breakPaper", dust = Color3.fromRGB(222, 214, 190), chip = Color3.fromRGB(236, 228, 204) },
	leather = { hit = "breakLeatherHit", broke = "breakLeather", dust = Color3.fromRGB(96, 70, 52), chip = Color3.fromRGB(120, 86, 60) },
}

Breakables.Types = {
	Brk_Barrel = {
		floor = 4, hp = 30, material = "wood",
		size = V(2.403, 3.002, 2.397), center = V(-0.003, 1.500, 0.000),
		frags = {
			{ name = "Brk_Barrel_frag1", offset = V(-0.685, 1.500, 0.477), size = V(1.026, 3.002, 1.443) },
			{ name = "Brk_Barrel_frag2", offset = V(0.487, 1.500, 0.685), size = V(1.423, 3.002, 1.026) },
			{ name = "Brk_Barrel_frag3", offset = V(0.685, 1.500, -0.477), size = V(1.026, 3.002, 1.443) },
			{ name = "Brk_Barrel_frag4", offset = V(-0.477, 1.500, -0.685), size = V(1.443, 3.002, 1.026) },
			{ name = "Brk_Barrel_frag5", offset = V(-0.000, 2.800, 0.000), size = V(1.620, 0.080, 1.669) },
		},
	},
	Brk_BookStack = {
		floor = 5, hp = 16, material = "paper",
		size = V(2.231, 1.627, 1.751), center = V(-0.030, 0.803, -0.132),
		frags = {
			{ name = "Brk_BookStack_frag1", offset = V(0.030, 0.230, 0.041), size = V(1.721, 0.460, 1.403) },
			{ name = "Brk_BookStack_frag2", offset = V(0.019, 0.610, 0.020), size = V(1.362, 0.300, 1.028) },
			{ name = "Brk_BookStack_frag3", offset = V(0.045, 0.950, 0.019), size = V(1.495, 0.380, 1.272) },
			{ name = "Brk_BookStack_frag4", offset = V(-0.022, 1.300, 0.048), size = V(1.209, 0.320, 1.033) },
			{ name = "Brk_BookStack_frag5", offset = V(-0.050, 1.536, -0.050), size = V(1.096, 0.152, 0.861) },
			{ name = "Brk_BookStack_frag6", offset = V(-0.030, 0.666, -0.220), size = V(2.231, 1.329, 1.575) },
		},
	},
	Brk_Bucket = {
		floor = 4, hp = 14, material = "wood",
		size = V(1.486, 1.867, 1.406), center = V(-0.000, 0.933, 0.000),
		frags = {
			{ name = "Brk_Bucket_frag1", offset = V(-0.274, 0.650, 0.256), size = V(0.854, 1.302, 0.894) },
			{ name = "Brk_Bucket_frag2", offset = V(0.418, 0.650, 0.093), size = V(0.570, 1.302, 1.220) },
			{ name = "Brk_Bucket_frag3", offset = V(-0.053, 0.650, -0.411), size = V(1.139, 1.302, 0.584) },
			{ name = "Brk_Bucket_frag4", offset = V(-0.000, 1.423, 0.000), size = V(1.486, 0.886, 0.160) },
			{ name = "Brk_Bucket_frag5", offset = V(-0.000, 0.535, 0.000), size = V(1.080, 1.010, 1.062) },
		},
	},
	Brk_Candelabra = {
		floor = 5, hp = 28, material = "metal",
		size = V(2.240, 4.749, 1.282), center = V(-0.000, 2.335, 0.169),
		glow = { name = "Brk_Candelabra_glow", offset = V(0.000, 4.403, 0.000), size = V(2.000, 1.134, 0.100), color = Color3.fromRGB(184, 227, 255) }, -- холодное пламя свечей (#B8E3FF)
		frags = {
			{ name = "Brk_Candelabra_frag1", offset = V(0.000, 0.235, 0.149), size = V(1.434, 0.549, 1.242) },
			{ name = "Brk_Candelabra_frag2", offset = V(-0.000, 1.225, 0.000), size = V(0.360, 1.550, 0.360) },
			{ name = "Brk_Candelabra_frag3", offset = V(-0.000, 2.940, 0.000), size = V(0.440, 1.980, 0.440) },
			{ name = "Brk_Candelabra_frag4", offset = V(0.533, 3.123, 0.000), size = V(1.173, 1.275, 0.340) },
			{ name = "Brk_Candelabra_frag5", offset = V(-0.533, 3.123, 0.000), size = V(1.173, 1.275, 0.340) },
			{ name = "Brk_Candelabra_frag6", offset = V(-0.000, 3.970, 0.000), size = V(2.080, 1.320, 0.220) },
		},
	},
	Brk_Chair = {
		floor = 5, hp = 20, material = "wood",
		size = V(1.620, 4.140, 1.530), center = V(-0.000, 2.070, -0.015),
		frags = {
			{ name = "Brk_Chair_frag1", offset = V(-0.000, 2.960, 0.630), size = V(1.479, 2.360, 0.120) },
			{ name = "Brk_Chair_frag2", offset = V(0.680, 1.985, 0.630), size = V(0.220, 3.970, 0.220) },
			{ name = "Brk_Chair_frag3", offset = V(-0.680, 1.985, 0.630), size = V(0.220, 3.970, 0.220) },
			{ name = "Brk_Chair_frag4", offset = V(-0.000, 0.943, 0.000), size = V(1.600, 1.195, 1.500) },
			{ name = "Brk_Chair_frag5", offset = V(-0.000, 1.645, 0.020), size = V(1.420, 0.210, 1.300) },
			{ name = "Brk_Chair_frag6", offset = V(-0.000, 0.715, -0.630), size = V(1.580, 1.430, 0.220) },
		},
	},
	Brk_CoalBin = {
		floor = 4, hp = 40, material = "wood",
		size = V(2.670, 2.365, 1.860), center = V(-0.000, 1.183, 0.000),
		frags = {
			{ name = "Brk_CoalBin_frag1", offset = V(-0.000, 0.615, -0.830), size = V(2.600, 1.070, 0.200) },
			{ name = "Brk_CoalBin_frag2", offset = V(-0.000, 0.890, 0.830), size = V(2.202, 1.620, 0.140) },
			{ name = "Brk_CoalBin_frag3", offset = V(1.200, 0.890, 0.104), size = V(0.220, 1.780, 1.611) },
			{ name = "Brk_CoalBin_frag4", offset = V(-1.200, 0.890, 0.000), size = V(0.220, 1.780, 1.820) },
			{ name = "Brk_CoalBin_frag5", offset = V(0.015, 1.280, -0.020), size = V(2.320, 0.749, 1.491) },
			{ name = "Brk_CoalBin_frag6", offset = V(-0.550, 1.494, 0.090), size = V(0.400, 1.741, 0.821) },
		},
	},
	Brk_Crate = {
		floor = 4, hp = 24, material = "wood",
		size = V(2.520, 2.281, 2.520), center = V(-0.000, 1.139, 0.000),
		frags = {
			{ name = "Brk_Crate_frag1", offset = V(-0.000, 1.190, -1.140), size = V(1.893, 2.019, 0.240) },
			{ name = "Brk_Crate_frag2", offset = V(-0.000, 1.100, 1.110), size = V(1.842, 1.680, 0.120) },
			{ name = "Brk_Crate_frag3", offset = V(1.110, 0.970, 0.000), size = V(0.180, 1.940, 1.842) },
			{ name = "Brk_Crate_frag4", offset = V(-1.140, 1.100, 0.000), size = V(0.240, 2.200, 1.893) },
			{ name = "Brk_Crate_frag5", offset = V(-0.000, 2.185, 0.000), size = V(2.322, 0.190, 1.840) },
			{ name = "Brk_Crate_frag6", offset = V(1.060, 1.100, 0.000), size = V(0.280, 2.202, 2.400) },
		},
	},
	Brk_Globe = {
		floor = 5, hp = 40, material = "wood",
		size = V(2.500, 3.651, 2.500), center = V(-0.000, 1.825, 0.000),
		frags = {
			{ name = "Brk_Globe_frag1", offset = V(-0.000, 2.550, -0.450), size = V(1.800, 1.800, 0.900) },
			{ name = "Brk_Globe_frag2", offset = V(-0.000, 2.550, 0.450), size = V(1.800, 1.800, 0.900) },
			{ name = "Brk_Globe_frag3", offset = V(-0.000, 2.550, 0.000), size = V(2.179, 2.179, 0.100) },
			{ name = "Brk_Globe_frag4", offset = V(-0.000, 2.500, 0.000), size = V(2.500, 0.090, 2.500) },
			{ name = "Brk_Globe_frag5", offset = V(0.000, 1.227, 0.000), size = V(2.164, 2.454, 2.164) },
			{ name = "Brk_Globe_frag6", offset = V(0.000, 1.227, -0.000), size = V(2.164, 2.454, 2.164) },
		},
	},
	Brk_HandBellows = {
		floor = 4, hp = 18, material = "leather",
		size = V(2.380, 1.479, 0.981), center = V(0.010, 0.712, 0.000),
		frags = {
			{ name = "Brk_HandBellows_frag1", offset = V(0.225, 1.400, 0.000), size = V(1.951, 0.100, 0.700) },
			{ name = "Brk_HandBellows_frag2", offset = V(0.225, 0.940, 0.000), size = V(1.951, 0.100, 0.700) },
			{ name = "Brk_HandBellows_frag3", offset = V(0.100, 1.175, 0.000), size = V(1.202, 0.350, 0.674) },
			{ name = "Brk_HandBellows_frag4", offset = V(-0.910, 1.170, 0.000), size = V(0.540, 0.220, 0.220) },
			{ name = "Brk_HandBellows_frag5", offset = V(0.550, 0.426, 0.000), size = V(0.160, 0.908, 0.981) },
		},
	},
	Brk_IngotStack = {
		floor = 4, hp = 60, material = "metal",
		size = V(2.212, 1.462, 1.760), center = V(0.006, 0.731, 0.000),
		frags = {
			{ name = "Brk_IngotStack_frag1", offset = V(-0.000, 0.150, 0.000), size = V(2.200, 0.300, 1.600) },
			{ name = "Brk_IngotStack_frag2", offset = V(-0.000, 0.150, 0.000), size = V(2.200, 0.300, 1.600) },
			{ name = "Brk_IngotStack_frag3", offset = V(0.500, 0.645, 0.000), size = V(0.960, 0.690, 1.760) },
			{ name = "Brk_IngotStack_frag4", offset = V(-0.397, 0.645, 0.000), size = V(1.166, 0.690, 1.760) },
			{ name = "Brk_IngotStack_frag5", offset = V(0.001, 1.220, 0.000), size = V(1.957, 0.460, 1.760) },
		},
	},
	Brk_Lectern = {
		floor = 5, hp = 34, material = "wood",
		size = V(2.000, 2.951, 1.520), center = V(-0.000, 1.476, 0.000),
		frags = {
			{ name = "Brk_Lectern_frag1", offset = V(-0.000, 2.539, -0.056), size = V(1.900, 0.661, 1.349) },
			{ name = "Brk_Lectern_frag2", offset = V(-0.000, 2.671, -0.036), size = V(1.500, 0.560, 0.981) },
			{ name = "Brk_Lectern_frag3", offset = V(-0.000, 2.170, 0.000), size = V(0.680, 0.560, 0.680) },
			{ name = "Brk_Lectern_frag4", offset = V(-0.000, 1.300, 0.000), size = V(0.680, 1.900, 0.680) },
			{ name = "Brk_Lectern_frag5", offset = V(-0.000, 0.185, 0.000), size = V(1.700, 0.370, 1.445) },
			{ name = "Brk_Lectern_frag6", offset = V(-0.000, 2.568, -0.008), size = V(2.000, 0.711, 1.297) },
		},
	},
	Brk_Minecart = {
		floor = 4, hp = 70, material = "metal",
		size = V(3.740, 2.178, 2.000), center = V(-0.000, 1.088, 0.000),
		frags = {
			{ name = "Brk_Minecart_frag1", offset = V(-0.000, 1.390, -0.812), size = V(3.160, 1.300, 0.375) },
			{ name = "Brk_Minecart_frag2", offset = V(-0.000, 1.390, 0.812), size = V(3.160, 1.300, 0.375) },
			{ name = "Brk_Minecart_frag3", offset = V(1.375, 1.385, 0.000), size = V(0.450, 1.310, 1.920) },
			{ name = "Brk_Minecart_frag4", offset = V(-1.375, 1.385, 0.000), size = V(0.450, 1.310, 1.920) },
			{ name = "Brk_Minecart_frag5", offset = V(-0.000, 0.440, 0.000), size = V(3.740, 0.881, 1.900) },
			{ name = "Brk_Minecart_frag6", offset = V(-0.010, 1.743, 0.021), size = V(2.856, 0.748, 1.680) },
		},
	},
	Brk_ScrollRack = {
		floor = 5, hp = 36, material = "wood",
		size = V(3.220, 3.600, 1.303), center = V(-0.000, 1.800, -0.052),
		frags = {
			{ name = "Brk_ScrollRack_frag1", offset = V(-0.000, 3.435, -0.020), size = V(3.220, 0.270, 1.240) },
			{ name = "Brk_ScrollRack_frag2", offset = V(-0.000, 1.740, 0.000), size = V(3.120, 3.480, 1.200) },
			{ name = "Brk_ScrollRack_frag3", offset = V(-1.440, 1.855, 0.000), size = V(0.120, 3.250, 1.100) },
			{ name = "Brk_ScrollRack_frag4", offset = V(-0.000, 1.800, 0.000), size = V(2.900, 3.100, 1.060) },
			{ name = "Brk_ScrollRack_frag5", offset = V(-0.000, 1.638, -0.061), size = V(2.510, 2.587, 0.985) },
			{ name = "Brk_ScrollRack_frag6", offset = V(-0.013, 1.643, -0.069), size = V(2.535, 2.596, 0.980) },
		},
	},
	Brk_SmallCabinet = {
		floor = 5, hp = 44, material = "wood",
		size = V(2.660, 4.056, 1.960), center = V(-0.000, 2.028, -0.300),
		glow = { name = "Brk_SmallCabinet_glow", offset = V(0.000, 3.830, 0.600), size = V(0.283, 0.283, 0.080), color = Color3.fromRGB(184, 227, 255) }, -- кристалл памяти (#B8E3FF)
		frags = {
			{ name = "Brk_SmallCabinet_frag1", offset = V(0.545, 2.150, -0.595), size = V(1.070, 2.340, 0.120) },
			{ name = "Brk_SmallCabinet_frag2", offset = V(-0.624, 2.150, -0.850), size = V(0.949, 2.340, 0.619) },
			{ name = "Brk_SmallCabinet_frag3", offset = V(-0.000, 3.703, -0.020), size = V(2.660, 0.706, 1.400) },
			{ name = "Brk_SmallCabinet_frag4", offset = V(-0.000, 1.675, 0.000), size = V(2.400, 3.350, 1.200) },
			{ name = "Brk_SmallCabinet_frag5", offset = V(-0.000, 0.580, -0.035), size = V(2.460, 0.760, 1.330) },
			{ name = "Brk_SmallCabinet_frag6", offset = V(0.010, 2.072, 0.050), size = V(2.019, 2.123, 0.750) },
		},
	},
	Brk_SmallMold = {
		floor = 4, hp = 36, material = "stone",
		size = V(1.750, 1.300, 2.760), center = V(-0.035, 0.650, 0.000),
		frags = {
			{ name = "Brk_SmallMold_frag1", offset = V(-0.000, 0.695, -1.160), size = V(1.502, 0.950, 0.360) },
			{ name = "Brk_SmallMold_frag2", offset = V(-0.000, 0.695, 1.160), size = V(1.502, 0.950, 0.360) },
			{ name = "Brk_SmallMold_frag3", offset = V(0.720, 0.695, 0.000), size = V(0.180, 0.990, 2.320) },
			{ name = "Brk_SmallMold_frag4", offset = V(-0.720, 0.695, 0.000), size = V(0.180, 0.990, 2.320) },
			{ name = "Brk_SmallMold_frag5", offset = V(-0.000, 0.745, -0.480), size = V(1.680, 1.050, 1.000) },
			{ name = "Brk_SmallMold_frag6", offset = V(-0.020, 0.585, 0.000), size = V(1.300, 1.170, 2.400) },
		},
	},
	Brk_ToolRack = {
		floor = 4, hp = 26, material = "wood",
		size = V(2.460, 2.727, 1.223), center = V(-0.000, 1.350, 0.000),
		frags = {
			{ name = "Brk_ToolRack_frag1", offset = V(1.100, 1.350, 0.000), size = V(0.240, 2.727, 1.223) },
			{ name = "Brk_ToolRack_frag2", offset = V(-1.100, 1.350, 0.000), size = V(0.240, 2.727, 1.223) },
			{ name = "Brk_ToolRack_frag3", offset = V(-0.000, 1.570, 0.000), size = V(2.400, 2.220, 0.620) },
			{ name = "Brk_ToolRack_frag4", offset = V(0.289, 1.780, -0.180), size = V(1.238, 1.660, 0.100) },
			{ name = "Brk_ToolRack_frag5", offset = V(-0.130, 1.477, -0.180), size = V(1.440, 1.895, 0.480) },
			{ name = "Brk_ToolRack_frag6", offset = V(0.022, 0.640, -0.005), size = V(1.845, 0.180, 0.500) },
		},
	},
}

-- Расстановка этажа: таблица из Floor<N>Breakables (если модуль есть).
function Breakables.placements(floorId: number)
	local module = script.Parent:FindFirstChild("Floor" .. floorId .. "Breakables")
	if not module then
		return {}
	end
	return require(module)
end

function Breakables.get(typeId: string)
	return Breakables.Types[typeId]
end

return Breakables
