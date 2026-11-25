--!nonstrict
-- MotionGuard — серверный сторож перемещений (PLAN_DORABOTKI P1-4).
-- Физику персонажа ведёт клиент, поэтому телепорт и спидхак проходили
-- безнаказанно: проверка дальности рывка только писала warn. Сторож меряет
-- смещение персонажа между проверками и сверяет с допустимым: скорость берём
-- из Humanoid (сервер её знает и сам меняет) + запасы на рывок, ускорения
-- способностей, падения и пинг.
--
-- РЕЖИМ. ENFORCE = true (с 11.11.2026): прогон показал ноль ложных
-- срабатываний на честное движение (отбрасывания ударами, лифты, падения
-- учтены в допусках), сторож возвращает нарушителя на последнюю валидную
-- точку. Кика здесь нет и не будет без отдельного решения владельца.
--
-- Легальные перебросы (телепорт по зонам, возврат за карту) помечаются
-- MotionGuard.markLegal(player, секунд): окно пропускается, базовая точка
-- обновляется без штрафа.
local Players = game:GetService("Players")

local MotionGuard = {}

-- Возврат нарушителя на валидную точку. Прогон 11.11.2026 прошёл чисто,
-- ложных срабатываний на честное движение не было — включено (PLAN_DORABOTKI P1-4).
local ENFORCE = true

local CHECK_INTERVAL = 0.35
local BASE_ALLOW = 5    -- ускорения способностей, платформы, округление
local DASH_ALLOW = 7    -- рывок и отбрасывания за один интервал
local PING_ALLOW = 12   -- запас на пинг и джиттер (медленный Wi-Fi)
local SPAWN_GRACE = 3   -- секунд после спавна/переброса без проверки
local WARN_EVERY = 20   -- повторный warn — каждый 20-й случай, не спамим

local watched = {} -- [player] = { root, last, legalUntil, violations, warnCount }

local function bindCharacter(w, character)
	w.violations = 0
	w.legalUntil = os.clock() + SPAWN_GRACE
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and character.Parent then
			w.root = root
			w.last = root.Position
		end
	end)
end

local function watch(player)
	local w = { root = nil, last = nil, legalUntil = 0, violations = 0, warnCount = 0 }
	watched[player] = w
	player.CharacterAdded:Connect(function(character)
		bindCharacter(w, character)
	end)
	if player.Character then
		bindCharacter(w, player.Character)
	end
end

-- Переброс системы (телепорт по зонам, возврат за карту): окно без проверки.
function MotionGuard.markLegal(player, seconds: number?)
	local w = watched[player]
	if not w then
		return
	end
	w.legalUntil = os.clock() + math.clamp(seconds or SPAWN_GRACE, 0.5, 60)
end

local function tickLoop()
	while true do
		task.wait(CHECK_INTERVAL)
		local now = os.clock()
		for player, w in pairs(watched) do
			if not player.Parent then
				watched[player] = nil
			else
				local root = w.root
				if not root or not root.Parent then
					continue -- персонаж пересобирается: базу поставит CharacterAdded
				end
				local pos = root.Position
				if now < w.legalUntil then
					w.last = pos
				else
					local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
					local speed = (humanoid and humanoid.WalkSpeed) or 16
					local allowed = BASE_ALLOW + DASH_ALLOW + PING_ALLOW + speed * CHECK_INTERVAL
					local offset = Vector3.new(pos.X - w.last.X, 0, pos.Z - w.last.Z).Magnitude
					if offset <= allowed then
						w.last = pos
						w.violations = math.max(0, w.violations - 1) -- штраф остывает
					else
						w.violations += 1
						w.warnCount += 1
						if ENFORCE and w.violations >= 3 then
							root.CFrame = CFrame.new(w.last) * root.CFrame.Rotation
						else
							w.last = pos -- наблюдение: принимаем точку, каскада не будет
						end
						if w.warnCount == 1 or w.warnCount % WARN_EVERY == 0 then
							warn(("[MotionGuard] %s: скачок %.0f стадов (допустимо %.0f)%s"):format(
								player.Name, offset, allowed, ENFORCE and " — возвращён" or " — режим наблюдения"))
						end
					end
				end
			end
		end
	end
end

function MotionGuard.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		watched[player] = nil
	end)
	task.spawn(tickLoop)
	print("[MotionGuard] сторож перемещений запущен, режим: " .. (ENFORCE and "принуждение" or "наблюдение"))
end

return MotionGuard
