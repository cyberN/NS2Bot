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
    
    // super does state machinin'
    return BotAI_Base.OnThink(self, deltaTime)
end

// chat
function BotAI_Marine:OnChat(message, playerName, teamOnly)
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
			//Print("Player found a medpack to pickup")
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
			//Print("Player found an ammopack to pickup")
		else
			if math.random() < .5 then
				// TODO: consider armory distance
				player:GetTeam():TriggerAlert(kTechId.MarineAlertNeedAmmo, player)
			end
		end
    end
    
    // ask for orders 
    if not self.lastOrderTime or self.currentTime - self.lastOrderTime > 360 then
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
    self.target = orderTarget
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
    return self.location or (self.target.GetOrigin and self.target:GetOrigin()) or self.target:GetEngagementPoint()
end

function BotTask:Target()
    return self.target
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
                if (not orderTarget:isa("PowerPoint") or not orderTarget:GetIsDestroyed()) then // dont attack destroyed power points
                    return MakeBotTask(kBotTaskOrders.Attack, orderTarget:GetEngagementPoint(), orderTarget, self.AttackState)
                end
            end
            
            // construct order
            if (orderType == kTechId.Construct) then
                return MakeBotTask(kBotTaskOrders.Construct, orderTarget:GetEngagementPoint(), orderTarget, self.ConstructState)
            end
            
            // move order
            local orderLocation = order:GetLocation()
            if orderLocation then
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
            return MakeBotTask(kBotTaskOrders.Pickup, nil, target, self.PickupState)
        end
    end
    
    // check ammo
    if (self:GetAmmoScalar() < .4) then
        target = self:FindPickupable("AmmoPack")
        if (target) then
            return MakeBotTask(kBotTaskOrders.Pickup, nil, target, self.PickupState)
        end
    end
    
    // check enemy
    target = self:FindMovingTarget()
    if (target) then
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
				return MakeBotTask(kBotTaskOrders.Pickup, nil, target, self.PickupState)
			end
		end
		
		// look for shotgun
		if (not self:HasWeapon("Shotgun")) then
			target = self:FindPickupable("Shotgun")
			if (target) then
				return MakeBotTask(kBotTaskOrders.Pickup, nil, target, self.PickupState)
			end
		end
    
    // check structure
    target = self:FindStaticTarget()
    if (target) then
        return MakeBotTask(kBotTaskOrders.Attack, nil, target, self.AttackState)
    end
    
    // check exosuit
    
    // check jetpack
    
    // TODO
    
end

//=== Debug ===================================================================

function BotAI_Marine:StateTrace(name)
	if (Shared.GetDevMode() and self.stateName ~= name) then
        Print("[M] %s", name)
        self.stateName = name
	end
end

//=== States (Jeffco) ==========================================================

function BotAI_Marine:GetStateForTask(task)
    if not (task and task:IsValid()) then
        return
    end
        
    if (task:Type() == kBotTaskOrders.Attack) then
        
        self.attackTarget = task:Target()
        self.attackLocation = task:Location()
        
        return self.AttackState
        
    elseif (task:Type() == kBotTaskOrders.Construct) then
        
        self.constructTarget = task:Target()
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
    self.task = self:GetInterruption(isBusy)
    if (self.task) then
        local newState = self:GetStateForTask(self.task)
        if (newState) then 
            return newState
        end
    end
    
    // check commander order
    self.task = self:GetCommanderOrder()
    if (self.task) then
        local newState = self:GetStateForTask(self.task)
        if (newState) then 
            return newState
        end
    end
end

local function EndStateCheckTask(task, expectedMove, defaultState)
    if (task) then
        if (task:Task() == expectedMove) then
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
        if (newState) then return newState end
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
        self.randomLookTarget.y = self.randomLookTarget.x + math.random(-10, 10)
        self.randomLookTarget.z = self.randomLookTarget.z + math.random(-50, 50)
    end
    local lookSpeed = self:DeltaTime() * 2
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
    
    self:GetBot():SayTeam("LoL I can't pick up shit") // DEBUG
    
    // done tee hee :v
    self.task:SetDone(true)
    
    return self.IdleState
end

function BotAI_Marine:WalkAroundState()

    self:StateTrace("walk around")
    
    local player = self:GetPlayer()
    
    // TODO find proper random targets :)
	
    local randomWalkTarget = player:GetEyePos()
    randomWalkTarget.x = randomWalkTarget.x + math.random(-8, 8)
    randomWalkTarget.z = randomWalkTarget.z + math.random(-8, 8)
    
    self.moveRange = 1.0
    
    self.task = MakeBotTask(kBotTaskOrders.Move, randomWalkTarget, nil, self.MoveState)
    local newState = self:GetStateForTask(self.task)
    if (newState) then return newState end
    
    return self.IdleState
end

function BotAI_Marine:MoveState()

    self:StateTrace("move")
    
    // check urgent state changes
    local newState = self:CheckForStateChanges(true)
    if (newState) then return newState end
    
    // target reached?
    if self:GetBot():MoveToPoint(self.moveLocation, self.moveRange) or (self:GetStateTime() > kMoveTimeout) then
        self:GetBot():SayTeam("Moved to location.") // DEBUG
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
    local constructionTarget = self.constructTarget
    if (HasMixin(constructionTarget, "Construct") and constructionTarget:GetIsBuilt()) then
        self:GetBot():SayTeam("Target constructed.") // DEBUG
        return EndStateCheckTask(self.task, kBotTaskOrders.Construct, self.IdleState)
    end
    
    // is target reachable?    
    local player = self:GetPlayer()
    local engagementPoint = self.constructTarget:GetEngagementPoint()
    
    local allowedDistance = GetEngagementDistance(self.constructTarget:GetTechId(), true)
   
    if self.constructTarget:isa("RoboticsFactory") then
        allowedDistance = allowedDistance * 0.5
    elseif self.constructTarget:isa("Observatory") then
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

function BotAI_Marine:AttackState()

    self:StateTrace("attack")

    // check urgent state changes
    local newState = self:CheckForStateChanges(true)
    if (newState) then return newState end
    
    local attackTarget = self.attackTarget
  
    // check if dead
    if ((HasMixin(attackTarget, "Live") and not attackTarget:GetIsAlive()) or attackTarget:GetHealthScalar() <= 0) then
        self:GetBot():SayTeam("Target killed.") // DEBUG
        return EndStateCheckTask(self.task, kBotTaskOrders.Attack, self.IdleState)
    end
  
    // choose weapon
    local player = self:GetPlayer()
    local activeWeapon = player:GetActiveWeapon()
    local outOfAmmo = activeWeapon == nil or (activeWeapon:isa("ClipWeapon") and activeWeapon:GetAmmo() == 0)
    if attackTarget:isa("Structure") and (activeWeapon == nil or not activeWeapon:isa("Axe")) then
        self:GetBot():Weapon3()
    elseif attackTarget:isa("Player") then
        local primaryWeapon, secondaryWeapon = self:GetWeapons()
        if primaryWeapon and (not primaryWeapon:isa("ClipWeapon") or primaryWeapon:GetAmmo() > 0) then
            if activeWeapon ~= primaryWeapon then
                self:GetBot():Weapon1()
            end
        elseif secondaryWeapon and (not secondaryWeapon:isa("ClipWeapon") or secondaryWeapon:GetAmmo() > 0) then
            if activeWeapon ~= secondaryWeapon then
                self:GetBot():Weapon2()
            end
        elseif outOfAmmo then
            self:GetBot():NextWeapon()
        end
    elseif outOfAmmo then
        self:GetBot():NextWeapon()
    end        
    
    // move to axe a target?
    local melee = false
    if activeWeapon and activeWeapon:isa("Axe") then
        melee = true
        local engagementPoint = attackTarget:GetEngagementPoint()
        local allowedDistance = 3
        if attackTarget:isa("Hive") then
            allowedDistance = 10
            engagementPoint = attackTarget:GetOrigin()
        end        
        if (player:GetEyePos() - engagementPoint):GetLengthSquared() > allowedDistance then
        
            self.moveLocation = engagementPoint
			self.moveRange = 1.0
			
            return self.MoveState
            
        elseif not attackTarget:isa("Hive") then
            self:GetBot():Crouch()
        end
    end
    
    // timeout?
    if self:GetStateTime() > 20 then
    
        self.moveLocation = attackTarget:GetEngagementPoint()
		self.moveRange = 1.0
		
        return self.MoveState
        
    end
    
    // look at attack target
    local targetPosition = attackTarget:GetOrigin()
    if activeWeapon and activeWeapon:isa("ClipWeapon") then
        targetPosition.x = targetPosition.x + (math.random() - 0.5) * 1.1
        targetPosition.y = targetPosition.y + (math.random() - 0.5) * 1.1
        targetPosition.z = targetPosition.z + (math.random() - 0.5) * 1.1
    end
    self:GetBot():LookAtPoint(targetPosition, melee)

    // attack!
    if math.random() < .6 then
        self:GetBot():PrimaryAttack()
    end
    
    return self.AttackState
end

//=============================================================================
