local _G = GLOBAL
local require = _G.require

local DEBUG = true

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
  local world = _G.TheWorld
  print("KK-TEST> TheWorld = ", world)
  --world:AddComponent("interiorspawner")
  --print("KK-TEST> TheWorld.components.interiorspawner = ", world.components.interiorspawner)

  world.IsCave = function(self)
    return self:HasTag("cave")
  end
end
AddSimPostInit(OnLoadSim)

--------------

if DEBUG then
  local TheInput = _G.TheInput
  local TEST_KEY = _G.KEY_V
  TheInput:AddKeyUpHandler(TEST_KEY, function()
    local world = _G.TheWorld
    print("KK-TEST> IsCave() = ", world:IsCave())
  end)
end
