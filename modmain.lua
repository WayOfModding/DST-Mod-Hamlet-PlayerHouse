local _G = GLOBAL
local require = _G.require

Assets =
{
  Asset("ATLAS", "images/modimages.xml"),
  Asset("IMAGE", "images/modimages.tex"),
}

PrefabFiles =
{
  "playerhouse_city",
}

require "modrecipes"
require "modstrings"

local function OnLoadSim(player)
  print("KK-TEST> TheWorld = ", _G.TheWorld)
  _G.TheWorld:AddComponent("interiorspawner")
  print("KK-TEST> TheWorld.components.interiorspawner = ", TheWorld.components.interiorspawner)
end
AddSimPostInit(OnLoadSim)
