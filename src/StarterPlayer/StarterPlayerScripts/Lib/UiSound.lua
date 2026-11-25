--!nonstrict
-- UiSound (клиент)
-- Звуки интерфейса и наград.
--   * UiAssets.Sounds — одиночные звуки с id (и встроенной заглушкой fallback);
--   * UiSound.Mix — «сведённые» звуки из нескольких слоёв лицензированных
--     звуков (Pro Sound Effects, APM, встроенные звуки движка): перелистывание,
--     печать, «голос» жителя, удар по наковальне и т.п.
-- Если в UiAssets.Sounds у звука вписан свой загруженный id (например,
-- page_turn из assets/sfx_ui), играет он; иначе — слои из Mix.
--
-- UiSound.play(name, { pitch, volume }) — pitch умножает высоту всех слоёв.
--
-- Палитра v3 (07.11.2026): если у ключа есть замена в UiAssets.PaletteFor и у
-- звука палитры вписан id, играет он (один файл вместо слоёв). Все звуки
-- интерфейса идут через SoundGroup «KlinokUi» (громкость UiAssets.UiVolume).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local UiAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiAssets"))

local UiSound = {}

-- Лицензированные звуки (те же, что в Config/Sfx).
local PSE = {
	airWhoosh = "rbxassetid://9126283272", -- Wood Swish Ruler Whoosh
	energyWhoosh = "rbxassetid://9125517884", -- Electric Whoosh Low End
	shieldClang1 = "rbxassetid://9119072660",
	shieldClang2 = "rbxassetid://9119072674",
	metalRattle = "rbxassetid://9116797354",
	waterImpact = "rbxassetid://9119481909",
	rockCrunch = "rbxassetid://9118633662",
	magicChime = "rbxassetid://9116394545",
}
local APM = { percHit = "rbxassetid://9045209987" }
local ENGINE = {
	click = "rbxasset://sounds/clickfast.wav",
	button = "rbxasset://sounds/button.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
	snap = "rbxasset://sounds/snap.mp3",
	bass = "rbxasset://sounds/bass.wav",
}

-- Слой: s — имя звука из UiAssets.Sounds ИЛИ готовый id; v — громкость;
-- p — {мин, макс} высоты; d — задержка; len — обрезать через len секунд.
local function L(s: string, v: number, p1: number, p2: number?, d: number?, len: number?)
	return { s = s, v = v, p = { p1, p2 or p1 }, d = d, len = len }
end

UiSound.Mix = {
	-- Книга и бумага
	page_turn = { L(PSE.airWhoosh, 0.32, 1.55, 1.75, nil, 0.32), L(ENGINE.snap, 0.12, 2.3, 2.6, 0.1), L("ui_hover", 0.5, 0.7, 0.75, 0.16) },
	page_back = { L(PSE.airWhoosh, 0.3, 1.35, 1.5, nil, 0.32), L(ENGINE.snap, 0.12, 2.1, 2.3, 0.12) },
	paper_slide = { L(PSE.airWhoosh, 0.18, 2.0, 2.3, nil, 0.2) },
	tab_select = { L("ui_click", 1, 0.86, 0.9), L(ENGINE.snap, 0.1, 2.6, 2.8, 0.02) },
	stamp = { L(APM.percHit, 0.42, 1.55, 1.7, nil, 0.25), L("forge_strike", 0.35, 1.7, 1.8, nil, 0.3), L(ENGINE.snap, 0.15, 0.9, 1.0) },
	-- Разговор
	dialog_open = { L(PSE.airWhoosh, 0.26, 1.05, 1.15, nil, 0.4), L(PSE.magicChime, 0.16, 1.25, 1.3, 0.08, 0.9) },
	dialog_close = { L(PSE.airWhoosh, 0.22, 1.4, 1.5, nil, 0.3) },
	dialog_next = { L("ui_click", 0.8, 1.18, 1.24) },
	talk_blip = { L(ENGINE.click, 0.11, 0.95, 1.05, nil, 0.07) },
	choice_hover = { L("ui_hover", 0.9, 1.25, 1.35) },
	choice_pick = { L("ui_click", 1, 1.0, 1.0), L(PSE.magicChime, 0.12, 1.6, 1.7, 0.03, 0.45) },
	new_topic = { L(PSE.magicChime, 0.2, 1.45, 1.5, nil, 0.7) },
	-- Кузня Эха
	forge_heat = { L(PSE.energyWhoosh, 0.32, 0.6, 0.66, nil, 1.1), L(ENGINE.bass, 0.18, 0.5, 0.55) },
	forge_anvil = { L("forge_strike", 1, 0.95, 1.05), L(PSE.shieldClang2, 0.28, 0.9, 1.0, nil, 0.7), L(ENGINE.bass, 0.22, 0.68, 0.74) },
	forge_spark = { L(PSE.shieldClang1, 0.1, 2.0, 2.3, nil, 0.22), L(ENGINE.ping, 0.08, 2.3, 2.5) },
	forge_reveal = { L("forge_success", 1, 1, 1), L(PSE.magicChime, 0.4, 0.95, 1.0, 0.1, 1.6) },
	forge_quench = { L(PSE.waterImpact, 0.4, 1.15, 1.25, nil, 0.7), L(PSE.energyWhoosh, 0.22, 1.5, 1.6, 0.05, 0.8), L(PSE.rockCrunch, 0.16, 1.3, 1.4, 0.02, 0.4) },
	echo_socket = { L("echo_absorb", 0.7, 1.25, 1.35), L(ENGINE.ping, 0.08, 1.9, 2.0) },
	star_on = { L("reward_pop", 1, 1, 1), L(PSE.magicChime, 0.18, 1.3, 1.35, nil, 0.6) },
	list_tick = { L("ui_hover", 0.7, 1.5, 1.6) },
	confirm = { L("ui_click", 1, 0.75, 0.8), L(PSE.metalRattle, 0.12, 1.5, 1.6, 0.02, 0.25) },
	-- Камень, свечи, врата
	stone_slab = { L(PSE.rockCrunch, 0.22, 1.05, 1.2, nil, 0.35), L(ENGINE.bass, 0.12, 0.8, 0.9) },
	stone_tick = { L(PSE.rockCrunch, 0.1, 1.7, 1.9, nil, 0.14) },
	medal = { L(PSE.shieldClang1, 0.16, 1.5, 1.6, nil, 0.5), L(PSE.magicChime, 0.14, 1.2, 1.25, 0.04, 0.8) },
	candle = { L(PSE.energyWhoosh, 0.1, 1.8, 2.0, nil, 0.35) },
	gate_rumble = { L(PSE.rockCrunch, 0.3, 0.6, 0.7, nil, 0.9), L(ENGINE.bass, 0.25, 0.5, 0.55), L(PSE.energyWhoosh, 0.18, 0.7, 0.75, 0.15, 1.0) },
	floor_pick = { L("ui_click", 1, 0.9, 0.95), L(PSE.magicChime, 0.14, 1.0, 1.05, 0.02, 0.6) },
	coin_tick = { L("coins", 0.5, 1.4, 1.6, nil, 0.2) },
	-- Сундуки этажей v3: полёт в сумку и сцена «Клинок читает память»
	chest_appear = { L(PSE.magicChime, 0.22, 0.8, 0.85, nil, 0.9), L(PSE.energyWhoosh, 0.16, 1.4, 1.5, 0.05, 0.6) },
	chest_fly = { L(PSE.airWhoosh, 0.34, 0.9, 1.0, nil, 0.5), L(PSE.energyWhoosh, 0.14, 1.6, 1.7, 0.05, 0.5) },
	chest_pickup = { L("reward_pop", 0.9, 0.9, 0.95), L(PSE.metalRattle, 0.2, 1.1, 1.2, 0.02, 0.35), L(PSE.magicChime, 0.16, 1.4, 1.45, 0.05, 0.7) },
	chest_land = { L(PSE.rockCrunch, 0.3, 0.8, 0.9, nil, 0.4), L(ENGINE.bass, 0.26, 0.6, 0.65), L(PSE.metalRattle, 0.14, 0.9, 1.0, 0.03, 0.3) },
	blade_form = { L("echo_absorb", 0.7, 0.8, 0.85), L(PSE.magicChime, 0.24, 0.7, 0.75, 0.1, 1.2) },
	blade_strike = { L("forge_strike", 1, 1.15, 1.2), L(PSE.shieldClang1, 0.34, 1.2, 1.3, nil, 0.6), L(ENGINE.bass, 0.3, 0.55, 0.6) },
	lid_open = { L("chest_open", 0.9, 1, 1), L(PSE.energyWhoosh, 0.2, 0.9, 1.0, 0.05, 0.9) },
	memory_tick = { L(PSE.magicChime, 0.2, 1.0, 1.0, nil, 0.5), L(ENGINE.ping, 0.06, 1.6, 1.7) },
	memory_secret = { L("echo_absorb", 1, 0.6, 0.62), L(PSE.magicChime, 0.4, 0.5, 0.52, 0.05, 1.8), L(PSE.energyWhoosh, 0.3, 0.5, 0.55, 0.1, 1.2) },
	item_reveal = { L("forge_success", 0.9, 1.05, 1.1), L(PSE.magicChime, 0.3, 1.2, 1.25, 0.08, 1.4) },
	-- «Дары Эха» (FloorBoonController): остановка времени, карточки, выбор
	boon_stop = { L(ENGINE.bass, 0.5, 0.42, 0.46), L(PSE.shieldClang2, 0.22, 0.38, 0.4, 0.02, 1.2), L(PSE.energyWhoosh, 0.32, 0.5, 0.55, nil, 1.1), L(PSE.magicChime, 0.24, 0.5, 0.52, 0.2, 1.8) },
	boon_rise = { L(PSE.airWhoosh, 0.22, 1.25, 1.45, nil, 0.3) },
	boon_flip = { L(PSE.airWhoosh, 0.18, 1.85, 2.05, nil, 0.2), L(ENGINE.snap, 0.1, 1.9, 2.1, 0.03) },
	boon_reveal_rare = { L(PSE.magicChime, 0.32, 1.1, 1.15, nil, 1.1), L(ENGINE.ping, 0.1, 1.5, 1.55, 0.05) },
	boon_reveal_legend = { L("forge_success", 0.75, 1.15, 1.2), L(PSE.magicChime, 0.42, 0.85, 0.9, 0.04, 1.8), L(ENGINE.bass, 0.3, 0.6, 0.65) },
	boon_hover = { L("ui_hover", 0.9, 1.15, 1.25), L(PSE.magicChime, 0.06, 1.9, 2.0, nil, 0.25) },
	boon_pick = { L("reward_pop", 1, 1, 1), L(PSE.magicChime, 0.32, 1.25, 1.3, 0.03, 1.1), L(APM.percHit, 0.22, 1.6, 1.7, nil, 0.3) },
	boon_pick_legend = { L("reward_pop", 1, 0.9, 0.9), L("level_up", 0.6, 1.1, 1.1, 0.05), L(PSE.magicChime, 0.42, 1.0, 1.05, 0.03, 1.6), L(ENGINE.bass, 0.3, 0.7, 0.75) },
	boon_resume = { L(PSE.energyWhoosh, 0.34, 1.2, 1.3, nil, 0.8), L(PSE.airWhoosh, 0.25, 0.8, 0.9, 0.05, 0.5), L(ENGINE.ping, 0.12, 1.2, 1.25, 0.12) },
	boon_tick = { L(ENGINE.click, 0.16, 1.25, 1.3, nil, 0.1) },
	-- мана мага: не хватает на заклинание (глухой «пустой» звон)
	mana_empty = { L(PSE.magicChime, 0.16, 0.55, 0.6, nil, 0.45), L(ENGINE.click, 0.12, 0.75, 0.8) },
}

local cache = {}
local lastPlayed = {}

local uiGroup = SoundService:FindFirstChild("KlinokUi")
if not (uiGroup and uiGroup:IsA("SoundGroup")) then
	uiGroup = Instance.new("SoundGroup")
	uiGroup.Name = "KlinokUi"
	uiGroup.Volume = UiAssets.UiVolume or 0.8
	uiGroup.Parent = SoundService
end

local function realId(id): boolean
	return typeof(id) == "string" and id ~= "" and not id:match("://0$")
end

local function resolve(spec)
	if realId(spec.id) then
		return spec.id
	end
	return spec.fallback
end

local function baseSound(key: string, id: string, volume: number)
	local base = cache[key]
	if not base then
		base = Instance.new("Sound")
		base.Name = "Ui_" .. key
		base.SoundId = id
		base.Volume = volume
		base.Parent = SoundService
		cache[key] = base
	end
	return base
end

local function fire(key: string, id: string, volume: number, pitch: number, length: number?)
	local sound = baseSound(key, id, volume):Clone()
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.SoundGroup = uiGroup
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	if length then
		task.delay(length, function()
			if sound.Parent then
				-- короткий спад вместо щелчка
				local tween = game:GetService("TweenService"):Create(sound, TweenInfo.new(0.06), { Volume = 0 })
				tween:Play()
				task.delay(0.07, function()
					sound:Destroy()
				end)
			end
		end)
	end
	task.delay(8, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	return sound
end

local function playLayer(layer, opts)
	local pitchMul = opts and opts.pitch or 1
	local volMul = opts and opts.volume or 1
	local spec = UiAssets.Sounds[layer.s]
	local id, volume
	if spec then
		id = resolve(spec)
		volume = (spec.volume or 0.5) * layer.v
	else
		id = layer.s
		volume = layer.v
	end
	if not id then
		return
	end
	local pitch = (layer.p[1] + (layer.p[2] - layer.p[1]) * math.random()) * pitchMul
	if layer.d and layer.d > 0 then
		task.delay(layer.d, fire, layer.s, id, volume * volMul, pitch, layer.len)
	else
		fire(layer.s, id, volume * volMul, pitch, layer.len)
	end
end

-- name — ключ из UiAssets.Sounds или UiSound.Mix. opts.pitch, opts.volume (множитель),
-- opts.gap — минимальный интервал повтора (по умолчанию 40 мс).
function UiSound.play(name: string, opts)
	local now = os.clock()
	local gap = opts and opts.gap or 0.04
	if lastPlayed[name] and now - lastPlayed[name] < gap then
		return nil
	end
	-- палитра v3: новый звук, если он уже загружен
	local paletteKey = UiAssets.PaletteFor and UiAssets.PaletteFor[name]
	local palette = paletteKey and UiAssets.Palette[paletteKey]
	if palette and realId(palette.id) then
		lastPlayed[name] = now
		-- высоту подстраиваем мягче: каскады (pitch 0,85…1,3) не должны пищать
		local pitch = opts and opts.pitch or 1
		pitch = 1 + (pitch - 1) * 0.5
		return fire("P_" .. paletteKey, palette.id, (palette.volume or 0.3) * (opts and opts.volume or 1), pitch)
	end
	local spec = UiAssets.Sounds[name]
	local mix = UiSound.Mix[name]
	-- свой загруженный звук важнее слоёв
	if spec and (realId(spec.id) or not mix) then
		local id = resolve(spec)
		if not id then
			return nil
		end
		lastPlayed[name] = now
		return fire(name, id, (spec.volume or 0.5) * (opts and opts.volume or 1), opts and opts.pitch or 1)
	end
	if mix then
		lastPlayed[name] = now
		for _, layer in ipairs(mix) do
			playLayer(layer, opts)
		end
	end
	return nil
end

-- «Голос» жителя: короткий слог на каждую 2–3 букву. voice = { pitch, spread }.
-- Есть ли у ключа готовая замена из палитры (AudioController отдаёт такие сюда).
function UiSound.hasPalette(name: string): boolean
	local paletteKey = UiAssets.PaletteFor and UiAssets.PaletteFor[name]
	local palette = paletteKey and UiAssets.Palette[paletteKey]
	return palette ~= nil and realId(palette.id)
end

function UiSound.blip(voice)
	local base = voice and voice.pitch or 1
	local spread = voice and voice.spread or 0.08
	UiSound.play("talk_blip", { pitch = base * (1 - spread + math.random() * spread * 2), gap = 0.03, volume = voice and voice.volume or 1 })
end

return UiSound
