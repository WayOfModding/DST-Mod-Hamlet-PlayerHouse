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

local function printworldinfo()
  local world = _G.TheWorld

  print("KK-TEST> TheWorld = ", world)
  print("KK-TEST> IsCave() = ", world:IsCave())
  print("KK-TEST> #world.components = ", #world.components)
  print("KK-TEST> world.components = ", world.components)
end

local function OnLoadSim(player)
  local world = _G.TheWorld

  world.IsCave = function(self)
    return self:HasTag("cave")
  end

  printworldinfo()

  world:AddComponent("interiorspawner")
  print("KK-TEST> TheWorld.components.interiorspawner = ", world.components.interiorspawner)
end
AddSimPostInit(OnLoadSim)

--------------

if DEBUG then
  local TheInput = _G.TheInput
  local TEST_KEY = _G.KEY_V
  TheInput:AddKeyUpHandler(TEST_KEY, printworldinfo)
end
