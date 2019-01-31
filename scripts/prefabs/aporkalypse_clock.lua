local assets=
{
	Asset("ANIM", "anim/porkalypse_clock_01.zip"),
	Asset("ANIM", "anim/porkalypse_clock_02.zip"),
	Asset("ANIM", "anim/porkalypse_clock_03.zip"),
	Asset("ANIM", "anim/porkalypse_clock_marker.zip"),
	Asset("ANIM", "anim/porkalypse_totem.zip"),

	Asset("ANIM", "anim/pressure_plate.zip"),
	Asset("ANIM", "anim/pressure_plate_backwards_build.zip"),
	Asset("ANIM", "anim/pressure_plate_forwards_build.zip"),

	Asset("MINIMAP_IMAGE", "porkalypse_clock"), 
}

local clock_prefabs = 
{
	"aporkalypse_clock1",
	"aporkalypse_clock2",
	"aporkalypse_clock3",
}

local plate_prefabs = 
{
	["aporkalypse_rewind_plate"] = {x = 6, z = 6},
	["aporkalypse_fastforward_plate"] = {x = 6, z = -6},
}

local function increment_rotation( inst, amount )
	inst.Transform:SetRotation(inst.Transform:GetRotation() + amount)
end

local function common_clock_fn()
	local inst = CreateEntity()
	local trans = inst.entity:AddTransform()
	local anim = inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()

	anim:SetOrientation( ANIM_ORIENTATION.OnGround )
	anim:SetLayer( LAYER_BACKGROUND )

	return inst
end

local function make_clock_fn(bank, build, sort_order, mult, speed)
	local function fn()
		local inst = common_clock_fn()

		inst.AnimState:SetSortOrder( 3 )
		inst.AnimState:SetFinalOffset( sort_order )
	    inst.AnimState:SetBank(bank)
	    inst.AnimState:SetBuild(build)
	    inst.AnimState:PlayAnimation("off_idle")
	    
	    inst:AddComponent("inspectable")
	    inst.components.inspectable.nameoverride = "aporkalypse_clock"
	    inst.name = STRINGS.NAMES.APORKALYPSE_CLOCK

	    return inst
	end
	
	return fn
end

local function FixAngle( target_angle)
    while target_angle > 360 do
        target_angle = target_angle % 360
    end

    while target_angle < 0 do
        target_angle = target_angle + 360
    end
    
    return target_angle
end

local function FindChildren(inst)
	local children = {}
	local marker = GetClosestWithName(inst, "aporkalypse_marker", 20)
	if marker then
		marker.Transform:SetRotation(90)
		children[marker] = true
	end
	for _, clock in pairs(clock_prefabs) do
		local found = GetClosestWithName(inst, clock, 20)
		if found then
			table.insert(inst.clocks, found)
			found.Transform:SetRotation(90)
			children[found] = true
		end
	end

	for k,v in pairs(plate_prefabs) do
		local found = GetClosestWithName(inst, k, 20)
		if found then
			table.insert(inst.plates, found)
			found.aporkalypse_clock = inst

			local x,y,z = inst.Transform:GetWorldPosition()
			x = x + v.x
			z = z + v.z
			
			found.Transform:SetPosition(x,y,z)
			children[found] = true
		end
	end
	if #inst.plates > 0 and #inst.clocks > 0 and marker then
		return children
	else
		return false
	end
end

local function SpawnChildren(inst)
	local marker = inst:SpawnChild("aporkalypse_marker")
	marker.Transform:SetRotation(90)

	for i,v in ipairs(clock_prefabs) do
		local clock = inst:SpawnChild(v)
		table.insert(inst.clocks, clock)
		clock.Transform:SetRotation(90)
	end

	for k,v in pairs(plate_prefabs) do
		local plate = inst:SpawnChild(k)
		
		plate.Transform:SetPosition(v.x,0,v.z)

		plate.aporkalypse_clock = inst
		table.insert(inst.plates, plate)
	end
end

local function CleanupAllOrphans()
	local names = {}
	names["aporkalypse_marker"] = true
	for i,v in ipairs(clock_prefabs) do
		names[v] = true
	end
	for k,v in pairs(plate_prefabs) do
		names[k] = true
	end
	local toRemove = {}
	for i,v in pairs(Ents) do
		local prefab = v.prefab
		if names[prefab] then
			table.insert(toRemove,v)
		end
	end
	local interiorSpawner = GetInteriorSpawner()
	for i,v in pairs(toRemove) do
		v:Remove()
	end
end

local function make_master_fn()
	local inst = CreateEntity()
	inst.entity:AddTransform()
	inst.entity:AddSoundEmitter()

	local anim = inst.entity:AddAnimState()

	anim:SetBank("totem")
	anim:SetBuild("porkalypse_totem")
	anim:PlayAnimation("idle_loop", true)

	inst.plates = {}
	inst.clocks = {}
	
	inst:DoTaskInTime(0, function()
		CleanupAllOrphans()
		SpawnChildren(inst)
	end)

	inst.daily_movement = { 6/TUNING.TOTAL_DAY_TIME, 360/TUNING.TOTAL_DAY_TIME, 12/TUNING.TOTAL_DAY_TIME }
	inst.previous_total_time = 0

	inst.StartRewind = function()
		if inst.rewind then
			return
		end

		inst.rewind = true
		inst.start_angle = 90
	end

	inst.StopRewind = function ( )
		if not inst.rewind then
			return
		end

		inst.rewind = false

		local final_angle = inst.start_angle-inst.clocks[1].Transform:GetRotation()
		final_angle = FixAngle(final_angle)

		local aporkalypse = GetAporkalypse()
		if aporkalypse then
			if aporkalypse:IsActive() then
				aporkalypse:EndAporkalypse()
			end
			-- Divide the angle difference by the daily movement to reschedule the aporkalypse
			aporkalypse:ScheduleAporkalypse(GetClock():GetTotalTime() + final_angle/inst.daily_movement[1])
		end


	end

	inst:DoTaskInTime(0.02, function() 
		inst:ListenForEvent( "clocktick", function(world, data)
			local total_time = GetClock():GetTotalTime()
			local aporkalypse = GetAporkalypse()

			local delta = total_time - inst.previous_total_time

			if inst.rewind then

				for i,v in ipairs(inst.clocks) do
					increment_rotation(v, delta * inst.rewind_mult * inst.daily_movement[i] * 250)
				end
			elseif not aporkalypse or not aporkalypse:IsActive() then
				for i,v in ipairs(inst.clocks) do
					increment_rotation(v, delta * inst.daily_movement[i])
				end
			end
			
			inst.previous_total_time = total_time
		end, GetWorld())
	end)


	local function playclockanimation(anim)
		for i,v in ipairs(inst.clocks) do
	   		v.AnimState:PlayAnimation(anim .. "_shake", false)
	   		v.AnimState:PushAnimation(anim .. "_idle")
	   	end
	end

	inst:ListenForEvent("beginaporkalypse", function()
		playclockanimation("on")
		
		inst.AnimState:PushAnimation("idle_pst", false)
	   	inst.AnimState:PushAnimation("idle_on")
	end, GetWorld())

	inst:ListenForEvent("endaporkalypse", function ()
		playclockanimation("off")

		inst.AnimState:PushAnimation("idle_pre", false)
	   	inst.AnimState:PushAnimation("idle_loop")
	end, GetWorld())

	-- inst.OnSave = function(inst, data)
	-- 	if inst.plates then
	-- 		data.plates = {}
	-- 		for _, plate in ipairs(plates) do
	-- 			table.insert(data.plates, plate.GUID)
	-- 		end

	-- 	end
	-- end

	-- inst.OnLoadPostPass = function(inst, ents, data)
	-- 	if data.queen_guid and ents[data.queen_guid] then
	-- 	if data.plates then
	-- 		for _, plate in ipairs(data.plates) do
	-- 			inst.plates = {}

	-- 		end
	-- 	end
	-- end

	return inst
end


local function on_pressure_plate_near(inst)
    if not inst:HasTag("INTERIOR_LIMBO") and not inst.down then
        inst.SoundEmitter:PlaySound("dontstarve_DLC003/common/items/pressure_plate/hit")
        inst.AnimState:PlayAnimation("popdown")
        inst.AnimState:PushAnimation("down_idle")
        inst.down = true
        inst.trigger(inst)
    end
end

local function on_pressure_plate_far(inst)
    if not inst:HasTag("INTERIOR_LIMBO") and inst.down then
        inst.AnimState:PlayAnimation("popup")
        inst.AnimState:PushAnimation("up_idle")
        inst.down = nil
        inst.untrigger(inst)
    end
end

local function make_common_plate()
	local inst = CreateEntity()
	local trans = inst.entity:AddTransform()
	local anim = inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()

    anim:SetBank("pressure_plate")
    anim:SetBuild("pressure_plate")
    anim:PlayAnimation("up_idle")

    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)

    inst:AddTag("structure")
    
    inst.weights = 0

    inst:AddTag("weighdownable")

-------------------------------------------------------------------------------
    inst:AddComponent("creatureprox")
    inst.components.creatureprox:SetOnPlayerNear(on_pressure_plate_near)
    inst.components.creatureprox:SetOnPlayerFar(on_pressure_plate_far)

    inst.components.creatureprox:SetTestfn(function(testing) return not testing:HasTag("flying") end)
    
    inst.components.creatureprox:SetDist(0.8, 0.9)
    inst.components.creatureprox.inventorytrigger = true

-------------------------------------------------------------------------------

    return inst
end


local function make_rewind_plate()
	local inst = make_common_plate()
	inst.AnimState:SetBuild("pressure_plate_forwards_build")

	inst.trigger = function() 
		if inst.aporkalypse_clock then
			inst.aporkalypse_clock.rewind_mult = -1
			inst.aporkalypse_clock:StartRewind()
		end

		local pt = Vector3(inst.Transform:GetWorldPosition())
		local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 50, nil, {"INTERIOR_LIMBO"})
        for i, ent in ipairs(ents) do
            if ent:HasTag("lockable_door") then
                ent:PushEvent("close")
            end
        end
	end
	inst.untrigger = function() 
		if inst.aporkalypse_clock then
			inst.aporkalypse_clock:StopRewind()
		end

		local pt = Vector3(inst.Transform:GetWorldPosition())
		local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 50, nil, {"INTERIOR_LIMBO"})
        for i, ent in ipairs(ents) do
            if ent:HasTag("lockable_door") then
                ent:PushEvent("open")
            end
        end
	end

	return inst
end

local function make_fastforward_plate()
	local inst = make_common_plate()
	inst.AnimState:SetBuild("pressure_plate_backwards_build")

	inst.trigger = function() 
		if inst.aporkalypse_clock then
			inst.aporkalypse_clock.rewind_mult = 1
			inst.aporkalypse_clock:StartRewind()
		end

		local pt = Vector3(inst.Transform:GetWorldPosition())
		local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 50, nil, {"INTERIOR_LIMBO"})
        for i, ent in ipairs(ents) do
            if ent:HasTag("lockable_door") then
                ent:PushEvent("close")
            end
        end
	end

	inst.untrigger = function() 
		if inst.aporkalypse_clock then
			inst.aporkalypse_clock:StopRewind()
		end

		local pt = Vector3(inst.Transform:GetWorldPosition())
		local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 50, nil, {"INTERIOR_LIMBO"})
        for i, ent in ipairs(ents) do
            if ent:HasTag("lockable_door") then
                ent:PushEvent("open")
            end
        end
	end

	return inst
end

local function make_marker()
	local inst = CreateEntity()
	local trans = inst.entity:AddTransform()
	local anim = inst.entity:AddAnimState()

    local minimap = inst.entity:AddMiniMapEntity()        
    minimap:SetIcon("porkalypse_clock.png")

	anim:SetBuild("porkalypse_clock_marker")
	anim:SetBank("clock_marker")
	anim:PlayAnimation("idle")

	anim:SetOrientation( ANIM_ORIENTATION.OnGround )
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
    inst.AnimState:SetFinalOffset(0)
	return inst
end

local function MakeClock(clock_num, mult, speed)
	local name = "aporkalypse_clock" .. clock_num
	local bank = "clock_0".. clock_num
	local build = "porkalypse_clock_0" .. clock_num
	local sort_order = clock_num

	return Prefab( "common/objects/" .. name, make_clock_fn( bank, build, sort_order, mult, speed), assets)
end

return MakeClock( 1, 1, 1),
	   MakeClock( 2, -1, 3),
	   MakeClock( 3, 1, 0.5),
	   Prefab( "common/objects/aporkalypse_rewind_plate", make_rewind_plate, assets),
	   Prefab( "common/objects/aporkalypse_fastforward_plate", make_fastforward_plate, assets),
	   Prefab( "common/objects/aporkalypse_clock", make_master_fn, assets),
	   Prefab( "common/objects/aporkalypse_marker", make_marker, assets)