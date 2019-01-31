local assets=
{
}

local prefabs =
{
}    


local function fn(Sim)
	local inst = CreateEntity()
	inst.entity:AddTransform()
	inst:AddTag("NOBLOCK")
    inst:AddTag("interior_spawn_origin")

    return inst
end
local function storagefn(Sim)
	local inst = CreateEntity()
	inst.entity:AddTransform()
	inst:AddTag("NOBLOCK")
    inst:AddTag("interior_spawn_storage")

    return inst
end

return Prefab( "forest/objects/interior_spawn_origin", fn, assets, prefabs),
	   Prefab( "forest/objects/interior_spawn_storage", storagefn, assets, prefabs)
