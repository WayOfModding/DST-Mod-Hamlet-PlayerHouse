--The name of the mod displayed in the 'mods' screen.
name = "[Hamlet] Porkland"

--A version number so you can ask people if they are running an old version of your mod.
version = "1.0.0"

--Who wrote this awesome mod?
author = "KaiserKatze"

--A description of the mod.
description = "Version "..version.." By "..author..[[

Port Hamlet DLC of Don't Starve.
]]

--This lets other players know if your mod is out of date. This typically needs to be updated every time there's a new game update.
api_version = 10

dst_compatible = true

--This lets clients know if they need to get the mod from the Steam Workshop to join the game
all_clients_require_mod = true

--This determines whether it causes a server to be marked as modded (and shows in the mod list)
client_only_mod = false

--This lets people search for servers with this mod by these tags
server_filter_tags = {"hamlet"}

icon_atlas = "modicon.xml"
icon = "modicon.tex"

forumthread = ""

configuration_options =
{
  {
    name = "IDEOLOGY",
    label = "Can I get into other people's house?",
    options = {
      {
        description = "Communism",
        data = 0,
        hover = "Yes, you can!"
      }, {
        description = "Nazism",
        data = 1,
        hover = "If only you are the dictactor host!"
      }, {
        description = "Capitalism",
        data = 2,
        hover = "No, you can't!"
      }
    },
    default = 0,
  },
}
