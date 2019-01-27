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
