require("stategraphs/commonstates")

local actionhandlers =
{
}

local events =
{
}

local states_south =
{
    State
    {
        name = "idle_south",
        tags = {"idle", "canrotate"},

        onenter = function(inst, playanim)
            inst.components.door:updateDoorVis()
            inst.AnimState:PlayAnimation("south", true)
        end,
    },

    State
    {
        name = "open_south",
        tags = {"moving", "canrotate"},

        onenter = function(inst)
            inst.components.door:sethidden(false)
            inst.components.door:updateDoorVis()
            inst.AnimState:PlayAnimation("south_open", false)
        end,

        events =
        {
            EventHandler("animover", function(inst) inst.sg:GoToState("idle_south") end),
        }
    },

    State
    {
        name = "shut_south",
        tags = {"busy"},

        onenter = function(inst)
            inst.AnimState:PlayAnimation("south_shut", false)
        end,

        events =
        {
            EventHandler("animover",
                function(inst)
                    inst.components.door:sethidden(true)
                    inst.components.door:updateDoorVis()
                    inst.sg:GoToState("idle_south")
                end),
        }
    },
}

return StateGraph("anthilldoor_south", states_south, events, "idle_south", actionhandlers)
