local InteriorCamera = require "cameras/interiorcamera"

local wallWidth = 7
local wallLength = 24

local BigPopupDialogScreen = require "screens/bigpopupdialog"
local PopupDialogScreen = require "screens/popupdialog"

local function GetVerb(inst, doer)
  return STRINGS.ACTIONS.JUMPIN.ENTER
end

local ANTHILL_DUNGEON_NAME = "ANTHILL1"

local InteriorSpawner = Class(function(self, inst)
  self.inst = inst

  self.interiors = {}

  self.doors = {}

  self.next_interior_ID = 0

  self.getverb = GetVerb

  self.interior_spawn_origin = nil

  self.current_interior = nil

  -- true if we're considered inside an interior, which is also during transition in/out of
  self.considered_inside_interior = {}

  self.from_inst = nil
  self.to_inst = nil
  self.to_target = nil

  self.prev_player_pos_x = 0.0
  self.prev_player_pos_y = 0.0
  self.prev_player_pos_z = 0.0

  self.exteriorCamera = TheCamera
  self.interiorCamera = InteriorCamera()

  self.homeprototyper = SpawnPrefab("home_prototyper")
  -- for debugging the black room issue
  self.alreadyFlagged = {}
  self.was_invincible = false

  -- This has to happen after the fade for....reasons
  self.inst:DoTaskInTime(2, function() self:getSpawnOrigin() end)

  self.inst:DoTaskInTime(1, function() self:FixDoors() end)
  self.inst:DoTaskInTime(0.1, function() self:CleanupBlackRoomAfterHiddenDoor() end)

  -- Tear down the wall!
  self.inst:DoTaskInTime(0.1, function() self:WallCleanUp() end)

  -- Fixup because the items weren't put back in locked cabinets
  self.inst:DoTaskInTime(2, function() self:FixShelfItems() end)
end)

function InteriorSpawner:FixShelfItems()
  for i,v in pairs(Ents) do
    if v.components.inventoryitem and v.onshelf then
      local shelf = v.onshelf
      local pocket = shelf.components.pocket
      local pocketitem = pocket:GetItem("shelfitem")
      -- if there's something in the pocket we have a different issue, don't touch it
      if shelf and not pocketitem then
        -- check if the shelf_slot contains us?
        local shelfer = shelf.components.shelfer
        if shelfer then
          local gift = shelfer:GetGift()
          if gift ~= v then
            -- in case it's locked (and it probably is, because that's why this whole function is here)
            local enabled = shelfer.enabled
            shelfer.enabled = true
            shelfer:UpdateGift(nil, v)
            -- and lock it again if needed
            if enabled then
              shelfer:Enable()
            else
              shelfer:Disable()
            end
          end
        end
      end
    end
  end
end

function InteriorSpawner:WallCleanUp()
  -- Delete all existing instances of generic_wall_back. There's a ton of em that aren't needed and are wrong to boot
  local entsToRemove = {}
  for i,v in pairs(Ents) do
    if v.prefab == "generic_wall_back" then
      entsToRemove[v] = true
      v:Remove()
    end
  end
  -- see if any interior was referencing any of these walls, if so, remove them
  for _,interior in pairs(self.interiors) do
    if interior.object_list and #interior.object_list > 0 then
      local new_list = {}
      for n,obj in pairs(interior.object_list) do
        if not entsToRemove[obj] then
          table.insert(new_list, obj)
        end
      end
      interior.object_list = new_list
    end
  end

  -- and create 4 new ones that will be reconfigured for each room
  self.walls = {}
  local origWidth = 1
  local delta = (2 * wallWidth - 2 * origWidth) / 2

  local wall

  local spawnStorage = self:getSpawnStorage()

  wall = SpawnPrefab("generic_wall_back")
  --wall.Transform:SetPosition(x - (interior_definition.depth/2) +1 - delta,y,z)
  wall.Transform:SetPosition(spawnStorage.x, spawnStorage.y, spawnStorage.z)
  wall.setUp(wall,wallLength, nil, nil, wallWidth)
  self.walls[1] = wall

  -- front wall
  wall = SpawnPrefab("generic_wall_back")
  --wall.Transform:SetPosition(x + (interior_definition.depth/2) + 3 + delta,y,z)
  wall.Transform:SetPosition(spawnStorage.x, spawnStorage.y, spawnStorage.z)
  wall.setUp(wall,wallLength, nil, nil, wallWidth)
  self.walls[2] = wall
  --Spawn Side Walls [TODO] Base Values On Interior Width And Height

  -- right wall
  wall = SpawnPrefab("generic_wall_back")
  --wall.Transform:SetPosition(x,y,z + (interior_definition.width/2) +1+delta)
  wall.Transform:SetPosition(spawnStorage.x, spawnStorage.y, spawnStorage.z)
  wall.setUp(wall,wallWidth,nil,nil,wallLength)
  self.walls[3] = wall

  -- left wall
  wall = SpawnPrefab("generic_wall_back")
  --wall.Transform:SetPosition(x,y,z - (interior_definition.width/2) -1-delta)
  wall.Transform:SetPosition(spawnStorage.x, spawnStorage.y, spawnStorage.z)
  wall.setUp(wall,wallWidth,nil,nil,wallLength)
  self.walls[4] = wall


  if self.current_interior then
    self:ConfigureWalls(self.current_interior)
  end
end

function InteriorSpawner:ConfigureWalls(interior)
  local spawnOrigin = self:getSpawnOrigin()
  local x,y,z = spawnOrigin.x, spawnOrigin.y, spawnOrigin.z

  local origwidth = 1
  local delta = (2 * wallWidth - 2 * origwidth) / 2

  local depth = interior.depth
  local width = interior.width

  -- back, front wall
  self:Teleport(self.walls[1], Vector3(x - (depth/2) - 1 - delta,y,z))
  self:Teleport(self.walls[2], Vector3(x + (depth/2) + 1 + delta,y,z))

  -- left, right wall
  self:Teleport(self.walls[3], Vector3(x,y,z + (width/2) + 1 + delta))
  self:Teleport(self.walls[4], Vector3(x,y,z - (width/2) - 1 -delta))

  for i=1,4 do
    self.walls[i]:ReturnToScene()
    self.walls[i]:RemoveTag("INTERIOR_LIMBO")
  end

end

local dodebug = false

local function doprint(text)
  if dodebug then
    print(text)
  end
end

local EAST  = { x =  1, y =  0 }
local WEST  = { x = -1, y =  0 }
local NORTH = { x =  0, y =  1 }
local SOUTH = { x =  0, y = -1 }

local dir =
{
    EAST,
    WEST,
    NORTH,
    SOUTH,
}

local dir_opposite =
{
    WEST,
    EAST,
    SOUTH,
    NORTH,
}

local NO_INTERIOR = -1

function createInteriorHandle(interior)

  local wallsTexture = "levels/textures/interiors/harlequin_panel.tex"
  local floorTexture = "levels/textures/interiors/noise_woodfloor.tex"

  if interior.walltexture ~= nil then
    wallsTexture = interior.walltexture
  end

  if interior.floortexture ~= nil then
    floorTexture = interior.floortexture
  end

  local height = 5
  if interior.height then
    height = interior.height
  end

  local handle = InteriorManager:CreateInterior(interior.width, height, interior.depth, wallsTexture, floorTexture)

  GetWorld().Map:AddInterior( handle )

  return handle
end

function InteriorSpawner:UpdateInteriorHandle(interior)
  GetWorld().Map:SetInteriorFloorTexture( interior.handle, interior.floortexture )
  GetWorld().Map:SetInteriorWallsTexture( interior.handle, interior.walltexture )
end

function InteriorSpawner:getSpawnOrigin()
  local pt = nil
  if not self.interior_spawn_origin then
    local spawnOriginCount = 0
    for k, v in pairs(Ents) do
      if v:HasTag("interior_spawn_origin") then
        -- Go with the first one, that's what we did before
        pt = v:GetPosition()
        print("Spawn Origin",k,"at",v)
        if spawnOriginCount == 0 then
          self.interior_spawn_origin = v
          InteriorManager:SetCurrentCenterPos2d( pt.x, pt.z )
          -- interior_spawn_storage
        end
        spawnOriginCount = spawnOriginCount + 1
      end
    end
    assert(spawnOriginCount > 0)
    if spawnOriginCount > 1 then
      -- drat. This one caught me off guard
      GetWorld():DoTaskInTime(0, function() self:BlackRoomBugCheckPopup() end)
    end
  else
    pt = self.interior_spawn_origin:GetPosition()
  end
  return pt
end

function InteriorSpawner:getSpawnStorage()
  local pt = nil
  if not self.interior_spawn_storage then
    for k, v in pairs(Ents) do
      if v:HasTag("interior_spawn_storage") then
        self.interior_spawn_storage = v
        pt = self.interior_spawn_storage:GetPosition()
        InteriorManager:SetDormantCenterPos2d( pt.x, pt.z )
        break
      end
    end
  else
    pt = self.interior_spawn_storage:GetPosition()
  end
  return pt
end

function InteriorSpawner:PushDirectionEvent(target, direction)
  target:UpdateIsInInterior()
end

function InteriorSpawner:CheckIsFollower(inst)
  local isfollower = false
  -- CURRENT ASSUMPTION IS THAT ONLY THE PLAYER USES DOORS!!!!
  local player = GetPlayer()

  local eyebone = nil

  for follower, v in pairs(player.components.leader.followers) do
    if follower == inst then
      isfollower = true
    end
  end

  if player.components.inventory then
    for k, item in pairs(player.components.inventory.itemslots) do

      if item.components.leader then
        if item:HasTag("chester_eyebone") then
          eyebone = item
        end
        for follower, v in pairs(item.components.leader.followers) do
          if follower == inst then
            isfollower = true
          end
        end
      end
    end
    -- special special case, look inside equipped containers
    for k, equipped in pairs(player.components.inventory.equipslots) do
      if equipped and equipped.components.container then

        local container = equipped.components.container
        for j, item in pairs(container.slots) do

          if item.components.leader then
            if item:HasTag("chester_eyebone") then
              eyebone = item
            end
            for follower, v in pairs(item.components.leader.followers) do
              if follower == inst then
                isfollower = true
              end
            end
          end
        end
      end
    end
    -- special special special case: if we have an eyebone, then we have a container follower not actually in the inventory. Look for inventory items with followers there.
    if eyebone and eyebone.components.leader then
      for follower, v in pairs(eyebone.components.leader.followers) do

        if follower and (not follower.components.health or (follower.components.health and not follower.components.health:IsDead())) and follower.components.container then
          for j,item in pairs(follower.components.container.slots) do

            if item.components.leader then
              for follower, v in pairs(item.components.leader.followers) do
                if follower and (not follower.components.health or (follower.components.health and not follower.components.health:IsDead())) then
                  if follower == inst then
                    isfollower = true
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  if inst and not isfollower and inst.parent and inst.parent == GetPlayer() then
    print("FOUND A CHILD",inst.prefab)
    isfollower = true
  end

  return isfollower
end

function InteriorSpawner:ExecuteTeleport(doer, destination, direction)
  self:Teleport(doer, destination)

  if direction then
    self:PushDirectionEvent(doer, direction)
  end

  if doer.components.leader then
    for follower, v in pairs(doer.components.leader.followers) do
      self:Teleport(follower, destination)
      if direction then
        self:PushDirectionEvent(follower, direction)
      end
    end
  end

  local eyebone = nil

  --special case for the chester_eyebone: look for inventory items with followers
  if doer.components.inventory then
    for k, item in pairs(doer.components.inventory.itemslots) do

      if direction then
        self:PushDirectionEvent(item, direction)
      end

      if item.components.leader then
        if item:HasTag("chester_eyebone") then
          eyebone = item
        end
        for follower,v in pairs(item.components.leader.followers) do
          self:Teleport(follower, destination)
        end
      end
    end
    -- special special case, look inside equipped containers
    for k, equipped in pairs(doer.components.inventory.equipslots) do
      if equipped and equipped.components.container then

        if direction then
          self:PushDirectionEvent(equipped, direction)
        end

        local container = equipped.components.container
        for j, item in pairs(container.slots) do

          if direction then
            self:PushDirectionEvent(item, direction)
          end

          if item.components.leader then
            if item:HasTag("chester_eyebone") then
              eyebone = item
            end
            for follower,v in pairs(item.components.leader.followers) do
              self:Teleport(follower, destination)
            end
          end
        end
      end
    end
    -- special special special case: if we have an eyebone, then we have a container follower not actually in the inventory. Look for inventory items with followers there.
    if eyebone and eyebone.components.leader then
      for follower, v in pairs(eyebone.components.leader.followers) do

        if direction then
          self:PushDirectionEvent(follower, direction)
        end

        if follower and (not follower.components.health or (follower.components.health and not follower.components.health:IsDead())) and follower.components.container then
          for j, item in pairs(follower.components.container.slots) do

            if direction then
              self:PushDirectionEvent(item, direction)
            end

            if item.components.leader then
              for follower, v in pairs(item.components.leader.followers) do
                if follower and (not follower.components.health or (follower.components.health and not follower.components.health:IsDead())) then
                  self:Teleport(follower, destination)
                end
              end
            end
          end
        end
      end
    end
  end


  if doer == GetPlayer() and GetPlayer().components.kramped then

    local kramped = GetPlayer().components.kramped
    kramped:TrackKrampusThroughInteriors(destination)
end
end

function InteriorSpawner:Teleport(obj, destination)
  -- at this point destination can be a prefab or just a pt.
  local pt = nil
  if destination.prefab then
    pt = destination:GetPosition()
  else
    pt = destination
  end

  if not obj:IsValid() then return end


  if obj.Physics then
    if obj.Transform then
      local displace = Vector3(0,0,0)
      if destination.prefab and destination.components.door and destination.components.door.outside then
        local down = TheCamera:GetDownVec()
        local angle = math.atan2(down.z, down.x)
        obj.Transform:SetRotation(angle)

      elseif destination.prefab and destination.components.door and destination.components.door.angle then
        obj.Transform:SetRotation(destination.components.door.angle)
        print("destination.components.door.angle",destination.components.door.angle)
        --displace.x = math.cos(
        local angle = (destination.components.door.angle * 2 * PI) / 360
        local magnitude = 1
        local dx = math.cos(angle) * magnitude
        local dy = math.sin(angle) * magnitude
        print("dx,dy",dx,dy)
        displace.x = dx
        displace.z = -dy
      else
        obj.Transform:SetRotation(180)
      end
      obj.Physics:Teleport(pt.x + displace.x, pt.y + displace.y, pt.z + displace.z)
    end
  elseif obj.Transform then
    obj.Transform:SetPosition(pt.x, pt.y, pt.z)
  end
end


local function FadeInFinished(was_invincible)
  -- Last step in transition
  local player = GetPlayer()
  player.components.health:SetInvincible(was_invincible)

  player.components.playercontroller:Enable(true)
  GetWorld():PushEvent("enterroom")
end

function InteriorSpawner:SetCameraOffset(cameraoffset, zoom)
  local pt = self:getSpawnOrigin()

  -- cameraoffset = -2
  -- zoom = 35

  TheCamera.interior_currentpos_original = Vector3(pt.x+cameraoffset, 0, pt.z)
  TheCamera.interior_currentpos = Vector3(pt.x+cameraoffset, 0, pt.z)

  TheCamera.interior_distance = zoom
end

local function GetTileType(pt)
  local ground = GetWorld()
  local tile
  if ground and ground.Map then
    tile = ground.Map:GetTileAtPoint(pt:Get())
  end
  local groundstring = "unknown"
  for i,v in pairs(GROUND) do
    if tile == v then
      groundstring = i
    end
  end
  return groundstring
end

function InteriorSpawner:GetDoor(door_id)
  return self.doors[door_id]
end

function InteriorSpawner:BlackRoomPopup(playerpos, interior, door_ent)
  if self.current_interior == interior then
    GetPlayer().Physics:Teleport(playerpos.x, playerpos.y, playerpos.z)
    SetPause(true,"blackroompopup")
    TheFrontEnd:PushScreen(
            BigPopupDialogScreen( STRINGS.UI.BLACKROOM_BUG.BLACKROOM_TITLE,
                  STRINGS.UI.BLACKROOM_BUG.BLACKROOM_BODY,
          {
            {
              text = STRINGS.UI.BLACKROOM_BUG.OPEN_FORUMS,
              cb = function()
              VisitURL("https://forums.kleientertainment.com/forums/topic/97024-if-you-have-the-completely-black-room-bug-we-could-really-use-your-help")
              TheFrontEnd:PopScreen()
              TheFrontEnd:PushScreen(
                                                              PopupDialogScreen( STRINGS.UI.BLACKROOM_BUG.THANKS, "", {{text=STRINGS.UI.BLACKROOM_BUG.OK, cb = function()
                                  TheFrontEnd:PopScreen()
                                  door_ent.components.door:Activate(GetPlayer())
                                  SetPause(false)
                                    end}})
                  )

            end
          },
          {
            text = STRINGS.UI.BLACKROOM_BUG.CANCEL,
            cb = function()
              SetPause(false)
              TheFrontEnd:PopScreen()
              door_ent.components.door:Activate(GetPlayer())
            end
          }
          }
      )
    )

  end
end

function InteriorSpawner:BlackRoomBugCheckPopup()
  if not self.BlackRoomBugCheckPopupShown then
    self.BlackRoomBugCheckPopupShown = true
    SetPause(true,"blackroomcheckpopup")
    TheFrontEnd:PushScreen(
        BigPopupDialogScreen( STRINGS.UI.BLACKROOM_BUG.BLACKROOM_TITLE,
                      STRINGS.UI.BLACKROOM_BUG.BLACKROOM_CHECK_TITLE,
            {
              {
                text = STRINGS.UI.BLACKROOM_BUG.HESITANT_OK,
                cb = function()
                TheFrontEnd:PopScreen()
                SetPause(false)
              end
            },
            }
          )
        )
  end
end

function InteriorSpawner:FadeOutFinished()
  -- THIS ASSUMES IT IS THE PLAYER WHO MOVED
  local player = GetPlayer()

  local x, y, z = player.Transform:GetWorldPosition()
  self.prev_player_pos_x = x
  self.prev_player_pos_y = y
  self.prev_player_pos_z = z

  -- Now that we are faded to black, perform transition
  TheFrontEnd:SetFadeLevel(1)
  --current_inst.SoundEmitter:PlaySound("dontstarve/common/pighouse_door")

  local wasinterior = TheCamera.interior

  --if the door has an interior name, then we are going to a room, otherwise we are going out
  if self.to_interior then
    TheCamera = self.interiorCamera
  --  TheCamera:SetTarget( self.interior_spawn_origin )
  else
    TheCamera = self.exteriorCamera
  end

  local direction = nil
  if wasinterior and not TheCamera.interior then
    direction = "out"
    -- if going outside, blank the interior color cube setting.
    GetWorld().components.colourcubemanager:SetInteriorColourCube(nil)
  end
  if not wasinterior and TheCamera.interior then
    -- If the user is the player, then the perspective of things will move inside
    direction = "in"
  end

  self:UnloadInterior()

  GetWorld().components.ambientsoundmixer:SetReverbPreset("default")

  local destination = self:GetInteriorByName(self.to_interior)

  if destination then

    if destination.reverb then
      GetWorld().components.ambientsoundmixer:SetReverbPreset(destination.reverb)
    end

    -- set the interior color cube
    GetWorld().components.colourcubemanager:SetInteriorColourCube( destination.cc )

    self:LoadInterior(destination)

    -- Configure The Camera
    local pt = self:getSpawnOrigin()

    local cameraoffset = -2.5     --10x15
    local zoom = 23

    if destination.cameraoffset and destination.zoom then
      cameraoffset = destination.cameraoffset
      zoom = destination.zoom
    elseif destination.depth == 12 then    --12x18
      cameraoffset = -2
      zoom = 25
    elseif destination.depth == 16 then --16x24
      cameraoffset = -1.5
      zoom = 30
    elseif destination.depth == 18 then --18x26
      cameraoffset = -2 -- -1
      zoom = 35
    end

    TheCamera.interior_currentpos_original = Vector3(pt.x+cameraoffset, 0, pt.z)
    TheCamera.interior_currentpos = Vector3(pt.x+cameraoffset, 0, pt.z)

    TheCamera.interior_distance = zoom
  else
    GetWorld().Map:SetInterior( NO_INTERIOR )
  end



  local to_target_position
  if not self.to_target and self.from_inst.components.door then
    -- by now the door we want to spawn at should be created and/or placed.
    self.to_target = self.doors[self.from_inst.components.door.target_door_id].inst
    if direction == "out" then
      -- make sure this is a walkable spot
      local pt = self.to_target:GetPosition()
      local cameraAngle = TheCamera:GetHeadingTarget()
      local angle = cameraAngle * 2 * PI / 360
      local offset = FindWalkableOffset(pt,-angle,1.5)
      if offset then
        self.to_target = pt + offset
      end
    end
  end


  self:ExecuteTeleport(player, self.to_target, direction)
  -- Log some info for debugging purposes
  if destination then
    local pt1 = self:getSpawnOrigin()
    local pt2 = self:getSpawnStorage()
    print("SpawnOrigin:",pt1,GetTileType(pt1))
    print("SpawnStorage:",pt2,GetTileType(pt2))
    print("SpawnDelta:",pt2-pt1)
    local ppt = GetPlayer():GetPosition()
    print("Player at ",ppt, GetTileType(ppt))
  end
  -- and do a sanity check
  if destination then
    local pt = self:getSpawnOrigin()
    -- collect all the things in the "interior area" minus the interior_spawn_origin and the player
    local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 50, nil, {"INTERIOR_LIMBO"})
    local hasWall = false
    for i,v in pairs(ents) do
      if v.prefab == "generic_wall_back" then
        hasWall = true
        break
      end
    end
    if not hasWall then
      if not self.alreadyFlagged[self.current_interior.unique_name] then
        print("*** Warning *** InteriorSpawner:LoadInterior - no wall for interior "..self.current_interior.unique_name.." ("..self.current_interior.dungeon_name..")")
      end
    end
    if #ents <= 16 then
      -- oh oh, a black room
      local interior = self.current_interior
      local playerpos = GetPlayer():GetPosition()
      local to_target = self.to_target
      GetWorld():DoTaskInTime(2, function() self:BlackRoomPopup(playerpos, interior, to_target) end)
    end
  end
  -- Log some info for debugging purposes
  if destination then
    local pt1 = self:getSpawnOrigin()
    local pt2 = self:getSpawnStorage()
    print("SpawnOrigin:",pt1,GetTileType(pt1))
    print("SpawnStorage:",pt2,GetTileType(pt2))
    print("SpawnDelta:",pt2-pt1)
    local ppt = GetPlayer():GetPosition()
    print("Player at ",ppt, GetTileType(ppt))
  end
  -- and do a sanity check
  if destination then
    local pt = self:getSpawnOrigin()
    -- collect all the things in the "interior area" minus the interior_spawn_origin and the player
    local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 50, nil, {"INTERIOR_LIMBO"})
    local hasWall = false
    for i,v in pairs(ents) do
      if v.prefab == "generic_wall_back" then
        hasWall = true
        break
      end
    end
    if not hasWall then
      if not self.alreadyFlagged[self.current_interior.unique_name] then
        print("*** Warning *** InteriorSpawner:LoadInterior - no wall for interior "..self.current_interior.unique_name.." ("..self.current_interior.dungeon_name..")")
      end
    end
    if #ents <= 16 then
      -- oh oh, a black room
      local interior = self.current_interior
      local playerpos = GetPlayer():GetPosition()
      local to_inst = self.to_inst
      GetWorld():DoTaskInTime(2, function() self:BlackRoomPopup(playerpos, interior, to_inst) end)
    end
  end


  GetPlayer().components.locomotor:UpdateUnderLeafCanopy()

  if direction =="out" then
    -- turn off amb snd

    GetWorld():PushEvent("exitinterior", {to_target = self.to_target})
  else
    --change amb sound ot this room.

    GetWorld():PushEvent("enterinterior", {to_target = self.to_target})
  end

  --GetWorld():PushEvent("onchangecanopyzone", {instant=true})
  --local ColourCubeManager = GetWorld().components.colourcubemanager
  --ColourCubeManager:StartBlend(0)

  if player:HasTag("wanted_by_guards") then
    player:RemoveTag("wanted_by_guards")
    local x, y, z = player.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 35, {"guard"})
    if #ents> 0 then
      for i, guard in ipairs(ents)do
        guard:PushEvent("attacked", {attacker = player, damage = 0, weapon = nil})
      end
    end
  end
  if self.from_inst and self.from_inst.components.door then
    GetWorld():PushEvent("doorused", {door = self.to_target, from_door = self.from_inst})
  end

  if self.from_inst and self.from_inst:HasTag("ruins_entrance") and not self.to_interior then
    GetPlayer():PushEvent("exitedruins")
  end

  if self.to_target.prefab then

    if self.to_target:HasTag("ruins_entrance") then
      GetPlayer():PushEvent("enteredruins")
      -- unlock all doors
      self:UnlockAllDoors(self.to_target)
    end

    if self.to_target:HasTag("shop_entrance") then
      GetPlayer():PushEvent("enteredshop")
    end

    if self.to_target:HasTag("anthill_inside") then
      GetPlayer():PushEvent("entered_anthill")
    end

    if self.to_target:HasTag("anthill_outside") then
      GetPlayer():PushEvent("exited_anthill")
    end
  end

  TheCamera:SetTarget(GetPlayer())
  TheCamera:Snap()

  self.from_inst = nil

  self.to_target = nil
  if self.HUDon == true then
    GetPlayer().HUD:Show()
    self.HUDon = nil
  end

  TheFrontEnd:Fade(true, 1, function() FadeInFinished(self.was_invincible) end)
  GetWorld().doorfreeze = nil
end

function InteriorSpawner:GatherAllRooms(from_room, allrooms)
  if allrooms[from_room] then
    -- already did this room
    return
  end
  allrooms[from_room] = true
  local interior = self:GetInteriorByName(from_room)
  if interior then
    --print("interior = ",interior)
    --print("prefabs:",interior.prefabs)
    if interior.prefabs then
      -- room was never spawned
      --assert(false)
      for k, prefab in ipairs(interior.prefabs) do
        if prefab.name == "prop_door" then
          if  prefab.door_closed then
            prefab.door_closed["door"] = nil
          end
          local target_interior = prefab.target_interior
          print("target_interior:",target_interior)
          if target_interior then
            self:GatherAllRooms(target_interior, allrooms)
          end
        end
      end
    else
      -- go through the object list and see what entities are doors
      if interior.object_list and #interior.object_list > 0 then
        --print("Room has been spawned but was unspawned")
        -- room was spawned but is unspawned
        for i,v in pairs(interior.object_list) do
          --print(i,v)
          if v.prefab == "prop_door" then
            if v.components.door then
              --v.components.door:checkDisableDoor(nil, "door")
              v:PushEvent("open", {instant=true})
              local target_interior = v.components.door.target_interior
              --print("target_interior:",target_interior)
              if target_interior then
                self:GatherAllRooms(target_interior, allrooms)
              end
            end
          end
        end
      else
        -- we're in the room
        print("Inside the room")
        local ents = self:GetCurrentInteriorEntities()
        for i,v in pairs(ents) do
          if v.prefab == "prop_door" then
            --print(v)
            if v.components.door then
              --v.components.door:checkDisableDoor(nil, "door")
              v:PushEvent("open", {instant=true})
              local target_interior = v.components.door.target_interior
              --print("target_interior:",target_interior)
              if target_interior then
                self:GatherAllRooms(target_interior, allrooms)
              end
            end
          end
        end
      end
    end
  else
    assert(false)
  end

end

function InteriorSpawner:UnlockAllDoors(from_door)
  -- gather all rooms that can be reached from this room
  local allrooms = {}
  local target_interior
  if from_door then
    target_interior = from_door.components.door and from_door.components.door.interior_name
  else
    target_interior = self.current_interior and self.current_interior.unique_name
  end
  if target_interior then
    print("Unlocking all doors coming from", target_interior)
    self:GatherAllRooms(target_interior, allrooms)
    else
    print("Nothing to unlock")
  end
  --for i,v in pairs(allrooms) do
  --  print(i,v)
  --end
end

function InteriorSpawner:PlayTransition(doer, inst, interiorID, to_target)
  -- the usual use of this function is with doer and inst.. where inst has the door component.

  -- but you can provide an interiorID and a to_target instead and bypass the door stuff.

  -- to_target can be a pt or an inst

  self.from_inst = inst

  self.to_interior = nil

  if interiorID then
    self.to_interior = interiorID
  else
    if inst then
      self.to_interior = inst.components.door.target_interior
    end
  end


  if to_target then
    self.to_target = to_target
  end

  if doer:HasTag("player") then
    if self.to_interior then
      self:ConsiderPlayerInside(self.to_interior)
    end

    GetWorld().doorfreeze = true
    self.was_invincible = doer.components.health:IsInvincible()
    doer.components.health:SetInvincible(true)


    doer.components.playercontroller:Enable(false)

    if GetPlayer().HUD.shown then
      self.HUDon = true
      GetPlayer().HUD:Hide()
    end

    TheFrontEnd:Fade(false, 0.5, function() self:FadeOutFinished() end)
  else
    print("!!ERROR: Tried To Execute Transition With Non Player Character")
  end
end



function InteriorSpawner:GetNewID()
  self.next_interior_ID = self.next_interior_ID + 1
  return self.next_interior_ID
end

function InteriorSpawner:GetDir()
  return dir
end

function InteriorSpawner:GetNorth()
  return NORTH
end
function InteriorSpawner:GetSouth()
  return SOUTH
end
function InteriorSpawner:GetWest()
  return WEST
end
function InteriorSpawner:GetEast()
  return EAST
end

function InteriorSpawner:GetDirOpposite()
  return dir_opposite
end

function InteriorSpawner:GetOppositeFromDirection(direction)
  if direction == NORTH then
    return self:GetSouth()
  elseif direction == EAST then
    return self:GetWest()
  elseif direction == SOUTH then
    return self:GetNorth()
  else
    return self:GetEast()
  end
end

function InteriorSpawner:CreateRoom(interior, width, height, depth, dungeon_name, roomindex, addprops, exits, walltexture, floortexture, minimaptexture, cityID, cc, batted, playerroom, reverb, ambsnd, groundsound, cameraoffset, zoom)
    if not interior then
        interior = "generic_interior"
    end
    if not width then
        width = 15
    end
    if not depth then
        depth = 10
    end

    assert(roomindex)

  -- SET A DEFAULT CC FOR INTERIORS
    if not cc then
      cc = "images/colour_cubes/day05_cc.tex"
    end

    local interior_def =
    {
        unique_name = roomindex,
        dungeon_name = dungeon_name,
        width = width,
        height = height,
        depth = depth,
        prefabs = {},
        walltexture = walltexture,
        floortexture = floortexture,
        minimaptexture = minimaptexture,
        cityID = cityID,
        cc = cc,
        visited = false,
        batted = batted,
        playerroom = playerroom,
        enigma = false,
        reverb = reverb,
        ambsnd = ambsnd,
        groundsound = groundsound,
        cameraoffset = cameraoffset,
        zoom = zoom,
    }

    table.insert(interior_def.prefabs, { name = interior, x_offset = -2, z_offset = 0 })

    local prefab = {}

    for i, prefab  in ipairs(addprops) do
        table.insert(interior_def.prefabs, prefab)
    end

    for t, exit in pairs(exits) do
        if     t == NORTH then
            prefab = { name = "prop_door", x_offset = -depth/2, z_offset = 0, sg_name = exit.sg_name, startstate = exit.startstate, animdata = { minimapicon = exit.minimapicon, bank = exit.bank, build = exit.build, anim = "north", background = true },
                        my_door_id = roomindex.."_NORTH", target_door_id = exit.target_room.."_SOUTH", target_interior = exit.target_room, rotation = -90, hidden = false, angle=0, addtags = { "lockable_door", "door_north" } }
        elseif t == SOUTH then
            prefab = { name = "prop_door", x_offset = (depth/2), z_offset = 0, sg_name = exit.sg_name, startstate = exit.startstate, animdata = { minimapicon = exit.minimapicon, bank = exit.bank, build = exit.build, anim = "south", background = false },
                        my_door_id = roomindex.."_SOUTH", target_door_id = exit.target_room.."_NORTH", target_interior = exit.target_room, rotation = -90, hidden = false, angle=180, addtags = { "lockable_door", "door_south" } }

            if not exit.secret then
              table.insert(interior_def.prefabs, { name = "prop_door_shadow", x_offset = (depth/2), z_offset = 0, animdata = { bank = exit.bank, build = exit.build, anim = "south_floor" } })
            end

        elseif t == EAST then
            prefab = { name = "prop_door", x_offset = 0, z_offset = width/2, sg_name = exit.sg_name, startstate = exit.startstate, animdata = { minimapicon = exit.minimapicon, bank = exit.bank, build = exit.build, anim = "east", background = true },
                        my_door_id = roomindex.."_EAST", target_door_id = exit.target_room.."_WEST", target_interior = exit.target_room, rotation = -90, hidden = false, angle=90, addtags = { "lockable_door", "door_east" } }
        elseif t == WEST then
            prefab = { name = "prop_door", x_offset = 0, z_offset = -width/2, sg_name = exit.sg_name, startstate = exit.startstate, animdata = { minimapicon = exit.minimapicon, bank = exit.bank, build = exit.build, anim = "west", background = true },
                        my_door_id = roomindex.."_WEST", target_door_id = exit.target_room.."_EAST", target_interior = exit.target_room, rotation = -90, hidden = false, angle=270, addtags = { "lockable_door", "door_west" } }
        end

        if exit.vined then
          prefab.vined = true
        end

        if exit.secret then
          prefab.secret = true
          prefab.hidden = true
        end

        table.insert(interior_def.prefabs, prefab)
    end

    self:AddInterior(interior_def)
end

function InteriorSpawner:GetInteriorsByDungeonName(dungeonname)
  if dungeonname == nil then
    return nil
  else
    local tempinteriors = {}
    for i,interior in pairs(self.interiors)do
      if interior.dungeon_name == dungeonname then
        table.insert(tempinteriors,interior)
      end
    end
    return tempinteriors
  end
end

function InteriorSpawner:GetInteriorByName(name)
  if name == nil then
    return nil
  else
    local interior = self.interiors[name]
    if interior == nil then
      print("!!ERROR: Unable To Find Interior Named:"..name)
    end

    return interior
  end
end

function InteriorSpawner:GetInteriorByDoorId(door_id)
  local interior = nil
  local door_data = self.doors[door_id]
  if door_data and door_data.my_interior_name then
    interior = self.interiors[door_data.my_interior_name]
  end

  if not interior then
    print("THERE WAS NO INTERIOR FOR THIS DOOR, ITS A WORLD DOOR.", door_id)
  end
  -- assert(interior,"!!ERROR: Unable To Find Interior Due To Missing Door Data, For Door Id:"..door_id)

  return interior
end

function InteriorSpawner:RefreshDoorsNotInLimbo()

  local pt = self:getSpawnOrigin()

  --collect all the things in the "interior area" minus the interior_spawn_origin and the player
  local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 50, nil, {"INTERIOR_LIMBO"})
--    dumptable(ents,1,1,1)
  local south_door = nil
  local shadow = nil
--  print(#ents)
  for i = #ents, 1, -1 do
    if ents[i] then
--      print(i)

      if ents[i]:HasTag("door_south") then
        south_door = ents[i]
      end

      if ents[i].prefab == "prop_door_shadow" then
        shadow = ents[i]
      end
    end
  end

  if south_door and shadow then
    south_door.shadow = shadow
  end

  for i = #ents, 1, -1 do
    if ents[i] then
      if ents[i].components.door then
        ents[i].components.door:updateDoorVis()
      end
    end
  end

  return ents

end

function InteriorSpawner:GetCurrentInteriorEntities()
  local pt = self:getSpawnOrigin()

  -- collect all the things in the "interior area" minus the interior_spawn_origin and the player

  local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 20, nil, {"INTERIOR_LIMBO","interior_spawn_storage"})
  assert(ents ~= nil)
  assert(#ents > 0)

  --local deleteents = {}
  local prev_ents = ents
  for i = #ents, 1, -1 do
    local following = self:CheckIsFollower(ents[i])
    if not ents[i] then
      print("entry", i, "was null for some reason?!?")
    end
    --print("#### current length:", #ents, "i:", i, "prefab:", ents[i].prefab)

    if following or ents[i]:HasTag("interior_spawn_origin") or (ents[i] == GetPlayer()) or ents[i]:IsInLimbo() or ents[i]:HasTag("INTERIOR_LIMBO_IMMUNE") then

      table.remove(ents, i)
    end
  end

--  for i, ent in ipairs(deleteents)do
    --ent:Remove()
  --end

  -- Some sanity check to try to figure out the black room issue
  -- In order to skip the rooms that were bugged on load we won't do this if the FindEntities returned nothing. Those rooms are E.M.P.T.Y
  if #ents == 0 then
    if not self.alreadyFlagged[self.current_interior.unique_name] then
      -- don't mark as flagged, I want the sanity check to run still
      print("*** Error *** InteriorSpawner:GetCurrentInteriorEntities - No entities found in "..self.current_interior.unique_name.." ("..self.current_interior.dungeon_name..")")
      print("", "Entities before cull:",#prev_ents)
      for i,v in pairs(prev_ents) do
        print("",i,v)
      end
    end
--    assert(#ents > 0)
  end

--  assert(#ents > 0)

  return ents
end

function InteriorSpawner:PrintDoorStatus(objectInInterior, tagName)
    local tagMsg = ""
    local entMsg = ""

    if objectInInterior.components.door.hidden then tagMsg = "disabled" else tagMsg = "enabled" end
    if objectInInterior.entity:IsVisible() then entMsg = "visible" else entMsg = "invisible" end
    print("INTERIOR SPAWNER: "..tagName.." (tag indicates "..tagMsg.. ") (ent = "..entMsg..")")
end

function InteriorSpawner:DebugPrint()
  local relatedInteriors = self:GetCurrentInteriors()
  print("INTERIOR SPAWNER: PRINTING INTERIOR")

  if self.current_interior then
    print("INTERIOR SPAWNER: CURRENT INTERIOR = "..self.current_interior.unique_name)
    local pt = self:getSpawnOrigin()

    --collect all the things in the "interior area" minus the interior_spawn_origin and the player
    local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 50, nil, {"INTERIOR_LIMBO"})

    for k, v in ipairs(ents) do
      if v.components.door then
        if v:HasTag("door_north") then
          self:PrintDoorStatus(v, "door_north")
        elseif v:HasTag("door_south") then
          self:PrintDoorStatus(v, "door_south")
        elseif v:HasTag("door_east") then
          self:PrintDoorStatus(v, "door_east")
        elseif v:HasTag("door_west") then
          self:PrintDoorStatus(v, "door_west")
        end
      end
    end
  end
end

local function IsCompleteDisguise(target)
   return target:HasTag("has_antmask") and target:HasTag("has_antsuit")
end

function InteriorSpawner:PutPropIntoInteriorLimbo(prop,interior,ignoredisplacement)
  if not prop.persists then
    prop:Remove()
  else
    if interior then
      table.insert(interior.object_list, prop)
    end
    prop:AddTag("INTERIOR_LIMBO")
    prop.interior = interior.unique_name

    if prop.components.playerprox and prop.components.playerprox.onfar then
      prop.components.playerprox.onfar(prop)
    end

      if prop.SoundEmitter then
          prop.SoundEmitter:OverrideVolumeMultiplier(0)
      end

    if prop.Physics and not prop.Physics:IsActive() then
      prop.dissablephysics = true
    end
    if prop.removefrominteriorscene then
      prop.removefrominteriorscene(prop)
    end
    prop:RemoveFromScene(true)

    local pt1 = self:getSpawnOrigin()
    local pt2 = self:getSpawnStorage()

    if pt2 and not prop.parent and not ignoredisplacement then
      local diffx = pt2.x - pt1.x
      local diffz = pt2.z - pt1.z

      local proppt = Vector3(prop.Transform:GetWorldPosition())
      prop.Transform:SetPosition(proppt.x + diffx, proppt.y, proppt.z +diffz)

    end
  end
end

function InteriorSpawner:UnloadInterior()
  self:SanityCheck("Pre UnloadInterior")
  if self.current_interior then
    print("Unload interior "..self.current_interior.unique_name.."("..self.current_interior.dungeon_name..")")
    -- THIS UNLOADS THE CURRENT INTERIOR IN THE WORLD
    local interior = self.current_interior

    local ents = self:GetCurrentInteriorEntities()

    -- whipe the rooms object list, then fill it with all the stuff found at this place,
    -- then remove them from the scene
    interior.object_list = {}
    for k, v in ipairs(ents) do
      if v.prefab == "antman" then
        local target = v.components.combat.target
        if target and IsCompleteDisguise(target) then
          v.combatTargetWasDisguisedOnExit = true
        end
      end
      self:PutPropIntoInteriorLimbo(v,interior)
    end
    self:ConsiderPlayerNotInside(self.current_interior.unique_name)
    self.current_interior = nil
  else
    print("COMING FROM OUTSIDE, NO INTERIOR TO UNLOAD")
  end
  self:SanityCheck("Post UnLoadInterior")
end

function InteriorSpawner:LoadInterior(interior)
  self:SanityCheck("Pre LoadInterior")
  assert(interior, "No interior was set to load")

  -- THIS IS WHERE THE INTERIOR SHOULD BE SET
  print("Loading Interior "..interior.unique_name.. " With Handle "..interior.handle)
  GetWorld().Map:SetInterior( interior.handle )

  local hasdoors = false
  -- when an interior is called, it will either need to spawn all of it's contents the first time (prefabs attribute)
  -- or move its contents from limbo. (object_list attribute)
  if interior.prefabs then
    self:SpawnInterior(interior)
    self:RefreshDoorsNotInLimbo()
    interior.prefabs = nil
  else
    local prop_door_shadow = nil
    local doors_in_limbo = {}

    local pt1 = self:getSpawnStorage()
    local pt2 = self:getSpawnOrigin()

    local objects_to_return  = {}  -- make a copy, as it can be modified during iteration
    for k, v in ipairs(interior.object_list) do
      objects_to_return[k] = v
    end
    for k, v in ipairs(objects_to_return) do
      if pt1 and not v.parent then
        local diffx = pt2.x - pt1.x
        local diffz = pt2.z - pt1.z

        local proppt = Vector3(v.Transform:GetWorldPosition())
        v.Transform:SetPosition(proppt.x + diffx, proppt.y, proppt.z +diffz)
      end
      v:ReturnToScene()
      v:RemoveTag("INTERIOR_LIMBO")
      v.interior = nil

        if v.SoundEmitter then
            v.SoundEmitter:OverrideVolumeMultiplier(1)
        end

      if v.dissablephysics then
        v.dissablephysics = nil
        v.Physics:SetActive(false)
      end

      -- I am really not pleased with this function. TODO: Use callbacks to entities/components for this
      if v.prefab == "antman" then
        if IsCompleteDisguise(GetPlayer()) and not v.combatTargetWasDisguisedOnExit then
          v.components.combat.target = nil
        end
        v.combatTargetWasDisguisedOnExit = false
      end

      if v.Light and v.components.machine and not v.components.machine.ison then
          v.Light:Enable(false)
      end

      if v.prefab == "prop_door_shadow" then
        prop_door_shadow = v
      end

      if v:HasTag("interior_door") then
        table.insert(doors_in_limbo, v)
      end
      if v.returntointeriorscene then
        v.returntointeriorscene(v)
      end
      if not v.persists then
        v:Remove()
      end
    end

    for k, v in ipairs(doors_in_limbo) do
      hasdoors = true
      v:ReturnToScene()
      v:RemoveTag("INTERIOR_LIMBO")
      if (v.sg == nil) and (v.sg_name ~= nil) then
        v:SetStateGraph(v.sg_name)
        v.sg:GoToState(v.startstate)
      end

      if v:HasTag("door_south") then
        v.shadow = prop_door_shadow
      end

      v.components.door:updateDoorVis()
    end

    interior.object_list = {}
  end

  interior.enigma = false
  self.current_interior = interior
  self:ConsiderPlayerInside(self.current_interior.unique_name)

  if not hasdoors then
    print("*** Warning *** InteriorSpawner:LoadInterior - no doors for interior "..interior.unique_name.." ("..interior.dungeon_name..")")
  end

  -- Loaded interior, configure the walls
  self:ConfigureWalls(interior)

  self:SanityCheck("Post LoadInterior")
end

function InteriorSpawner:insertprefab(interior, prefab, offset, prefabdata)
  if interior.visited then
    local pt = self:getSpawnOrigin()
    local object = SpawnPrefab(prefab)
    object.Transform:SetPosition(pt.x + offset.x_offset, 0, pt.z + offset.z_offset)
    object:RemoveFromScene(true)
    object:AddTag("INTERIOR_LIMBO")
    if prefabdata and prefabdata.startstate then
      object.sg:GoToState(prefabdata.startstate)
      if prefabdata.startstate == "forcesleep" then
        object.components.sleeper.hibernate = true
        object.components.sleeper:GoToSleep()
      end
    end
    table.insert(interior.object_list, object)
  else
    local data = {name = prefab, x_offset = offset.x_offset, z_offset = offset.z_offset }
    if prefabdata then
      for arg, param in pairs(prefabdata) do
        data[arg] = param
      end
    end
    table.insert(interior.prefabs, data)
  end
end

function InteriorSpawner:InsertDoor(interior, door_data)
  if interior.visited then
    local pt = self:getSpawnOrigin()
    local object = SpawnPrefab("prop_door")
    object.Transform:SetPosition(pt.x + door_data.x_offset, 0, pt.z + door_data.z_offset)
    object:RemoveFromScene(true)
    object:AddTag("INTERIOR_LIMBO")

    object.initInteriorPrefab(object, GetPlayer(), door_data, interior)

    table.insert(interior.object_list, object)
  else

    local data = door_data
    table.insert(interior.prefabs, data)
  end
end

function InteriorSpawner:SpawnInterior(interior)

  -- this function only gets run once per room when the room is first called.
  -- if the room has a "prefabs" attribute, it means the prefabs have not yet been spawned.
  -- if it does not have a prefab attribute, it means they have bene spawned and all the rooms
  -- contents will now be in object_list

  print("SPAWNING INTERIOR, FIRST TIME ONLY")

  local pt = self:getSpawnOrigin()

  for k, prefab in ipairs(interior.prefabs) do

    if GetWorld().getworldgenoptions(GetWorld())[prefab.name] and GetWorld().getworldgenoptions(GetWorld())[prefab.name] == "never" then
      print("CANCEL SPAWN ITEM DUE TO WORLD GEN PREFS", prefab.name)
     else

      print("SPAWN ITEM", prefab.name)

      local object = SpawnPrefab(prefab.name)
      object.Transform:SetPosition(pt.x + prefab.x_offset, 0, pt.z + prefab.z_offset)

      -- flips the art of the item. This must be manually saved on items it it's to persist over a save
      if prefab.flip then
        local rx, ry, rz = object.Transform:GetScale()
        object.flipped = true
        object.Transform:SetScale(rx, ry, -rz)
      end

      -- sets the initial roation of an object, NOTE: must be manually saved by the item to survive a save
      if prefab.rotation then
        object.Transform:SetRotation(prefab.rotation)
      end

      -- adds tags to the object
      if prefab.addtags then
        for i, tag in ipairs(prefab.addtags) do
          object:AddTag(tag)
        end
      end

      if prefab.hidden then
        object.components.door.hidden = true
      end

      if prefab.angle then
        object.components.door.angle = prefab.angle
      end

      -- saves the roomID on the object
      if object.components.shopinterior or object.components.shopped or object.components.shopdispenser then
        object.interiorID = interior.unique_name
      end

      -- sets an anim to start playing
      if prefab.startAnim then
        object.AnimState:PlayAnimation(prefab.startAnim)
        object.startAnim = prefab.startAnim
      end

      if prefab.usesounds then
        object.usesounds = prefab.usesounds
      end

      if prefab.saleitem then
        object.saleitem = prefab.saleitem
      end

      if prefab.justsellonce then
        object:AddTag("justsellonce")
      end

      if prefab.startstate then
        object.startstate = prefab.startstate
        if object.sg == nil then
          object:SetStateGraph(prefab.sg_name)
          object.sg_name = prefab.sg_name
        end

        object.sg:GoToState(prefab.startstate)

        if prefab.startstate == "forcesleep" then
          object.components.sleeper.hibernate = true
          object.components.sleeper:GoToSleep()
        end
      end

      if prefab.shelfitems then
        object.shelfitems = prefab.shelfitems
      end

      -- this door should have vines
      if prefab.vined and object.components.vineable then
        object.components.vineable:SetUpVine()
      end


      -- this function processes the extra data that the prefab has attached to it for interior stuff.
      if object.initInteriorPrefab then
        object.initInteriorPrefab(object, GetPlayer(), prefab, interior)
      end

      -- should the door be closed for some reason?
      -- needs to happen after the object initinterior so the door info is there.
      if prefab.door_closed then
        for cause,setting in pairs(prefab.door_closed)do
          object.components.door:checkDisableDoor(setting, cause)
        end
      end

      if prefab.secret then
        object:AddTag("secret")
        object:RemoveTag("lockable_door")
        object:Hide()

        self.inst:DoTaskInTime(0, function()
          local crack = SpawnPrefab("wallcrack_ruins")
          crack.SetCrack(crack, object)
        end)
      end

      -- needs to happen after the door_closed stuff has happened.
      if object.components.vineable then
        object.components.vineable:InitInteriorPrefab()
      end

      if interior.cityID then
          object:AddComponent("citypossession")
          object.components.citypossession:SetCity(interior.cityID)
      end

      if object.decochildrenToRemove then
        for i, child in ipairs(object.decochildrenToRemove) do
          if child then
            local ptc = Vector3(object.Transform:GetWorldPosition())
                    child.Transform:SetPosition( ptc.x ,ptc.y, ptc.z )
                    child.Transform:SetRotation( object.Transform:GetRotation() )
                end
        end
      end
    end
  end

  interior.visited = true
end

function InteriorSpawner:IsInInterior()
  return TheCamera == self.interiorCamera
end

function InteriorSpawner:GetInteriorDoors(interiorID)
  local found_doors = {}

  for k, door in pairs(self.doors) do
    if door.my_interior_name == interiorID then
      table.insert(found_doors, door)
    end
  end

  return found_doors

end

function InteriorSpawner:GetDoorInst(door_id)
  local door_data = self.doors[door_id]
  if door_data then
    if door_data.my_interior_name then
      local interior = self.interiors[door_data.my_interior_name]
      for k, v in ipairs(interior.object_list) do
        if v.components.door and v.components.door.door_id == door_id then
          return v
        end
      end
    else
      return door_data.inst
    end
  end
  return nil
end

function InteriorSpawner:AddDoor(inst, door_definition)
  --print("ADDING DOOR", door_definition.my_door_id)
  -- this sets some properties on the door component of the door object instance
  -- this also adds the door id to a list here in interiorspawner so it's easier to find what room needs to load when a door is used
  self.doors[door_definition.my_door_id] = { my_interior_name = door_definition.my_interior_name, inst = inst, target_interior = door_definition.target_interior }

  if inst ~= nil then
    if inst.components.door == nil then
      inst:AddComponent("door")
    end
    inst.components.door.door_id = door_definition.my_door_id
    inst.components.door.interior_name = door_definition.my_interior_name
    inst.components.door.target_door_id = door_definition.target_door_id
    inst.components.door.target_interior = door_definition.target_interior
  end
end

function InteriorSpawner:AddInterior(interior_definition)
  -- print("CREATING ROOM", interior_definition.unique_name)
  local spawner_definition = self.interiors[interior_definition.unique_name]

  assert(not spawner_definition, "THIS ROOM ALREADY EXISTS: "..interior_definition.unique_name)

  spawner_definition = interior_definition
  spawner_definition.object_list = {}
  spawner_definition.handle = createInteriorHandle(spawner_definition)
  self.interiors[spawner_definition.unique_name] = spawner_definition

  -- if batcave, register with the batted component.
  if spawner_definition.batted then
    if GetWorld().components.batted then
      GetWorld().components.batted:registerInterior(spawner_definition.unique_name)
    end
  end
end

function InteriorSpawner:getPropInterior(inst)

  for room, data in pairs(self.interiors)do
    for p, prop in ipairs(data.object_list)do
      if inst == prop then
        return room
      end
    end
  end
end

function InteriorSpawner:removeprefab(inst,interiorID)
  print("trying to remove",inst.prefab,interiorID)
  local interior = self.interiors[interiorID]
  if interior then
    for i, prop in ipairs(interior.object_list) do
      if prop == inst then
        print("REMOVING",prop.prefab)
        table.remove(interior.object_list, i)
        break
      end
    end
  end
end

function InteriorSpawner:injectprefab(inst,interiorID)
  local interior = self.interiors[interiorID]
  inst:RemoveFromScene(true)
  inst:AddTag("INTERIOR_LIMBO")
  table.insert(interior.object_list, inst)
end

function InteriorSpawner:OnSave()
  -- print("InteriorSpawner:OnSave")
  self:SanityCheck("Pre Save")

  local data =
  {
    interiors = {},
    doors = {},
    next_interior_ID = self.next_interior_ID,
    current_interior = self.current_interior and self.current_interior.unique_name or nil,
  }

  local refs = {}

  for k, room in pairs(self.interiors) do

    local prefabs = nil
    if room.prefabs then
      prefabs = {}
      for k, prefab in ipairs(room.prefabs) do
        local prefab_data = prefab
        table.insert(prefabs, prefab_data)
      end
    end

    local object_list = {}
    for k, object in ipairs(room.object_list) do
      local save_data = object.GUID
      table.insert(object_list, save_data)
      table.insert(refs, object.GUID)
    end

    local interior_data =
    {
      unique_name = k,
      z = room.z,
      x = room.x,
      dungeon_name = room.dungeon_name,
      width = room.width,
      height = room.height,
      depth = room.depth,
      object_list = object_list,
      prefabs = prefabs,
      walltexture = room.walltexture,
      floortexture = room.floortexture,
      minimaptexture = room.minimaptexture,
      cityID = room.cityID,
      cc = room.cc,
      visited = room.visited,
      batted = room.batted,
      playerroom = room.playerroom,
      enigma = room.enigma,
      reverb = room.reverb,
      ambsnd = room.ambsnd,
      groundsound = room.groundsound,
      zoom = room.zoom,
      cameraoffset = room.cameraoffset,
    }

    table.insert(data.interiors, interior_data)
  end

  for k, door in pairs(self.doors) do
    local door_data =
    {
      name = k,
      my_interior_name = door.my_interior_name,
      target_interior = door.target_interior,
      secret = door.secret,
    }
    if door.inst then
      door_data.inst_GUID = door.inst.GUID
      table.insert(refs, door.inst.GUID)
    end
    table.insert(data.doors, door_data)
  end

  --Store camera details
  if TheCamera.interior_distance then
    data.interior_x = TheCamera.interior_currentpos.x
    data.interior_y = TheCamera.interior_currentpos.y
    data.interior_z = TheCamera.interior_currentpos.z
    data.interior_distance = TheCamera.interior_distance
  end

  return data, refs
end

function InteriorSpawner:OnLoad(data)
  self.interiors = {}
  for k, int_data in ipairs(data.interiors) do
    -- Create placeholder definitions with saved locations
    self.interiors[int_data.unique_name] =
    {
      unique_name = int_data.unique_name,
      z = int_data.z,
      x = int_data.x,
      dungeon_name = int_data.dungeon_name,
      width = int_data.width,
      height = int_data.height,
      depth = int_data.depth,
      object_list = {},
      prefabs = int_data.prefabs,
      walltexture = int_data.walltexture,
      floortexture = int_data.floortexture,
      minimaptexture = int_data.minimaptexture,
      cityID = int_data.cityID,
      cc = int_data.cc,
      visited = int_data.visited,
      batted = int_data.batted,
      playerroom = int_data.playerroom,
      enigma = int_data.enigma,
      reverb = int_data.reverb,
      ambsnd = int_data.ambsnd,
      groundsound = int_data.groundsound,
      zoom = int_data.zoom,
      cameraoffset = int_data.cameraoffset,
    }

    self.interiors[int_data.unique_name].handle = createInteriorHandle(self.interiors[int_data.unique_name])

    -- if batcave, register with the batted component.
    if int_data.batted then
      if GetWorld().components.batted then
        GetWorld().components.batted:registerInterior(int_data.unique_name)
      end
    end
  end

  for k, door_data in ipairs(data.doors) do
    self.doors[door_data.name] =  { my_interior_name = door_data.my_interior_name, target_interior = door_data.target_interior, secret = door_data.secret }
  end

  GetWorld().components.colourcubemanager:SetInteriorColourCube(nil)

  if data.current_interior then
    self.current_interior = self:GetInteriorByName(data.current_interior)
    self:ConsiderPlayerInside(self.current_interior.unique_name)
    GetWorld().components.colourcubemanager:SetInteriorColourCube( self.current_interior.cc )
  end

  self.next_interior_ID = data.next_interior_ID
end

function InteriorSpawner:CleanUpMessAroundOrigin()
  local function removeStray(ent)
    print("Removing stray "..ent.prefab)
    ent:Remove()
  end
  for i,v in pairs(Ents) do
    if v.Transform then
      local pos = v:GetPosition()
      if v.prefab == "window_round_light" and pos == Vector3(0,0,0) then
        removeStray(v)
      end
      if v.prefab == "window_round_light_backwall" and pos == Vector3(0,0,0) then
        removeStray(v)
      end
      if v.prefab == "home_prototyper" and v ~= self.homeprototyper then
        removeStray(v)
      end
    end
  end
end

function InteriorSpawner:LoadPostPass(ents, data)
  self:CleanUpMessAroundOrigin()

  self:RefreshDoorsNotInLimbo()

  -- fill the object list
  for k, room in pairs(data.interiors) do
    local interior = self:GetInteriorByName(room.unique_name)
    if interior then
      for i, object in pairs(room.object_list) do
        if object and ents[object] then
          local object_inst = ents[object].entity
          table.insert(interior.object_list, object_inst)
          object_inst.interior = room.unique_name
        else
          print("*** Warning *** InteriorSpawner:LoadPostPass object "..tostring(object).." not found for interior "..interior.unique_name)
        end
      end
    else
      print("*** Warning *** InteriorSpawner:LoadPostPass Could not fetch interior "..room.unique_name)
    end
  end

  -- fill the inst of the doors.
  for k, door_data in pairs(data.doors) do
    if door_data.inst_GUID then
      if   ents[door_data.inst_GUID] then
        self.doors[door_data.name].inst =  ents[door_data.inst_GUID].entity
      end
    end
  end

  -- camera load stuff
  if self.exteriorCamera == nil then
    -- TODO: Find better location for this
    self.exteriorCamera = TheCamera
    self.interiorCamera = InteriorCamera()
  end

  if data.interior_x then
    local player = GetPlayer()
    TheCamera = self.interiorCamera
    TheCamera.interior_currentpos = Vector3(data.interior_x, data.interior_y, data.interior_z)
    TheCamera.interior_distance = data.interior_distance
    TheCamera:SetTarget(player)
  end

  if self.current_interior then
    local pt_current = self:getSpawnOrigin()
    local pt_dormant = self:getSpawnStorage()
    InteriorManager:SetCurrentCenterPos2d( pt_current.x, pt_current.z )
    InteriorManager:SetDormantCenterPos2d( pt_dormant.x, pt_dormant.z )
    GetWorld().Map:SetInterior( self.current_interior.handle )
  end

  self:SanityCheck("Post Load")
  self:CheckForBlackRoomBug()
  self:FixRelicOutOfBounds()
end

function InteriorSpawner:CheckForInvalidSpawnOrigin()
  -- Trying to detect the issue with clouds in rooms/unplacable items
  local pt1 = self:getSpawnOrigin()
  print("SpawnOrigin:",pt1,GetTileType(pt1))
  if (GetTileType(pt1) == "IMPASSABLE") then
    print("World has suspicious SpawnOrigin")
  end
end

function InteriorSpawner:CheckForBlackRoomBug()
  print("Check for black room bug....")
  local hasError = false
  -- house hasn't been re-entered yet
  for _,v in pairs(self.interiors) do
    for _,k in pairs(v.object_list) do
      if k:HasTag("interior_spawn_storage") then
        print("Black room bug detected, interior not re-entered.")
        hasError = true
        break
      end
    end
  end
  -- house has been re-entered
  local pt_current = self:getSpawnOrigin()
  local pt_dormant = self:getSpawnStorage()
  local delta = pt_current - pt_dormant
  local deltaLen = delta:Length()
  if deltaLen < 1 then  -- yeah, it should 0 but whatevs
    print("Black room bug detected, interior re-entered")
    hasError = true
  end
  if hasError then
    print("*** Error *** World affected by black room bug, show message :(")
    GetWorld():DoTaskInTime(0, function() self:BlackRoomBugCheckPopup() end)
  else
    print("Seems we're good.")
  end
end

function InteriorSpawner:FixRelicOutOfBounds()
  print("FIXING RELIC OUT OF BOUNDS")
  for k, room in pairs(self.interiors) do
    local interior = self:GetInteriorByName(room.unique_name)

    if interior == self.current_interior then
      local pt = self:getSpawnOrigin()
      local ents = TheSim:FindEntities(pt.x,pt.y,pt.z, 40,nil,{"INTERIOR_LIMBO"})

      if ents and #ents > 0 then
        for i,ent in ipairs(ents)do
          if ent.prefab == "pig_ruins_truffle" or ent.prefab == "pig_ruins_sow" then
            local dist = ent:GetDistanceSqToInst(self.interior_spawn_origin)

            if dist > room.depth/2*room.depth/2 then
              local x,y,z = ent.Transform:GetWorldPosition()
              ent.Transform:SetPosition(x+4,y,z)
            end
          end
        end
      end
    else
      if room.prefabs and #room.prefabs > 0 then
        for i,prefab in ipairs(room.prefabs) do
          if prefab.name == "pig_ruins_truffle" or prefab.name == "pig_ruins_sow" then
            if prefab.x_offset < -room.depth/2 then
              prefab.x_offset = prefab.x_offset + 4
            end
          end
        end
      end
      if room.object_list and #room.object_list > 0 then
        for i,object in ipairs(room.object_list) do
          if object.prefab == "pig_ruins_truffle" or object.prefab == "pig_ruins_sow" then
            local dist = object:GetDistanceSqToInst(self.interior_spawn_storage)
            if dist > room.depth/2*room.depth/2 then
              local x,y,z = object.Transform:GetWorldPosition()
              object.Transform:SetPosition(x+4,y,z)
            end
          end
        end
      end
    end
  end
end

-- Sanity check. If we are in a room, that room has no prefabs nor object_list
-- all other rooms need either object_list (when stored) or prefabs (when never instantiated)
function InteriorSpawner:SanityCheck(reason)
  assert(reason)
  self:CheckForInvalidSpawnOrigin()
  for k, room in pairs(self.interiors) do
    local interior = self:GetInteriorByName(room.unique_name)
    if interior and not self.alreadyFlagged[room.unique_name] then
      local hasObjects = (#interior.object_list > 0)
      local hasPrefabs = (interior.prefabs ~= nil)
      if interior == self.current_interior then
        if (hasObjects or hasPrefabs) then
          self.alreadyFlagged[room.unique_name] = true
          print("*** Error *** InteriorSpawner ("..reason..")  Error: current interior "..room.unique_name.." ("..room.dungeon_name..") has objects or prefabs")
          print(debugstack())
        end
        --assert(not hasObjects and not hasPrefabs)
      else
        if (not (hasObjects or hasPrefabs)) then
          self.alreadyFlagged[room.unique_name] = true
          print("*** Error *** InteriorSpawner ("..reason..")  Error: non-current interior "..room.unique_name.." ("..room.dungeon_name..") has neither objects nor prefabs")
          print(debugstack())
        elseif (hasObjects and hasPrefabs) then
          self.alreadyFlagged[room.unique_name] = true
          print("*** Error *** InteriorSpawner ("..reason..") Error: non-current interior "..room.unique_name.." ("..room.dungeon_name..") has objects and prefabs")
          print(debugstack())
        end
        --assert(hasObjects or hasPrefabs)
        --assert(not (hasObjects and hasPrefabs))
      end
    end
  end
end

function InteriorSpawner:GetCurrentInteriors()
  local relatedInteriors = {}

  if self.current_interior then
    for key, interior in pairs(self.interiors) do
      if self.current_interior.dungeon_name == interior.dungeon_name then
        table.insert(relatedInteriors, interior)
      end
    end
  end

  return relatedInteriors
end

function InteriorSpawner:CountPrefabs(prefabName)
    local prefabCount = 0
    local relatedInteriors = self:GetCurrentInteriors()

  for i, interior in ipairs(relatedInteriors) do
        if interior == self.current_interior then
            local pt = self:getSpawnOrigin()
            -- collect all the things in the "interior area" minus the interior_spawn_origin and the player
            local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 50, {"interior_door"}, {"INTERIOR_LIMBO"})
            for p, objectInInterior in ipairs(ents) do
                if objectInInterior.prefab == prefabName then
                    prefabCount = prefabCount + 1
                end
            end
        elseif interior.object_list and (#interior.object_list > 0) then
            for p, objectInInterior in ipairs(interior.object_list) do
                if objectInInterior.prefab == prefabName then
                    prefabCount = prefabCount + 1
                end
            end
        end
    end

    return prefabCount
end


-- Try to fix up a really nasty bug that has crept in through a global variable 'name'
function InteriorSpawner:FixDoors()
  -- Get all player houses
        local interior_spawner = GetWorld().components.interiorspawner
  local playerInteriors = {}
  for i,v in pairs(interior_spawner.interiors) do
    if v.playerroom then
      if type(v.unique_name)=="number" then
        local name = v.unique_name
        playerInteriors[name]=v
      end
    end
  end

  local function fixDoorName(name, interior)
    local tail = name:sub(-5)
    if tail == "_door" or tail=="_exit" then
      local wanted_tail = interior..tail
      local actual_tail = name:sub(-#wanted_tail)
      if (actual_tail == wanted_tail) then
        local doorname = "playerhouse"..interior..tail
        return doorname
      end
    end
    return name
  end

  -- find all outside that refer to these interiors
  for i,v in pairs(Ents) do
    if v.components.door then
      local door_id = v.components.door.door_id
      if door_id then
        -- door going from outside to inside
        local target_interior = v.components.door.target_interior
        if playerInteriors[target_interior] then
          --print("has one as target_interior:",door_id)
          local oldname = v.components.door.door_id
          local newname = fixDoorName(oldname, target_interior)
          if oldname ~= newname then
            print("change",oldname,"to",newname)
            v.components.door.door_id = newname
          end
          local oldname = v.components.door.target_door_id
          local newname = fixDoorName(oldname, target_interior)
          if oldname ~= newname then
            print("change",oldname,"to",newname)
            v.components.door.target_door_id = newname
          end
        end
      end
    end
  end
  -- and all inside doors
  for i,v in pairs(Ents) do
    if v.components.door then
      local door_id = v.components.door.door_id
      if door_id then
        -- door going from outside to inside
        local interior_name = v.components.door.interior_name
        if playerInteriors[interior_name] then
          --print("has one as interior_name:",door_id)
          local oldname = v.components.door.door_id
          local newname = fixDoorName(oldname, interior_name)
          if oldname ~= newname then
            print("change",oldname,"to",newname)
            v.components.door.door_id = newname
          end
          local oldname = v.components.door.target_door_id
          local newname = fixDoorName(oldname, interior_name)
          if oldname ~= newname then
            print("change",oldname,"to",newname)
            v.components.door.target_door_id = newname
          end
        end
      end
    end
  end
  -- and now all doors in the InteriorManager
  local replaceDoors = {}
  for i,v in pairs(playerInteriors) do
    local interiorID = v.unique_name
    for j,k in pairs(interior_spawner.doors) do
      if k.my_interior_name == interiorID or k.target_interior == interiorID then
        --print("name:",j,"is one that qualifies for replacement")
        local oldname = j
        local newname = fixDoorName(oldname, v.unique_name)
        if oldname ~= newname then
          replaceDoors[oldname] = {name = newname, contents = k}
        end
      end
    end
  end
  -- do the replacements
  for i,v in pairs(replaceDoors) do
    print("Replace door",i,"with",v.name)
    -- nuke the old one
    interior_spawner.doors[i] = nil
    -- set the new one
    interior_spawner.doors[v.name] = v.contents
  end
  -- modify dungeon name if exists
  for i,v in pairs(playerInteriors) do
    local oldname = v.dungeon_name
    local newname = "playerhouse"..v.unique_name
    if oldname ~= newname then
      print("Changing dungeon name from",oldname,"to",newname)
      v.dungeon_name = newname
    end
    -- check if there's any prefabs in this dungeon that need to be renamed
    if v.prefabs then
      for j,k in pairs(v.prefabs) do
        if k.name=="prop_door" then
          -- my_door_id
          if k.my_door_id then
            local oldname = k.my_door_id
            local newname = fixDoorName(oldname, v.unique_name)
            if oldname ~= newname then
              print("change",oldname,"to",newname)
              k.my_door_id = newname
            end
          end
          if k.target_door_id then
            local oldname = k.target_door_id
            local newname = fixDoorName(oldname, v.unique_name)
            if oldname ~= newname then
              print("change",oldname,"to",newname)
              k.target_door_id = newname
            end
          end
        end
      end
    end
  end
end

function InteriorSpawner:IsPlayerConsideredInside(interior)
  -- if we're transitioning into, inside, or transitioning out of this will return true
  return self.considered_inside_interior[interior]
end

function InteriorSpawner:ConsiderPlayerInside(interior)
  self.considered_inside_interior[interior] = true
end

function InteriorSpawner:ConsiderPlayerNotInside(interior)
  self.considered_inside_interior[interior] = nil
end

function InteriorSpawner:ReturnFromHiddenDoorLimbo(v)
  local pt1 = self:getSpawnStorage()
  local pt2 = self:getSpawnOrigin()

  local prop_door_shadow = nil
  local doors_in_limbo = {}
  local hasdoors = false

  if pt1 and not v.parent then
    local diffx = pt2.x - pt1.x
    local diffz = pt2.z - pt1.z
    local proppt = Vector3(v.Transform:GetWorldPosition())
    v.Transform:SetPosition(proppt.x + diffx, proppt.y, proppt.z +diffz)
  end
  v:ReturnToScene()
  v:RemoveTag("INTERIOR_LIMBO")
  v.interior = nil

    if v.SoundEmitter then
        v.SoundEmitter:OverrideVolumeMultiplier(1)
    end

  if v.dissablephysics then
    v.dissablephysics = nil
    v.Physics:SetActive(false)
  end

  if v.prefab == "antman" then
    if IsCompleteDisguise(GetPlayer()) and not v.combatTargetWasDisguisedOnExit then
      v.components.combat.target = nil
    end
    v.combatTargetWasDisguisedOnExit = false
  end

  if v.prefab == "prop_door_shadow" then
    prop_door_shadow = v
  end

  if v:HasTag("interior_door") then
    table.insert(doors_in_limbo, v)
  end
  if v.returntointeriorscene then
    v.returntointeriorscene(v)
  end
  if not v.persists then
    v:Remove()
  end

  for k, v in ipairs(doors_in_limbo) do
    hasdoors = true
    v:ReturnToScene()
    v:RemoveTag("INTERIOR_LIMBO")
    if (v.sg == nil) and (v.sg_name ~= nil) then
      v:SetStateGraph(v.sg_name)
      v.sg:GoToState(v.startstate)
    end

    if v:HasTag("door_south") then
      v.shadow = prop_door_shadow
    end

    v.components.door:updateDoorVis()
  end
end

-- the hidden doors caused an issue. Try to clean up the damage
function InteriorSpawner:CleanupBlackRoomAfterHiddenDoor()
  local function PutInInterior(entity, interiorName)
    if self.current_interior and interiorName == self.current_interior.unique_name then
      -- needs to be moved in
      --assert(false)
      print("Returning",entity)
      self:ReturnFromHiddenDoorLimbo(entity)
    else
      local interior = self.interiors[interiorName]
      --assert(interior)
      --print("interior:",interior,interior.unique_name)
      -- add this entity to the object list for this interior
      if interior.object_list and #interior.object_list > 0 then
        local found = false
        for i,v in pairs(interior.object_list) do
          if v == entity then
            found = true
            break
          end
        end
        if not found then
          table.insert(interior.object_list,entity)
        end
      end
    end
  end
  local pt = self:getSpawnStorage()
  -- collect all the things in the "interior storage area" minus the interior_spawn_origin and the player
  local interior = self.current_interior
  if interior then
    print("We are currently in interior",interior.unique_name)
  else
    print("We are currently not in an interior")
  end
  local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 20, {"INTERIOR_LIMBO"}, {"interior_spawn_storage"})
  local lastpos
  for i,v in pairs(ents) do
    if v.interior then
      PutInInterior(v,v.interior)
    else
      -- ergh, no interior set on this, can we still salvage it?
      -- is it a door?
      if v.components.door then
        PutInInterior(v,v.components.door.interior_name)
        lastpos = v:GetPosition()
      end
    end
  end
  -- Is the player sitting near the spawn storage? Let's maybe not do that
  local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 20, nil, {"interior_spawn_storage"})
  for i,v in pairs(ents) do
    if v == GetPlayer() then
      local ent = SpawnPrefab("acorn")  -- everyone needs a magic acorn
      if lastpos then
        ent.Transform:SetPosition(lastpos.x, lastpos.y, lastpos.z)
      else
        -- no door to teleport to. Just try something
        local pt1 = self:getSpawnOrigin()
        local pt2 = self:getSpawnStorage()
        local delta = pt1-pt2
        local rightpos = v:GetPosition() + delta
        ent.Transform:SetPosition(rightpos.x, rightpos.y, rightpos.z)
      end
      self:ExecuteTeleport(v, ent)
      ent:Remove()
      break
    end
  end
  -- While at it, what about those that had no interior? Do they exist in an object list?
  local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, 20, nil, {"INTERIOR_LIMBO", "interior_spawn_storage"})
end

function InteriorSpawner:InPlayerRoom()
    return self.current_interior and self.current_interior.playerroom or false
end

return InteriorSpawner
