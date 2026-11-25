--!nonstrict
-- Daily
-- Сундук дня в долине (окно ChestWindow, сервер DailyService).
--
-- Правила (решение владельца 23.10.2026: «сделать систему»):
--   * один дар в сутки; сутки — по UTC (день = os.time() // 86400);
--   * серия 7 дней; забрал вчера → сегодня следующий день серии;
--   * пропустил день → серия начинается с 1-го дня;
--   * после 7-го дня серия идёт по кругу снова с 1-го.
-- Награды дней 1–6 — как в макете; Великий дар 7-го дня в макете без чисел
-- (доп.), поменять здесь.

local Daily = {}

Daily.Days = 7
Daily.SecondsPerDay = 86400

-- gold — золото; echo — эхо надетому оружию (на потолке → пыль, как у
-- повторки); dust — пыль эха. icon/text — карточка дня в окне.
Daily.Rewards = {
	{ gold = 50, icon = "coin", text = "50" },
	{ gold = 80, icon = "coin", text = "80" },
	{ echo = 1, icon = "soul", text = "1 эхо" },
	{ gold = 150, icon = "coin", text = "150" },
	{ dust = 20, icon = "dust", text = "20 пыли" },
	{ gold = 250, icon = "coin", text = "250" },
	{ gold = 400, echo = 2, dust = 30, icon = "chest", text = "Великий" },
}

-- Подпись «сегодня» на большой карточке.
function Daily.describe(reward): string
	local parts = {}
	if reward.gold then
		table.insert(parts, reward.gold .. " золота")
	end
	if reward.echo then
		table.insert(parts, reward.echo .. " эхо")
	end
	if reward.dust then
		table.insert(parts, reward.dust .. " пыли")
	end
	return table.concat(parts, " + ")
end

return Daily
