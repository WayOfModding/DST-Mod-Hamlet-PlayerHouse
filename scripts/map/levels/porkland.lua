

AddLevel(LEVELTYPE.PORKLAND, {
		id="PORKLAND_DEFAULT",
		name=STRINGS.UI.CUSTOMIZATIONSCREEN.PRESETLEVELS[1],
		desc=STRINGS.UI.CUSTOMIZATIONSCREEN.PRESETLEVELDESC[1],
    location="porkland",
    version=1,
		overrides={
				{"roads", 			"never"},
				{"start_setpeice", 	"PorklandStart"},
				{"start_node",		"BG_rainforest_base"},
				{"spring",			"noseason"},
				{"summer",			"noseason"},
				{"branching",		"least"},
				{"location",		"porkland"},
		},
		tasks = {
				"Pigtopia",
				"Pigtopia_capital",
				"Edge_of_civilization",
				"Edge_of_the_unknown",
				"Edge_of_the_unknown_2",
				"Lilypond_land",
				"Lilypond_land_2",
				"Deep_rainforest",
				"Deep_rainforest_2",
				"Deep_lost_ruins_gas",
				"Lost_Ruins_1",
				--"Lost_Ruins_4",
				"Deep_rainforest_3",
				"Deep_rainforest_mandrake",
				"Path_to_the_others",
				"Other_pigtopia_capital",
				"Other_pigtopia",
				"Other_edge_of_civilization",
				"this_is_how_you_get_ants",

				"Deep_lost_ruins4",
				"lost_rainforest",
				"interior_space",

				"Land_Divide_1",
				"Land_Divide_2",
				"Land_Divide_3",
				"Land_Divide_4",

				"painted_sands",
				"plains",
				"rainforests",
				"rainforest_ruins",
				"plains_ruins",
				"pincale",

				"Deep_wild_ruins4",
				"wild_rainforest",
				"wild_ancient_ruins",
		},

		background_node_range = {0, 1},
		-- numoptionaltasks = 4,
		-- optionaltasks = {
		-- 		"Befriend the pigs",
		-- 		"For a nice walk",
		-- 		"Kill the spiders",
		-- 		"Killer bees!",
		-- 		"Make a Beehat",
		-- 		"The hunters",
		-- 		"Magic meadow",
		-- 		"Frogs and bugs",
		-- },
		set_pieces = { --[[
		 	["city_1"] = { count=1, tasks={"Pigtopia_capital" } },
		 	["city_1_2"] = { count=1, tasks={"Pigtopia_capital" } },
			["city_1_3"] = { count=1, tasks={"Pigtopia_capital" } },
			["city_1_4"] = { count=1, tasks={"Pigtopia_capital" } },
		 	["city_1_5"] = { count=1, tasks={"Pigtopia_capital" } },
			["city_1_6"] = { count=1, tasks={"Pigtopia_capital" } },
			["city_1_7"] = { count=1, tasks={"Pigtopia_capital" } },

			["city_2"] = { count=1, tasks={"Pigtopia"} },
			["city_2_2"] = { count=1, tasks={"Pigtopia"} },
			["city_2_3"] = { count=1, tasks={"Pigtopia"} },
			["city_2_4"] = { count=1, tasks={"Pigtopia"} },
			["city_2_5"] = { count=1, tasks={"Pigtopia"} },
			]]
		},

		-- ordered_story_setpieces = {
		-- 	"TeleportatoRingLayout",
		-- 	"TeleportatoBoxLayout",
		-- 	"TeleportatoCrankLayout",
		-- 	"TeleportatoPotatoLayout",
		-- 	"AdventurePortalLayout",
		-- 	"TeleportatoBaseLayout",
		-- },
		required_prefabs = {
			"pugalisk_fountain",
			"interior_spawn_origin",
			"interior_spawn_storage",
			"roc_nest",
			"pig_ruins_entrance",
			"pig_ruins_entrance2",
			"pig_ruins_entrance3",
			"pig_ruins_entrance4",
			"pig_ruins_entrance5",
			"pig_ruins_exit",
			"pig_ruins_exit2",
			"pig_ruins_exit4"
		 	--"teleportato_ring",  "teleportato_box",  "teleportato_crank", "teleportato_potato", "teleportato_base", "chester_eyebone", "adventure_portal", "pigking"
		},
	})
