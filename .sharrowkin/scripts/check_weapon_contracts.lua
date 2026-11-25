local RS = game:GetService('ReplicatedStorage')
local copy = RS.Shared.Voxel.VoxelWeaponBuilder:Clone()
copy.Name = 'WeaponStep1Check'
copy.Parent = RS.Shared.Voxel
local builder = require(copy)
local count = 0
for _, module in ipairs({RS.Shared.Config.WeaponMeshData, RS.Shared.Config.WeaponMeshDataFloor2}) do
 local data = require(module)
 for id, spec in pairs(data) do
  local kind = string.find(id, 'hammer') or id == 'mud_mallet'
  kind = kind and 'hammer' or 'sword'
  for _, voxels in ipairs({false, true}) do
   local model = builder.build(kind, {weaponId=id, anchored=true, noFx=true, voxels=voxels})
   assert(model.Root:FindFirstChild('Grip') and model.Root:FindFirstChild('BladeBase') and model.Root:FindFirstChild('BladeTip'), id)
   for _, name in ipairs({'BladeLength','Extent','CenterY'}) do assert(type(model:GetAttribute(name)) == 'number', id..name) end
   if not voxels then assert(model:GetAttribute('WeaponMesh'), id..' missing mesh') end
   model:Destroy()
   count += 1
  end
 end
end
copy:Destroy()
return 'WEAPON_MODEL_CONTRACTS_OK '..count..' (assembled imported meshes + voxel fallback)'
