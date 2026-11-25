local RS = game:GetService('ReplicatedStorage')
local cmd = game.ServerStorage.KlinokDebug.Cmd
local player = game.Players:GetPlayers()[1]
local out = {}
for _, config in ipairs({RS.Shared.Config.WeaponMeshData, RS.Shared.Config.WeaponMeshDataFloor2}) do
 for id in pairs(require(config)) do
  local result = cmd:Invoke('give '..id)
  assert(string.find(result, 'надето'), id..': '..tostring(result))
  table.insert(out, id..': '..result)
 end
end
return 'PLAY_GIVE_OK 16\n'..table.concat(out, '\n')
