//=============================================================================
//
// lua\ai\BotAI_Marine.lua
//
// Copyright 2012 Sebastian J. (borstymail@googlemail.com)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//=============================================================================

class 'BotAI_Marine' (BotAI_Base)

local kMoveTimeout = 20

// is the player ok with this ai type?
function BotAI_Marine.IsPlayerApplicable(player)
    return player:isa("Marine")
end

function BotAI_Marine:AIName()
    return "BotAI_Marine"
end

// init
function BotAI_Marine:Initialize()
	// misc init
	self.targetReachedRange = 1.0
end

// leaving this ai
function BotAI_Marine:Dispose()
end

// think
function BotAI_Marine:OnThink(deltaTime)

	// misc
	self:TriggerAlerts()
	
	// reload weapon
	local activeWeapon = self:GetActiveWeapon()
    if (activeWeapon and activeWeapon:isa("ClipWeapon")) then
        if (activeWeapon:GetClip() <= 0 and activeWeapon:GetAmmo() > 0) then
            self:GetBot():Reload()
        end
    end
	
	// check flashlight
	if (math.random() < .1) then
		self:GetBot():Flashlight( self:IsDarkInHere() )
	end
    
    // super does state machinin'
    return BotAI_Base.OnThink(self, deltaTime)
end

// chat
function BotAI_Marine:OnChat(message, playerName, teamOnly)
end

function BotAI_Marine:OnSpawn()
    self:GetBot():SayAll("I spawned.")
    self.task = nil
	self.targetReachedRange = 1.0
	self:SetState(self.IdleState)
end

function BotAI_Marine:OnDeath()
    self:GetBot():SayAll("I died.")
    self.task = nil
	self:SetState(self.DeathState)
end

//=== Find helpers ============================================================

local kRepairRange = 10

function BotAI_Marine:FindPickupable(className)
	local player = self:GetPlayer()
	local playerPos = player:GetOrigin()
    local nearbyItems = GetEntitiesWithMixinWithinRangeAreVisible("Pickupable", player:GetEyePos(), 10, true)
    local closestPickup = nil
    local closestDistance = Math.infinity
	
    for i, nearby in ipairs(nearbyItems) do
        if nearby:GetIsValidRecipient(player) and ( className == nil or nearby:isa(className) ) then
			local nearbyDistance = (nearby:GetOrigin() - playerPos):GetLengthSquaredXZ()
            if nearbyDistance < closestDistance then
                closestPickup = nearby
                closestDistance = nearbyDistance
            end
        end
    end
	
    return closestPickup
end

function BotAI_Marine:FindRepairTarget()

    local player = self:GetPlayer()
    local eyePos = player:GetEyePos()
    local allowedDistance = kRepairRange * kRepairRange
    
    local repairTarget, closestDistance, ents, count
    
    // marines can be repaired only when we have a welder
    if (self:HasWeapon("Welder")) then
        ents = Shared.GetEntitiesWithClassname("Marine")
        count = ents:GetSize()
        for i = 0, count - 1 do
            local marine = ents:GetEntityAtIndex(i)
            if (marine ~= nil) then
                local distance = (marine:GetOrigin() - eyePos):GetLengthSquared()
                if distance < allowedDistance and marine:GetIsAlive() and marine:GetArmor() < marine:GetMaxArmor() and (repairTarget == nil or distance < closestDistance) then
                    repairTarget, closestDistance = marine, distance
                end
            end
        end
    end
    
    if repairTarget then
        return repairTarget
    end
    
    ents = Shared.GetEntitiesWithClassname("PowerPoint")    
    count = ents:GetSize()
    for i = 0, count - 1 do
        local powerPoint = ents:GetEntityAtIndex(i)
		if (powerPoint ~= nil) then
			local distance = (powerPoint:GetOrigin() - eyePos):GetLengthSquared()
			if distance < allowedDistance and powerPoint:GetIsSocketed() and powerPoint:GetHealthScalar() < 1. and (repairTarget == nil or distance < closestDistance) then
				repairTarget, closestDistance = powerPoint, distance
			end
		end
    end
    
    // TODO if we got welder, check for damaged buildings
    if (self:HasWeapon("Welder")) then
    end

    return repairTarget
end

function BotAI_Marine:FindMovingTarget()
    return self:GetBot():GetMoblieAttackTarget()
end

function BotAI_Marine:FindStaticTarget()
    return self:GetBot():GetStaticAttackTarget()
end

//=== Weapons =================================================================

function BotAI_Marine:GetWeapons()

    local player = self:GetPlayer()
    local primary, secondary
    for _, weapon in ientitychildren(player, "ClipWeapon") do
      local slot = weapon:GetHUDSlot()
      if slot == kSecondaryWeaponSlot then
        secondary = weapon
      elseif slot == kPrimaryWeaponSlot then
        primary = weapon
      end
    end
    return primary, secondary
end

function BotAI_Marine:GetAmmoScalar()

    local player = self:GetPlayer()
    local ammo, maxAmmo = 0, 0
    for _, weapon in ientitychildren(player, "ClipWeapon") do
        ammo = ammo + weapon:GetAmmo()
        maxAmmo = maxAmmo + weapon:GetMaxAmmo()
    end
    if maxAmmo == 0 then // alien
        return 1
    end
    return ammo / maxAmmo
end

function BotAI_Marine:HasWeapon(weaponClass)
    local player = self:GetPlayer()
    for _, weapon in ientitychildren(player, "Weapon") do
        if weapon:isa(weaponClass) then
            return true
        end
    end
    return false
end

//=== Misc ====================================================================

function BotAI_Marine:GetLocation()
	return GetLocationForPoint(self:GetPlayer():GetOrigin())
end

// check the local powernode if it's destroyed
function BotAI_Marine:IsDarkInHere()
	local location = self:GetLocation()
	if (location) then
		
		// find powernode
		local powerpoint = GetPowerPointForLocation(location:GetName())
		
		// find
		return powerpoint and (powerpoint:GetIsBuilt() /*and powerpoint:GetIsSocketed()*/ and not powerpoint:GetIsPowering())
	end
	
	return false
end

function BotAI_Marine:TriggerAlerts()

    local player = self:GetPlayer()
    
    if self.lastAlertTime and self.currentTime - self.lastAlertTime < 15 then
        return
    end
    
    if not self:GetBot():GetHasCommander() then
        return
    end
    
    // ask for for medpack
    if player:GetHealthScalar() < .4 then
	
        self.lastAlertTime = self.currentTime
		
		// TODO check for nearby medpacks
		local pickupable = self:FindPickupable("MedPack")
		if pickupable ~= nil then
		else
			if math.random() < .5 then
				// TODO: consider armory distance
				player:GetTeam():TriggerAlert(kTechId.MarineAlertNeedMedpack, player)
			end
		end
    end
    
    // ask for ammo pack
    if self:GetAmmoScalar() < .5 then
        self.lastAlertTime = self.currentTime

		local pickupable = self:FindPickupable("AmmoPack")
		if pickupable ~= nil then
		else
			if math.random() < .5 then
				// TODO: consider armory distance
				player:GetTeam():TriggerAlert(kTechId.MarineAlertNeedAmmo, player)
			end
		end
    end
    
    // ask for orders 
    if not self.task or self.task:GetDuration() > 180 then
        self.lastAlertTime = self.currentTime
        if math.random() < .5 then
            player:GetTeam():TriggerAlert(kTechId.MarineAlertNeedOrder, player)
        end
    end
end

//=== Orders ==================================================================

// a class for orders :)
class 'BotTask'

local kBotTaskOrders = enum({ "None", "Attack", "Construct", "Move", "Pickup" })

local function MakeBotTask(orderType, orderLocation, orderTarget, preferredState)
	local t = BotTask()
	t:Init(orderType, orderLocation, orderTarget, preferredState)
	return t
end

function BotTask:Init(orderType, orderLocation, orderTarget, preferredState)
    self.type = orderType or kBotTaskOrders.None
    self.location = orderLocation
    
    if (not orderTarget) then
        self.targetId = Entity.invalidId
    elseif (type(orderTarget)=="number") then
        self.targetId = orderTarget
    else
        self.targetId = orderTarget:GetId()
    end
    
    self.state = preferredState
    self.time = Shared.GetTime()
end

function BotTask:State()
    return self.state
end

function BotTask:GetDuration()
    return Shared.GetTime() - self.time
end 

function BotTask:Type()
    return self.type
end

function BotTask:Location()
    if (self.location) then return self.location end
    
    local target = self:Target()
    if (target) then
        return (target.GetOrigin and target:GetOrigin()) or target:GetEngagementPoint()
    end
end

function BotTask:Target()
    return Shared.GetEntity(self.targetId)
end

function BotTask:TargetId()
    return self.targetId
end

function BotTask:IsValid()
    return (not self.done) and self:Type() and self:State() and self:Location() and self:Type() ~= kBotTaskOrders.None and self:Location():isa("Vector")
end

function BotTask:SetDone(done)
    self.done = done
end

function BotTask:IsDone()
    return self.done
end 

function BotTask:Equals(other)
    local a = self.state == other.state
    local b = self.type  == other.type
    local c = self.targetId == other.targetId
    local d = (not self.location or self.location == other.location)
    
    return a and b and c and d
end

// check if we've got an order from our commander
function BotAI_Marine:GetCommanderOrder()

    // dont run every tick :)
    if (self.commandOrderTime and self.commandOrderTime > Shared.GetTime()) then
        return
    end
    self.commandOrderTime = Shared.GetTime() + 0.5
    
    local player = self:GetPlayer()
    if player.GetCurrentOrder then
    
		local order = player:GetCurrentOrder()
        if order then
            
            local orderType = order:GetType()
            local orderTarget = Shared.GetEntity(order:GetParam())
            
            // attack order
            if (orderType == kTechId.Attack) then
               // if (not orderTarget:isa("PowerPoint") or not orderTarget:GetIsDestroyed()) then // dont attack destroyed power points
                    // check if current task is same
					//if (self.task and self.task:Type() == kBotTaskOrders.Attack and self.task:Target() == orderTarget) then return end
					return MakeBotTask(kBotTaskOrders.Attack, orderTarget:GetEngagementPoint(), orderTarget, self.AttackState)
               // end
            end
            
            // construct order
            if (orderType == kTechId.Construct) then
                //if (self.task and self.task:Type() == kBotTaskOrders.Construct and self.task:Target() == orderTarget) then return end
				return MakeBotTask(kBotTaskOrders.Construct, orderTarget:GetEngagementPoint(), orderTarget, self.ConstructState)
            end
            
            // move order
            local orderLocation = order:GetLocation()
            if orderLocation then
                //if (self.task and self.task:Type() == kBotTaskOrders.Move and self.task:Location() == orderLocation) then return end
				return MakeBotTask(kBotTaskOrders.Move, orderLocation, nil, self.MoveState)
            end
            
        end
    end
end

// check for ammo/medpack/weapon pickups and targets in sight
//  busy: if we're busy and just checking, ignore static targets or weapon pickups
function BotAI_Marine:GetInterruption(busy)
    
    // dont run every tick :)
    if (self.interruptionTime and self.interruptionTime > Shared.GetTime()) then
        return
    end
    self.interruptionTime = Shared.GetTime() + 0.2
    
    local player = self:GetPlayer()
    local target
    
    // check medpack
    if (player:GetHealthScalar() < .4) then
        target = self:FindPickupable("Medpack")
        if (target) then
            //if (self.task and self.task:Type() == kBotTaskOrders.Pickup and self.task:Target() == target) then return end
			return MakeBotTask(kBotTaskOrders.Pickup, nil, target, self.PickupState)
        end
    end
    
    // check ammo
    if (self:GetAmmoScalar() < .4) then
        target = self:FindPickupable("AmmoPack")
        if (target) then
            //if (self.task and self.task:Type() == kBotTaskOrders.Pickup and self.task:Target() == target) then return end
			return MakeBotTask(kBotTaskOrders.Pickup, nil, target, self.PickupState)
        end
    end
    
    // check enemy
    target = self:FindMovingTarget()
    if (target) then
        //if (self.task and self.task:Type() == kBotTaskOrders.Attack and self.task:Target() == target) then return end
		return MakeBotTask(kBotTaskOrders.Attack, nil, target, self.AttackState)
    end
    
    // below are only low priority interruptions
    if (busy) then
        return
    end
    
    // check weapons
        
		// look for welder
		if (not self:HasWeapon("Welder")) then
			target = self:FindPickupable("Welder") // hier in ich
			if (target) then
				//if (self.task and self.task:Type() == kBotTaskOrders.Pickup and self.task:Target() == target) then return end
				return MakeBotTask(kBotTaskOrders.Pickup, nil, target, self.PickupState)
			end
		end
		
		// look for shotgun
		if (not self:HasWeapon("Shotgun")) then
			target = self:FindPickupable("Shotgun")
			if (target) then
				//if (self.task and self.task:Type() == kBotTaskOrders.Pickup and self.task:Target() == target) then return end
				return MakeBotTask(kBotTaskOrders.Pickup, nil, target, self.PickupState)
			end
		end
    
    // check structure
    target = self:FindStaticTarget()
    if (target) then
        //if (self.task and self.task:Type() == kBotTaskOrders.Attack and self.task:Target() == target) then return end
		return MakeBotTask(kBotTaskOrders.Attack, nil, target, self.AttackState)
    end
    
    // check exosuit
    
    // check jetpack
    
    // TODO
    
end

//=== Debug ===================================================================

function BotAI_Marine:StateTrace(name)
	if (Shared.GetDevMode() and self.stateName ~= name) then
        Print("[M] %s -> %s", self:GetPlayer():GetName(), name)
        self.stateName = name
	end
end

//=== States (Jeffco) ==========================================================

function BotAI_Marine:GetStateForTask(task)
    if not (task and task:IsValid()) then
        return
    end
        
    if (task:Type() == kBotTaskOrders.Attack) then
        
        self.attackTargetId = task:TargetId()
        self.attackLocation = task:Location()
        
        return self.AttackState
        
    elseif (task:Type() == kBotTaskOrders.Construct) then
        
        self.constructTargetId = task:TargetId()
        self.constructLocation = task:Location()
        
        return self.ConstructState
        
    elseif (task:Type() == kBotTaskOrders.Move) then
        
        self.moveLocation = task:Location()
        self.moveRange = 0.75
        
        return self.MoveState
    
    /* TODO implement
    elseif (task:Type() == kBotTaskOrders.Pickup) then
        
        self.pickupTarget = task:Target()
        self.pickupLocation = task:Location()
        
        return self.PickupState
    */
    end
end

// check for orders or interruptions
function BotAI_Marine:CheckForStateChanges(isBusy)

    // check interruption
    local newTask = self:GetInterruption(isBusy)
    if (newTask and (not self.task or not self.task:Equals(newTask))) then
        self.task = newTask
        local newState = self:GetStateForTask(newTask)
        if (newState) then 
            return newState
        end
    end
    
    // check commander order
    newTask = self:GetCommanderOrder()
    if (newTask and (not self.task or not self.task:Equals(newTask))) then
        self.task = newTask
        local newState = self:GetStateForTask(newTask)
        if (newState) then 
            return newState
        end
    end
end

local function EndStateCheckTask(task, expectedMove, defaultState)
    if (task) then
        if (task:Type() == expectedMove) then
            task:SetDone(true)
            return defaultState
        else
            return task:State()
        end
    else
        return defaultState
    end
end

function BotAI_Marine:IdleState()
  
    self:StateTrace("idle")
    
    // remove completed tasks
    if (self.task and self.task:IsDone()) then
        self.task = nil
    end
    
    // check state changes
    local newState = self:CheckForStateChanges(false)
    if (newState) then return newState end
    
    // build/repair?
    local target = self:FindRepairTarget()
    if target then
        self.task = MakeBotTask(kBotTaskOrders.Construct, nil, target, self.ConstructState)
        local newState = self:GetStateForTask(self.task)
        if (newState) then 
            return newState
        end
    end
    
    // walk around
    if math.random() < .05 then
        return self.WalkAroundState
    end
    
    // look around randomly, extra state for this is silly
    if self.randomLookTarget == nil then
        local player = self:GetPlayer()
        self.randomLookTarget = player:GetEyePos()
        self.randomLookTarget.x = self.randomLookTarget.x + math.random(-50, 50)
        self.randomLookTarget.y = self.randomLookTarget.y + math.random(-10, 10)
        self.randomLookTarget.z = self.randomLookTarget.z + math.random(-50, 50)
    end
    local lookSpeed = self:DeltaTime() * 0.5
    self:GetBot():LookAtPoint(self.randomLookTarget, lookSpeed)
    
    // reset randomLookTarget when reached
    if self.lastYaw then
        if (math.abs(self.move.yaw - self.lastYaw) < lookSpeed and math.abs(self.move.pitch - self.lastPitch) < lookSpeed) then
            self.randomLookTarget = nil
        end
    end
    self.lastYaw = self.move.yaw
    self.lastPitch = self.move.pitch
    
    // stay
    return self.IdleState
end

function BotAI_Marine:PickupState()
    self:StateTrace("pickup")
    
    //self:GetBot():SayTeam("LoL I can't pick up shit") // DEBUG
    
    // done tee hee :v
    self.task:SetDone(true)
    
    return self.IdleState
end

function BotAI_Marine:WalkAroundState()

    self:StateTrace("walk around")
    
    local player = self:GetPlayer()
    
    // TODO find proper random targets :)
	
    local randomWalkTarget = player:GetEyePos()
    randomWalkTarget.x = randomWalkTarget.x + math.random(-12, 12)
    randomWalkTarget.z = randomWalkTarget.z + math.random(-12, 12)
    
    local trace = true
    
    // go to one of our comm stations
    if ( math.random() < .02 ) then
        randomWalkTarget = self:GetBot():GetCommandStation()
        trace = false
    elseif (math.random() < .05) then
        local ents = Shared.GetEntitiesWithClassname(ConditionalValue(math.random() < .5, "TechPoint", "ResourcePoint"))
        if ents:GetSize() > 0 then 
            local index = math.floor(math.random() * ents:GetSize())
            local target = ents:GetEntityAtIndex(index)
            randomWalkTarget = target:GetEngagementPoint()
            trace = false
        end
    end
    
    if (trace) then
        // check if can see point
        trace = Shared.TraceRay(player:GetEyePos(), randomWalkTarget, CollisionRep.LOS, PhysicsMask.AllButPCs, EntityFilterTwo(player, self:GetActiveWeapon()))
        
        if (trace.fraction < 0.25) then
            return self.WalkAroundState
        end
        
        randomWalkTarget = trace.endPoint
    end
    
    self.moveRange = 2.0
    
    self.task = MakeBotTask(kBotTaskOrders.Move, randomWalkTarget, nil, self.MoveState)
    local newState = self:GetStateForTask(self.task)
    if (newState) then return newState end
    
    return self.WalkAroundState
end

function BotAI_Marine:MoveState()

    self:StateTrace("move")
    
    // check urgent state changes
    local newState = self:CheckForStateChanges(true)
    if (newState) then 
        return newState 
    end
    
    // check if we're just moving to get to our last attack target
    if (self.task and self.task:Type() == kBotTaskOrders.Attack) then
        
        local player = self:GetPlayer()
        local activeWeapon = self:GetActiveWeapon()
        local attackTarget = self.task:Target()
        
        // has weapon and is in range
        if (activeWeapon and (player:GetEyePos() - attackTarget:GetModelOrigin()):GetLength() < self.moveRange) then
            // trace dem target
            local filter = EntityFilterTwo(player, activeWeapon)
            local trace = Shared.TraceRay(player:GetEyePos(), attackTarget:GetModelOrigin(), CollisionRep.LOS, PhysicsMask.AllButPCs, filter)
            
            
            // return to attackstate
            if trace.entity == attackTarget then
                return self.AttackState
            end
        end
    end
    
    // target reached?
    if self:GetBot():MoveToPoint(self.moveLocation, self.moveRange) or (self:GetStateTime() > kMoveTimeout) then
        //self:GetBot():SayTeam("Moved to location.") // DEBUG
        return EndStateCheckTask(self.task, kBotTaskOrders.Move, self.IdleState)
    end
    
	if (self.nextPathPointLast ~= self:GetBot():CurrentAIPathPoint()) then 
		self.nextPathPointLast = self:GetBot():CurrentAIPathPoint()
		self.nextPathPointEnterTime = self.currentTime
	end
	
	// try jumping when waypoint hasn't changed for 2 seconds, or randomly :]
	if (self.currentTime - self.nextPathPointEnterTime) > 2 or (math.random() < .01) then
		self:GetBot():Jump()
	end
    
    return self.MoveState
end

function BotAI_Marine:ConstructState()

    self:StateTrace("construct")
    
    // check urgent state changes
    local newState = self:CheckForStateChanges(true)
    if (newState) then return newState end
    
    // target construction done?
    local constructionTarget = Shared.GetEntity( self.constructTargetId )
    
    if (not constructionTarget or 
            ((not HasMixin(constructionTarget, "Construct") or constructionTarget:GetIsBuilt()) and 
                (not constructionTarget:isa("PowerPoint") or (constructionTarget:GetIsSocketed() and constructionTarget:GetHealthScalar() >= 1.0)))
    ) then
            
        //self:GetBot():SayTeam("Target constructed.") // DEBUG
        return EndStateCheckTask(self.task, kBotTaskOrders.Construct, self.IdleState)
    end
    
    // is target reachable?    
    local player = self:GetPlayer()
    local engagementPoint = constructionTarget:GetEngagementPoint()
    
    local allowedDistance = GetEngagementDistance(constructionTarget:GetTechId(), true)
   
    if constructionTarget:isa("RoboticsFactory") then
        allowedDistance = allowedDistance * 0.5
    elseif constructionTarget:isa("Observatory") then
        allowedDistance = allowedDistance * 1.6
    end
    
	local engagementDistance = (player:GetEyePos() - engagementPoint):GetLengthXZ()
    if  engagementDistance > (allowedDistance * 2) then
        
        self.moveLocation = engagementPoint
		self.moveRange = allowedDistance * 1.5
		
        return self.MoveState
    end
    
    // timeout?
    if self:GetStateTime() > 20 then
        self.moveLocation = engagementPoint
        return self.MoveState
    end
	
    // look at build object
    self:GetBot():LookAtPoint(engagementPoint, true)

    // construct!
    self:GetBot():Use()
  
	// move against!
	if  engagementDistance > allowedDistance * 0.75 then
	    self:GetBot():MoveForward()
	end
  
    return self.ConstructState
end

function BotAI_Marine:WeldState()
    
    self:StateTrace("weld")
    
    // TODO implement (task + state)
    return self.IdleState
    
    /**
    local canWeld = self:GetPlayer():GetWeapon(Welder.kMapName) and HasMixin(target, "Weldable") and ( (target:isa("Marine") and target:GetArmor() < target:GetMaxArmor()) or (not target:isa("Marine") and target:GetHealthScalar() < 0.9) )
    */
end

function BotAI_Marine:GetActiveWeapon()
    return self:GetPlayer():GetActiveWeapon()
end

function BotAI_Marine:GetActiveWeaponOutOfAmmo()
    local weapon = self:GetActiveWeapon()
    return weapon == nil or (weapon:isa("ClipWeapon") and weapon:GetAmmo() == 0)
end

function BotAI_Marine:GetPrimaryWeapon()
    local prim, sec = self:GetWeapons()
    return prim
end

function BotAI_Marine:GetSecondaryWeapon()
    local prim, sec = self:GetWeapons()
    return sec
end

function BotAI_Marine:GetPrimaryWeaponOutOfAmmo()
    local weapon = self:GetPrimaryWeapon()
    return weapon == nil or (weapon:isa("ClipWeapon") and weapon:GetAmmo() == 0)
end

function BotAI_Marine:GetSecondaryWeaponOutOfAmmo()
    local weapon = self:GetSecondaryWeapon()
    return weapon == nil or (weapon:isa("ClipWeapon") and weapon:GetAmmo() == 0)
end

function BotAI_Marine:IsActivePrimaryWeapon()
    return self:GetActiveWeapon() == self:GetPrimaryWeapon()
end

function BotAI_Marine:IsActiveSecondaryWeapon()
    return self:GetActiveWeapon() == self:GetSecondaryWeapon()
end

function BotAI_Marine:GetAttackDistance()

    local activeWeapon = self:GetActiveWeapon()
    
    if activeWeapon then
        return math.min(activeWeapon:GetRange(), 15)
    end
    
    return nil
end

function BotAI_Marine:AttackState()

    self:StateTrace("attack")

    // check urgent state changes
    local newState = self:CheckForStateChanges(true)
    if (newState) then 
        self.attackTimeout = nil
        return newState 
    end
    
    local attackTarget = Shared.GetEntity( self.attackTargetId )
    local player = self:GetPlayer()
  
    // check if went out of range or dead
    if ( not attackTarget or (self.attackTimeout and self.attackTimeout < Shared.GetTime()) or  (HasMixin(attackTarget, "Live") and not attackTarget:GetIsAlive()) or attackTarget:GetHealthScalar() <= 0) then
        //self:GetBot():SayTeam("Target killed.") // DEBUG
        self.attackTimeout = nil
        return EndStateCheckTask(self.task, kBotTaskOrders.Attack, self.IdleState)
    end
    
    // decide on preference
    if (self.prefersAxe == nil) then
        self.prefersAxe = math.random() < .5
    end
    
    // taken from Bot_Player.lua
    local activeWeapon = self:GetActiveWeapon()
    if activeWeapon then
        local outOfAmmo = (activeWeapon:isa("ClipWeapon") and (activeWeapon:GetAmmo() == 0))
    
        // Some bots switch to axe to take down structures
        if (GetReceivesStructuralDamage(attackTarget) and self.prefersAxe and not activeWeapon:isa("Axe")) or outOfAmmo then
        
            // TODO check for welder
            
            self:GetBot():Weapon3()
            return self.AttackState
            
        elseif attackTarget:isa("Player") and not self:IsActivePrimaryWeapon() and not self:GetPrimaryWeaponOutOfAmmo() then
        
            self:GetBot():Weapon1()
            return self.AttackState
            
        // If we're out of ammo in our primary weapon, switch to next weapon (pistol or axe)
        elseif outOfAmmo then
        
            self:GetBot():NextWeapon()
            return self.AttackState
            
        end
        
    end
    
    // TODO findWeaponState?
    if not activeWeapon then
        self.task:SetDone(true)
        return self.IdleState
    end
    
    // Attack target! TODO: We should have formal point where attack emanates from.
    
    // trace dem target
    local filter = EntityFilterTwo(player, activeWeapon)
    local trace = Shared.TraceRay(player:GetEyePos(), attackTarget:GetModelOrigin(), CollisionRep.LOS, PhysicsMask.AllButPCs, filter)
    
    local attackDist = self:GetAttackDistance()
        
    if trace.entity == attackTarget then
        
        local distToTarget = (trace.endPoint - player:GetEyePos()):GetLength()
        
        if (distToTarget < attackDist) then
        
            // look at attack target
            local targetPosition = attackTarget:GetModelOrigin()
            targetPosition.x = targetPosition.x + (math.random() - 0.5) * 0.8
            targetPosition.y = targetPosition.y + (math.random() - 0.5) * 0.8
            targetPosition.z = targetPosition.z + (math.random() - 0.5) * 0.8
            
            self:GetBot():LookAtPoint(targetPosition)
            self:GetBot():PrimaryAttack()
            
            self.attackTimeout = Shared.GetTime() + 5
            
        else
            
            self.moveLocation = trace.endPoint
            self.moveRange = attackDist * 0.95
            self.attackTimeout = nil
            
            return self.MoveState
            
        end
    end
    
    // wait.. either we spot it again or attackTimeout hits us
    return self.AttackState
    
end

function BotAI_Marine:DeathState()

    self:StateTrace("death")
    
    return self.DeathState
end

//=============================================================================
