require("constants")

local StaticLayout = require("map/static_layout")
local ExampleLayout =
{
  --PORKLAND
  ["PorklandStart"] = StaticLayout.Get("map/static_layouts/porkland_start"),
  ["PigRuinsEntrance1"] = StaticLayout.Get("map/static_layouts/pig_ruins_entrance_1",{
    areas = {
        item1 = function() if math.random()<1 then return {"smashingpot"} else return nil end end,
        item2 = function() if math.random()<1 then return {"smashingpot"} else return nil end end,
        item3 = function() if math.random()<1 then return {"smashingpot"} else return nil end end
      }
  }),
  ["PigRuinsExit1"] = StaticLayout.Get("map/static_layouts/pig_ruins_exit_1"),
  ["PigRuinsEntrance2"] = StaticLayout.Get("map/static_layouts/pig_ruins_entrance_2"),
  ["PigRuinsExit2"] = StaticLayout.Get("map/static_layouts/pig_ruins_exit_2",{
    areas = { item1 = function() if math.random()<0.7 then return {"smashingpot"} else return nil end end,
          item2 = function() if math.random()<0.7 then return {"smashingpot"} else return nil end end,
          item3 = function() if math.random()<0.7 then return {"smashingpot"} else return nil end end
      }
  }),

  ["PigRuinsEntrance3"] = StaticLayout.Get("map/static_layouts/pig_ruins_entrance_3"),
  ["PigRuinsEntrance4"] = StaticLayout.Get("map/static_layouts/pig_ruins_entrance_4",{
    areas = {
        item1 = function() if math.random()<1 then return {"smashingpot"} else return nil end end,
        item2 = function() if math.random()<1 then return {"smashingpot"} else return nil end end,
        item3 = function() if math.random()<1 then return {"smashingpot"} else return nil end end
      }
  }),
  ["PigRuinsExit4"] = StaticLayout.Get("map/static_layouts/pig_ruins_exit_4",{
    areas = { item1 = function() if math.random()<0.7 then return {"smashingpot"} else return nil end end,
          item2 = function() if math.random()<0.7 then return {"smashingpot"} else return nil end end,
          item3 = function() if math.random()<0.7 then return {"smashingpot"} else return nil end end
      }
  }),
  ["PigRuinsEntrance5"] = StaticLayout.Get("map/static_layouts/pig_ruins_entrance_5",{
    areas = {
        item1 = function() if math.random()<1 then return {"smashingpot"} else return nil end end,
        item2 = function() if math.random()<1 then return {"smashingpot"} else return nil end end,
        item3 = function() if math.random()<1 then return {"smashingpot"} else return nil end end
      }
  }),

  ["lilypad"] = StaticLayout.Get("map/static_layouts/lilypad", {
    water = true,
    areas = { resource_area = {"lilypad"}},
  }),
  ["lilypad2"] = StaticLayout.Get("map/static_layouts/lilypad_2", {
    water = true,
    areas = { resource_area = {"lilypad"},
          resource_area2 = {"lilypad"}
          },
  }),
  ["PigRuinsHead"] = StaticLayout.Get("map/static_layouts/pig_ruins_head",{
    areas = { item1 = {"pig_ruins_head"},
          item2 = function()
                local list = {"smashingpot","grass","pig_ruins_torch"}
                for i=#list,1,-1 do
                  if math.random()<0.7 then
                    table.remove(list,i)
                  end
                end
                return list
              end,
          },
  }),
  ["PigRuinsArtichoke"] = StaticLayout.Get("map/static_layouts/pig_ruins_artichoke",{
    areas = { item1 = function() if math.random()<0.7 then return {"smashingpot"} else return nil end end,
          item2 = {"pig_ruins_artichoke"}
              },
  }),
  ["mandraketown"] = StaticLayout.Get("map/static_layouts/mandraketown"),
  ["nettlegrove"] = StaticLayout.Get("map/static_layouts/nettlegrove"),
  ["fountain_of_youth"] = StaticLayout.Get("map/static_layouts/pugalisk_fountain"),

  ["interior_spawnpoint"] = StaticLayout.Get("map/static_layouts/interior_spawn_point"),
  ["interior_spawnpoint_storage"] = StaticLayout.Get("map/static_layouts/interior_spawn_point_storage"),

  ["pig_ruins_nocanopy"] = StaticLayout.Get("map/static_layouts/pig_ruins_nocanopy"),
  ["pig_ruins_nocanopy_2"] = StaticLayout.Get("map/static_layouts/pig_ruins_nocanopy_2"),
  ["pig_ruins_nocanopy_3"] = StaticLayout.Get("map/static_layouts/pig_ruins_nocanopy_3"),
  ["pig_ruins_nocanopy_4"] = StaticLayout.Get("map/static_layouts/pig_ruins_nocanopy_4"),

  ["roc_nest"] = StaticLayout.Get("map/static_layouts/roc_nest"),
  ["roc_cave"] = StaticLayout.Get("map/static_layouts/roc_cave"),
}

return {Layouts = ExampleLayout}
