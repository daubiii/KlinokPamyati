// patch-floor1.js — заменяет клиентские вызовы RemoteEvent:FireServer на
// серверный мост FloorOneBridge в присланных скриптах режима.
'use strict';
const fs = require('fs');
const path = require('path');

const BASE = 'C:\\Users\\artem\\KlinokPamyati\\src\\ServerScriptService\\Floor1';

function patch(file, replacements) {
  const full = path.join(BASE, file);
  let text = fs.readFileSync(full, 'utf8');
  const results = [];
  for (const { from, to, label } of replacements) {
    if (text.includes(to) && !text.includes(from)) {
      results.push(`  уже пропатчено: ${label}`);
      continue;
    }
    if (!text.includes(from)) {
      results.push(`  НЕ НАЙДЕНО: ${label}`);
      continue;
    }
    text = text.split(from).join(to);
    results.push(`  ok: ${label}`);
  }
  fs.writeFileSync(full, text, 'utf8');
  return results;
}

const out = [];

out.push('EnemyBase.lua');
out.push(...patch('EnemyBase.lua', [
  {
    label: 'require моста',
    from: 'local HighlightManager = require(script.Parent.HighlightManager)',
    to: 'local HighlightManager = require(script.Parent.HighlightManager)\nlocal Bridge          = require(script.Parent.FloorOneBridge)',
  },
  {
    label: 'урон игроку',
    from: `function EnemyBase:DealDamage(amount, playerRoot)
	-- Отправляем серверу (RemoteEvent) — клиент не считает урон
	local evt = game.ReplicatedStorage:FindFirstChild("EnemyDealDamage")
	if evt then
		evt:FireServer({ source = self.Model, target = self.Player, damage = amount })
	end
end`,
    to: `function EnemyBase:DealDamage(amount, playerRoot)
	-- Скрипты режима работают на сервере, поэтому FireServer здесь невозможен:
	-- урон применяет мост, а RemoteEvent уходит клиенту как уведомление.
	Bridge.enemyDealDamage({ source = self.Model, target = self.Player, damage = amount })
end`,
  },
  {
    label: 'награда за убийство',
    from: `	local cfg = self.Config
	local evt = game.ReplicatedStorage:FindFirstChild("EnemyKilled")
	if evt then
		evt:FireServer({
			player     = self.Player,
			gold       = cfg.Gold,
			exp        = cfg.Exp,
			soulStacks = cfg.SoulStacks,
			material   = cfg.MaterialDrop,
		})
	end`,
    to: `	local cfg = self.Config
	Bridge.enemyKilled({
		player     = self.Player,
		gold       = cfg.Gold,
		exp        = cfg.Exp,
		soulStacks = cfg.SoulStacks,
		material   = cfg.MaterialDrop,
	})`,
  },
]));

out.push('GatekeeperBoss.lua');
out.push(...patch('GatekeeperBoss.lua', [
  {
    label: 'require моста',
    from: 'local Highlight    = require(script.Parent.HighlightManager)',
    to: 'local Highlight    = require(script.Parent.HighlightManager)\nlocal Bridge       = require(script.Parent.FloorOneBridge)',
  },
  {
    label: 'урон босса игроку',
    from: `	local evt = game.ReplicatedStorage:FindFirstChild("BossDealDamage")
	if evt then
		evt:FireServer({ source = self.Model, target = self.Player, damage = amount })
	end`,
    to: `	Bridge.enemyDealDamage({ source = self.Model, target = self.Player, damage = amount })`,
  },
  {
    label: 'награда за босса',
    from: `	local evt = game.ReplicatedStorage:FindFirstChild("BossKilled")
	if evt then
		local rewards = self.Config.Rewards
		evt:FireServer({
			player   = self.Player,
			exp      = rewards.Exp,
			gold     = rewards.Gold,
			material = rewards.Material,
			soul     = rewards.SoulDrops,
		})
	end`,
    to: `	local rewards = self.Config.Rewards
	Bridge.bossKilled({
		player   = self.Player,
		exp      = rewards.Exp,
		gold     = rewards.Gold,
		material = rewards.Material,
		soul     = rewards.SoulDrops,
	})

	-- Сообщаем менеджеру комнат, что босс побеждён: иначе этаж не завершится.
	if self.OnDefeated then
		self.OnDefeated()
	end`,
  },
]));

out.push('RoomManager.lua');
out.push(...patch('RoomManager.lua', [
  {
    label: 'require моста',
    from: 'local WaveManager  = require(script.Parent.WaveManager)',
    to: 'local WaveManager  = require(script.Parent.WaveManager)\nlocal Bridge       = require(script.Parent.FloorOneBridge)',
  },
  {
    label: 'отдых у костра',
    from: `			local evt = game.ReplicatedStorage:FindFirstChild("CampfireRest")
				if evt then evt:FireServer(player) end`,
    to: `			Bridge.campfireRest(player)`,
  },
  {
    label: 'спавн босса',
    from: `		local bossEvt = game.ReplicatedStorage:FindFirstChild("SpawnBoss")
		if bossEvt then
			bossEvt:FireServer({ player = self.Player, roomModel = room.model })
		end`,
    to: `		Bridge.spawnBoss({ player = self.Player, roomModel = room.model })`,
  },
  {
    label: 'этаж пройден',
    from: `	local evt = game.ReplicatedStorage:FindFirstChild("FloorComplete")
	if evt then evt:FireServer(self.Player) end`,
    to: `	Bridge.floorComplete(self.Player)`,
  },
]));

// SOUNDS в HighlightManager: заполняем явными заглушками с подсказкой.
out.push('HighlightManager.lua');
out.push(...patch('HighlightManager.lua', [
  {
    label: 'звуки-заглушки',
    from: `local SOUNDS = {
	white = "rbxassetid://0", -- замени ID звука
	red   = "rbxassetid://0",
}`,
    to: `-- ID звуков нужно вставить после загрузки OGG в Roblox (Audio/manifest.json
-- в пакете этажа). Пока здесь пусто: Sound с rbxassetid://0 молчит, ошибок
-- не вызывает. Формат: "rbxassetid://ВАШ_ID".
local SOUNDS = {
	white = "", -- белый замах: лёгкий звон (Audio/swing.ogg)
	red   = "", -- красный замах: низкий гудок (Audio/swing_heavy.ogg)
}`,
  },
]));

console.log(out.join('\n'));
