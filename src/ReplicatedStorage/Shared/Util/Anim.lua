--!nonstrict
-- Anim
-- Мелкая математика для процедурных анимаций: сглаживание и кривые поз.
-- Анимации в игре строятся кодом (Motor6D / CFrame), потому что
-- KeyframeSequence, собранный скриптом, работает только в Studio, а в
-- опубликованной игре проигрываются лишь загруженные в Roblox анимации.
--
-- Поза — плоская таблица { имя_ключа = число }. Кривая — список кадров
--   { t = секунды, ease = "quadOut", rs_x = 40, re_x = 10, ... }
-- Ключ, которого нет в кадре, считается нулём.

local Anim = {}

local function backOut(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

Anim.ease = {
	linear = function(t: number): number
		return t
	end,
	quadIn = function(t: number): number
		return t * t
	end,
	quadOut = function(t: number): number
		return 1 - (1 - t) * (1 - t)
	end,
	quadInOut = function(t: number): number
		if t < 0.5 then
			return 2 * t * t
		end
		return 1 - 2 * (1 - t) * (1 - t)
	end,
	sine = function(t: number): number
		return 0.5 - 0.5 * math.cos(math.pi * t)
	end,
	backOut = backOut,
	-- Резкий старт и мягкое затухание: удар.
	snap = function(t: number): number
		return 1 - (1 - t) ^ 4
	end,
}

function Anim.clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

function Anim.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Экспоненциальное сглаживание, не зависящее от частоты кадров.
function Anim.damp(current: number, target: number, rate: number, dt: number): number
	return target + (current - target) * math.exp(-rate * dt)
end

function Anim.dampVector(current: Vector3, target: Vector3, rate: number, dt: number): Vector3
	return target + (current - target) * math.exp(-rate * dt)
end

-- Длительность кривой.
function Anim.duration(frames): number
	local last = frames[#frames]
	return last and last.t or 0
end

local function clear(out)
	for key in pairs(out) do
		out[key] = nil
	end
end

-- Записать в out позу кривой в момент time.
function Anim.sample(frames, time: number, out)
	clear(out)
	local count = #frames
	if count == 0 then
		return out
	end

	local first = frames[1]
	if time <= first.t or count == 1 then
		for key, value in pairs(first) do
			if key ~= "t" and key ~= "ease" then
				out[key] = value
			end
		end
		return out
	end

	local last = frames[count]
	if time >= last.t then
		for key, value in pairs(last) do
			if key ~= "t" and key ~= "ease" then
				out[key] = value
			end
		end
		return out
	end

	local index = 1
	while index < count - 1 and time >= frames[index + 1].t do
		index += 1
	end
	local a = frames[index]
	local b = frames[index + 1]
	local span = b.t - a.t
	local u = span > 0 and (time - a.t) / span or 1
	local easing = Anim.ease[b.ease or "quadInOut"] or Anim.ease.quadInOut
	local e = easing(math.clamp(u, 0, 1))

	for key, value in pairs(a) do
		if key ~= "t" and key ~= "ease" then
			out[key] = value + ((b[key] or 0) - value) * e
		end
	end
	for key, value in pairs(b) do
		if key ~= "t" and key ~= "ease" and a[key] == nil then
			out[key] = value * e
		end
	end
	return out
end

return Anim
