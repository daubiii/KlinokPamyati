--!nonstrict
-- Bus (клиент)
-- Мини-шина событий между контроллерами. Контроллеры не требуют друг друга
-- напрямую, а обмениваются именованными событиями:
--   notify   { kind, text, rarity? }        — сообщение игроку
--   shake    { amount, time }               — тряска камеры
--   fov      { amount, time }               — рывок угла обзора
--   sfx      { name, position? }            — звук
--   lockInput { reason, locked }            — блокировка ввода

local Bus = {}

local listeners = {}

function Bus.on(name: string, callback)
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], callback)
end

function Bus.emit(name: string, data)
	local list = listeners[name]
	if not list then
		return
	end
	for _, callback in ipairs(list) do
		task.spawn(callback, data)
	end
end

return Bus
