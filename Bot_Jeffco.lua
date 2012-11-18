//=============================================================================
//
// lua\Bot_Jeffco.lua
//
// A simple bot implementation for Natural Selection 2
//
// Copyright 2011 Colin Graf (colin.graf@sovereign-labs.com)
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

Script.Load("lua/BotAIPathMixin.lua")

class 'BotJeffco' (Bot)

BotJeffco.kBotNames = {
    "Whitesides (bot)", "Baptist (bot)", "Fullbright (bot)", "Penhollow (bot)", "Harvill (bot)", "Bossert (bot)", "Claro (bot)",
    "Sanders (bot)", "Quiros (bot)", "Wakeland (bot)", "Nims (bot)", "Heroux (bot)", "Palafox (bot)", "Madruga (bot)", "Blane (bot)",
    "Welles (bot)", "Vencill (bot)", "Schoenberg (bot)", "Toll (bot)"
}
BotJeffco.kOrder = enum({ "Attack", "Construct", "Move", "Look", "None" })
BotJeffco.kDebugMode = false
BotJeffco.kRange = 30
BotJeffco.kRepairRange = 10
BotJeffco.kMaxPitch = 89
BotJeffco.kMinPitch = -89

local kTargetReachedRange = 0.5
local kNextPathPointRange = 1.75
local kMoveTimeout = 20

function BotJeffco:Initialize()

    InitMixin(self, BotAIPathMixin)

end

function BotJeffco:Jump()
	self.move.commands = bit.bor(self.move.commands, Move.Jump)
end

function BotJeffco:FindPickupable(className)
	local player = self:GetPlayer()
	local playerPos = player:GetOrigin()
    local nearbyItems = GetEntitiesWithMixinWithinRangeAreVisible("Pickupable", player:GetEyePos(), 10, true)
    local closestPickup = nil
    local closestDistance = Math.infinity
    for i, nearby in ipairs(nearbyItems) do
    
        if nearby:GetIsValidRecipient(player) and not ( className ~= nil and not nearby:isa(className) ) then
        
            local nearbyDistance = (nearby:GetOrigin() - playerPos):GetLengthSquared()
            if nearbyDistance < closestDistance then
            
                closestPickup = nearby
                closestDistance = nearbyDistance
            
            end
        end
    end
    
    return closestPickup
end

function BotJeffco:GetInfantryPortal()

    local ents = Shared.GetEntitiesWithClassname("InfantryPortal")    
    if ents:GetSize() > 0 then 
        return ents:GetEntityAtIndex(0)
    end
    
end

function BotJeffco:GetHasCommander()

    local ents = Shared.GetEntitiesWithClassname("MarineCommander")
    local count = ents:GetSize()
    local player = self:GetPlayer()
    local teamNumber = player:GetTeamNumber()
    
    for i = 0, count - 1 do
        local commander = ents:GetEntityAtIndex(i)
        if commander ~= nil and commander:GetTeamNumber() == teamNumber then
            return true
        end
    end
    
    return false
end

function BotJeffco:GetCommandStation()

    local ents = Shared.GetEntitiesWithClassname("CommandStation")    
    local count = ents:GetSize()
    local player = self:GetPlayer()
    local eyePos = player:GetEyePos()
    local closestCommandStation, closestDistance
    
    for i = 0, count - 1 do
        local commandStation = ents:GetEntityAtIndex(i)
        local distance = (commandStation:GetOrigin() - eyePos):GetLengthSquared()
        if closestCommandStation == nil or distance < closestDistance then
            closestCommandStation, closestDistance = commandStation, distance
        end
    end
    
    return closestCommandStation
end

function BotJeffco:GetMoblieAttackTarget()

    local player = self:GetPlayer()

    if not player.mobileTargetSelector then
        if player:isa("Marine") then
            player.mobileTargetSelector = TargetSelector():Init(
                player,
                BotJeffco.kRange, 
                true,
                { kMarineMobileTargets },
                { PitchTargetFilter(player,  -BotJeffco.kMaxPitch, BotJeffco.kMaxPitch), CloakTargetFilter() })
        end
        if player:isa("Alien") then
            player.mobileTargetSelector = TargetSelector():Init(
                player,
                BotJeffco.kRange, 
                true,
                { kAlienMobileTargets },
                { PitchTargetFilter(player,  -BotJeffco.kMaxPitch, BotJeffco.kMaxPitch) })
        end
    end
    
    if player.mobileTargetSelector then
        player.mobileTargetSelector:AttackerMoved()
        return player.mobileTargetSelector:AcquireTarget()
    end
end

function BotJeffco:GetStaticAttackTarget()

    local player = self:GetPlayer()

    if not player.staticTargetSelector then
        if player:isa("Marine") then
            player.staticTargetSelector = TargetSelector():Init(
                player,
                BotJeffco.kRange, 
                true,
                { kMarineStaticTargets },
                { CloakTargetFilter() })
        end
        if player:isa("Alien") then
            player.staticTargetSelector = TargetSelector():Init(
                player,
                BotJeffco.kRange, 
                true,
                { kAlienStaticTargets },
                {  })
        end
    end
    
    if player.staticTargetSelector then
        player.staticTargetSelector:AttackerMoved()
        return player.staticTargetSelector:AcquireTarget()
    end
end

function BotJeffco:GetRepairTarget()

    local player = self:GetPlayer()
    local eyePos = player:GetEyePos()
    local repairTarget, closestDistance
    local allowedDistance = BotJeffco.kRepairRange * BotJeffco.kRepairRange
    
    local ents = Shared.GetEntitiesWithClassname("Marine")    
    local count = ents:GetSize()
    for i = 0, count - 1 do
		local marine = ents:GetEntityAtIndex(i)
		if (marine ~= nil) then
			local distance = (marine:GetOrigin() - eyePos):GetLengthSquared()
			if distance < allowedDistance and marine:GetIsAlive() and marine:GetArmor() < marine:GetMaxArmor() and (repairTarget == nil or distance < closestDistance) then
				repairTarget, closestDistance = marine, distance
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

    return repairTarget
end

function BotJeffco:GetWeapons()

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

function BotJeffco:GetAmmoScalar()

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

function BotJeffco:LookAtPoint(toPoint, direct)

    local player = self:GetPlayer()

    // compute direction to target
    local diff = toPoint - player:GetEyePos()
    local direction = GetNormalizedVector(diff)
    
    // look at target
    if direct then
        self.move.yaw = GetYawFromVector(direction) - player:GetBaseViewAngles().yaw
    else
        local turnSpeed = ConditionalValue(player:isa("Alien"), .8, .4)
        self.move.yaw = SlerpRadians(self.move.yaw, GetYawFromVector(direction) - player:GetBaseViewAngles().yaw, turnSpeed)
    end
    self.move.pitch = GetPitchFromVector(direction) - player:GetBaseViewAngles().pitch
    //self.move.pitch = SlerpRadians(self.move.pitch, GetPitchFromVector(direction) - player:GetBaseViewAngles().pitch, .4)
    
end

function DebugDrawPoint(p, t, r, g, b, a)
    if not Shared.GetDevMode() then return end
    DebugLine(p - Vector.xAxis * .3, p + Vector.xAxis * .3, t, r, g, b, a)
    DebugLine(p - Vector.yAxis * .3, p + Vector.yAxis * .3, t, r, g, b, a)
    DebugLine(p - Vector.zAxis * .3, p + Vector.zAxis * .3, t, r, g, b, a)
end

// return true if end reached
function BotJeffco:MoveToPoint(toPoint, distablePathing)

    local player = self:GetPlayer()

    // use pathfinder
    if distablePathing == nil then
        if self:CheckTarget(player:GetOrigin(), toPoint) then
            
            if self.nextPathPoint == nil or (player:GetOrigin() - self.nextPathPoint):GetLengthXZ() < kTargetReachedRange then
            
                // look for next path point
				// if we can't find it, reset path to calculate new destination
                if not self:FindNextAIPathPoint(player:GetOrigin(), kNextPathPointRange) then
                    //Print("MoveToPoint cant find next point")
                    self:ResetAIPath()
                    return true
                end

                self.distance = (player:GetOrigin() - toPoint):GetLengthXZ()
				
                // if target is reached (by distance) pick another target in next think cycle
                if (self.distance < kTargetReachedRange) then
                    //Print("MoveToPoint distance small or RemainingAIPathPoint < 1")
                    self:ResetAIPath()
                    return true
				end
				
				// set next path point to current point, otherwise set to actual destination
				if (self:RemainingAIPathPoint() > 0) then
					self.nextPathPoint = self:CurrentAIPathPoint()
				else
					self.nextPathPoint = toPoint
				end
				
                DebugDrawPoint(self.nextPathPoint, 2, 1, 0, 1, 1)
            end
            
            // look at target
            self:LookAtPoint(self.nextPathPoint)
            
            // walk forwards
            self.move.move.z = 1
            return false
        else
            self.nextPathPoint = nil
            return true
        end
    else
        self.nextPathPoint = nil
        
        // look at target
        self:LookAtPoint(toPoint)
        
        // walk forwards
        self.move.move.z = 1
        
        return false
    end
    
end

//function BotJeffco:PickupState()
//	//TODO implement
//end

function BotJeffco:TriggerAlerts()

    local player = self:GetPlayer()
    if not player:isa("Marine") then
        return
    end
    
    if self.lastAlertTime and self.currentTime - self.lastAlertTime < 15 then
        return
    end
    
    if not self:GetHasCommander() then
        return
    end
    
    // ask for for medpack
    if player:GetHealthScalar() < .4 then
	
        self.lastAlertTime = self.currentTime
		
		// TODO check for nearby medpacks
		local pickupable = self:FindPickupable("MedPack")
		if pickupable ~= nil then
			Print("Player found a medpack to pickup")
		else
			if math.random() < .5 then
				// TODO: consider armory distance
				//player:PlaySound(marineRequestSayingsSounds[2])
				player:GetTeam():TriggerAlert(kTechId.MarineAlertNeedMedpack, player)
			end
		end
    end
    
    // ask for ammo pack
    if self:GetAmmoScalar() < .5 then
        self.lastAlertTime = self.currentTime
		
		local pickupable = self:FindPickupable("AmmoPack")
		if pickupable ~= nil then
			Print("Player found an ammopack to pickup")
		else
			if math.random() < .5 then
				// TODO: consider armory distance
				//player:PlaySound(marineRequestSayingsSounds[3])
				player:GetTeam():TriggerAlert(kTechId.MarineAlertNeedAmmo, player)
			end
		end
    end
    
    // ask for orders
    if not self.lastOrderTime or self.currentTime - self.lastOrderTime > 360 then
        self.lastAlertTime = self.currentTime
        if math.random() < .5 then
            //player:PlaySound(marineRequestSayingsSounds[4])
            player:GetTeam():TriggerAlert(kTechId.MarineAlertNeedOrder, player)
        end
    end

end

function BotJeffco:UpdateOrder()

    local player = self:GetPlayer()
	
    self.orderType = BotJeffco.kOrder.None

    // #1 attack opponent players / mobile objects
    local target = self:GetMoblieAttackTarget()
    if target then
        //player:GiveOrder(kTechId.Attack, target:GetId(), target:GetEngagementPoint(), nil, true, true)
        self.orderType = BotJeffco.kOrder.Attack
        self.orderTarget = target
        self.lastOrderTime = self.currentTime
        return
    end

    // #2 follow commander orders
    if player.GetCurrentOrder then
		local order = player:GetCurrentOrder()
        if order then
            local orderType = order:GetType()
            local orderTarget = Shared.GetEntity(order:GetParam())
            if orderTarget then
                if orderType == kTechId.Attack then
                    if not orderTarget:isa("PowerPoint") or not orderTarget:GetIsDestroyed() then
                        self.orderType = BotJeffco.kOrder.Attack
                        self.orderLocation = orderTarget:GetEngagementPoint()
                        self.orderTarget = orderTarget
                        self.lastOrderTime = self.currentTime
                        return
                    end
                end
                if orderType == kTechId.Construct then
                    self.orderType = BotJeffco.kOrder.Construct
                    self.orderTarget = orderTarget
                    self.lastOrderTime = self.currentTime
                    return
                end
            end
            local orderLocation = order:GetLocation()
            if orderLocation then
                if orderLocation ~= self.commanderOrderLocation then
                    self.orderType = BotJeffco.kOrder.Move
                    self.orderLocation = orderLocation
                    self.lastOrderTime = self.currentTime
                    self.commanderOrderLocation = orderLocation
                    self.commanderOrderLocationReached = false
                    return
                end
            end
            if self.commanderOrderLocation and not self.commanderOrderLocationReached then
                if (player:GetEyePos() - self.commanderOrderLocation):GetLengthSquared() < 5 then
                    self.commanderOrderLocationReached = true
                else
                    self.orderType = BotJeffco.kOrder.Move
                    self.orderLocation = self.commanderOrderLocation
                    self.lastOrderTime = self.currentTime
                    return
                end
            end
        end    
    end
    
    // #3 repair objects near by?
    target = self:GetRepairTarget()
    if target then
        self.orderType = BotJeffco.kOrder.Construct
        self.orderTarget = target
        self.lastOrderTime = self.currentTime
        return
    end
    
    // #4 attack stationary objects
    target = self:GetStaticAttackTarget()
    if target then
      //player:GiveOrder(kTechId.Attack, target:GetId(), target:GetEngagementPoint(), nil, true, true)
      self.orderType = BotJeffco.kOrder.Attack
      self.orderTarget = target
      self.lastOrderTime = self.currentTime
      return
    end

end

function BotJeffco:StateTrace(name)

  if BotJeffco.kDebugMode and self.stateName ~= name then
    Print("%s %s", self:GetPlayer():GetClassName(), name)
    self.stateName = name
  end

end

//=============================================================================

function BotJeffco:OnMove()
    return self.move
end

function BotJeffco:OnThink(deltaTime)

    //
    self:UpdateOrder()
    self:TriggerAlerts()
    
    // set default move
    local player = self:GetPlayer()
    local move = Move()
    move.yaw = player:GetAngles().yaw - player:GetBaseViewAngles().yaw // keep the current yaw/pitch
    move.pitch = player:GetAngles().pitch - player:GetBaseViewAngles().pitch
    self.move = move
    
    // use a state machine to generate a move
    local currentTime = Shared.GetTime()
    //self.state = nil
    if self.state == nil then
      self.state = self.InitialState
      self.stateEnterTime = currentTime
    end
    self.stateTime = currentTime - self.stateEnterTime
    self.currentTime = currentTime
    local newState = self.state(self)
    if newState ~= self.state then
      self.stateEnterTime = currentTime
      self.state = newState
    end
    
    return true
    
end

//=============================================================================
// States

function BotJeffco:InitialState()

    self:StateTrace("initial")

    // wait a few seconds, set name and start idling
    if self.stateTime > 6 then
  
        local player = self:GetPlayer()
        local name = player:GetName()
        if name and string.find(string.lower(name), string.lower(kDefaultPlayerName)) then
    
            name = BotJeffco.kBotNames[math.random(1, table.maxn(BotJeffco.kBotNames))]
            OnCommandSetName(self.client, name)

        end
        
        return self.IdleState
   
    end
  
    return self.InitialState
end

function BotJeffco:JoinTeamState()

    self:StateTrace("join team")

    local player = self:GetPlayer()
    if player:GetTeamNumber() ~= 0 then
        return self.IdleState
    end

    local rules = GetGamerules()
    local joinTeam = ConditionalValue(math.random() < .5, 1, 2)
    if rules:GetCanJoinTeamNumber(joinTeam) or Shared.GetCheatsEnabled() then
        rules:JoinTeam(player, joinTeam)
    end

    self.move.move.z = 1

    return self.JoinTeamState
end

function BotJeffco:IdleState()
  
    self:StateTrace("idle")
     
     // in rr?
     local player = self:GetPlayer()
     if player:GetTeamNumber() == 0 then
        return self.JoinTeamState
     end
     
    // respawing?
    if player:isa("AlienSpectator") then
       return self.HatchState
    end
    
    // commanding?
    if player:isa("MarineCommander") then
        return self.CommandState
    end
        
    // attack order?
    if self.orderType == BotJeffco.kOrder.Attack then
        return self.AttackState
    end
    
    // construct order?
    if self.orderType == BotJeffco.kOrder.Construct then
        return self.ConstructState
    end

    // move order?
    if self.orderType == BotJeffco.kOrder.Move then
        return self.MoveState
    end
    
    // build ip?
    if player:isa("Marine") and self:GetInfantryPortal() == nil and not self:GetHasCommander() and self:GetCommandStation() then
        return self.EnterCommandStationState
    end
    
    // walk around
    if math.random() < .02 then
        return self.RandomWalkState
    end

    // look around
    if math.random() < .1 then
        return self.RandomLookState
    end
    
    // stay
    return self.IdleState
end

function BotJeffco:EnterCommandStationState()

    self:StateTrace("enter command station state")
    
    local player = self:GetPlayer()
    if player:isa("MarineCommander") then
        return self.CommandState
    end
    
    local commandStation = self:GetCommandStation()
    if commandStation == nil then
        return self.IdleState
    end
        
    local comLocation = commandStation:GetOrigin()
    if (player:GetEyePos() - comLocation):GetLengthSquared() > 18 or self.stateTime > 3 then
        if math.random() < .5 then
            comLocation.x = comLocation.x + ConditionalValue(math.random() < .5, -3, 3)
        else
            comLocation.z = comLocation.z + ConditionalValue(math.random() < .5, -3, 3)
        end
        self.orderLocation = comLocation
        self.move.commands = bit.bor(self.move.commands, Move.Jump)
        return self.MoveState
    end
    
    self:LookAtPoint(commandStation:GetOrigin(), true)
    self.move.commands = bit.bor(self.move.commands, Move.Use)
    
    comLocation.y = comLocation.y + 1    
    self:MoveToPoint(comLocation, true)
    
    if math.random() < .2 and (player:GetEyePos() - comLocation):GetLengthSquared() > 3 then
        self.move.commands = bit.bor(self.move.commands, Move.Jump)
    end
    
    return self.EnterCommandStationState
end

function BotJeffco:CommandState()

    self:StateTrace("command")

    local player = self:GetPlayer()
    if not player:isa("MarineCommander") then
        return self.IdleState
    end

    if self:GetInfantryPortal() then
        return self.LeaveCommandStationState
    end

    // spawn infantry portal
    local commandStation = self:GetCommandStation()
    if commandStation == nil then
        return self.IdleState
    end
    local position = commandStation:GetOrigin()
    position.x = position.x + ConditionalValue(math.random() < .5, -2.8, 2.8)
    position.z = position.z + ConditionalValue(math.random() < .5, -2.8, 2.8)
    CreateEntity("infantryportal", position, player:GetTeamNumber())

    return self.CommandState;
end

function BotJeffco:LeaveCommandStationState()

    self:StateTrace("leave command station state")
    
    local player = self:GetPlayer()
    if not player:isa("MarineCommander") then
        return self.IdleState
    end
    
    //
    player:Logout()
    
    return self.LeaveCommandStationState
end

function BotJeffco:RandomLookState()

    self:StateTrace("random look")
    
    // attack?
    if self.orderType ~= BotJeffco.kOrder.None then
        return self.IdleState
    end

    if self.randomLookTarget == nil then
        local player = self:GetPlayer()
        self.randomLookTarget = player:GetEyePos()
        self.randomLookTarget.x = self.randomLookTarget.x + math.random(-50, 50)
        self.randomLookTarget.z = self.randomLookTarget.z + math.random(-50, 50)
    end

    self:LookAtPoint(self.randomLookTarget)
    
    if self.lastYaw then
        if (math.abs(self.move.yaw - self.lastYaw) < .05 and math.abs(self.move.pitch - self.lastPitch) < .05) or self.stateTime > 10 then
            self.randomLookTarget = nil
            return self.IdleState
        end
    end    
    self.lastYaw = self.move.yaw
    self.lastPitch = self.move.pitch

    return self.RandomLookState
end

function BotJeffco:RandomWalkState()

    self:StateTrace("random walk")
    
    // attack?
    if self.orderType ~= BotJeffco.kOrder.None then
        return self.AttackState
    end

    local player = self:GetPlayer()
    if self.randomWalkTarget == nil then

		// TODO find proper random targets :)
	
        self.randomWalkTarget = player:GetEyePos()
        self.randomWalkTarget.x = self.randomWalkTarget.x + math.random(-4, 4)
        self.randomWalkTarget.z = self.randomWalkTarget.z + math.random(-4, 4)

        if player:isa("Alien") then
            local ents = Shared.GetEntitiesWithClassname(ConditionalValue(math.random() < .5, "TechPoint", "ResourcePoint"))
            if ents:GetSize() > 0 then 
                local index = math.floor(math.random() * ents:GetSize())
                local target = ents:GetEntityAtIndex(index)
                self.randomWalkTarget = target:GetEngagementPoint()
            end
        else
            if math.random() < .3 and self.commanderOrderLocation then
                self.randomWalkTarget = self.commanderOrderLocation
            end
        end

    end

	// TODO ugly to have more or less the same code as in MoveState here
    if self:MoveToPoint(self.randomWalkTarget) or self.stateTime > kMoveTimeout then
        self.randomWalkTarget = nil
        return self.IdleState
    end
  
    return self.RandomWalkState
end

function BotJeffco:HatchState()

    self:StateTrace("hatch")

    local player = self:GetPlayer()
    if not player:isa("AlienSpectator") then
       return self.IdleState
    end

    self.move.commands = Move.PrimaryAttack
    
    return self.HatchState
end

function BotJeffco:MoveState()

    self:StateTrace("move")
  
    // target reached?
    if self:MoveToPoint(self.orderLocation) or self.stateTime > kMoveTimeout then
        return self.IdleState
    end
    
	if self.nextPathPointLast ~= self.nextPathPoint then 
		self.nextPathPointLast = self.nextPathPoint
		self.nextPathPointEnterTime = self.currentTime
	end
	
	// try jumping when waypoint hasn't changed for 2 seconds, or randomly :]
	if (self.currentTime - self.nextPathPointEnterTime) > 2 or math.random() < ConditionalValue(self:GetPlayer():isa("Alien"), .1, .01) then
		self:Jump()
	end

    return self.MoveState
end

function BotJeffco:ConstructState()

    self:StateTrace("construct")
    
    // construct?
    if self.orderType ~= BotJeffco.kOrder.Construct then
        return self.IdleState
    end

    // is target reachable?    
    local player = self:GetPlayer()
    local engagementPoint = self.orderTarget:GetEngagementPoint()
    local allowedDistance = 5
    if self.orderTarget:isa("RoboticsFactory") then
        allowedDistance = 7
    end
    if (player:GetEyePos() - engagementPoint):GetLengthSquared() > allowedDistance then
        self.orderLocation = engagementPoint
        return self.MoveState
    end
  
    // timeout?
    if self.stateTime > 20 then
        self.orderLocation = engagementPoint
        return self.MoveState
    end
  
    // look at build object
    self:LookAtPoint(engagementPoint, true)

    // construct!
    self.move.commands = bit.bor(self.move.commands, Move.Use)
  
    return self.ConstructState
end

function BotJeffco:AttackState()

    self:StateTrace("attack")

    // attack?
    if self.orderType ~= BotJeffco.kOrder.Attack then
        return self.IdleState
    end
    local attackTarget = self.orderTarget
  
    // choose weapon
    local player = self:GetPlayer()
    local activeWeapon = player:GetActiveWeapon()
    local outOfAmmo = activeWeapon == nil or (activeWeapon:isa("ClipWeapon") and activeWeapon:GetAmmo() == 0)
    if attackTarget:isa("Structure") and (activeWeapon == nil or not activeWeapon:isa("Axe")) then
        self.move.commands = bit.bor(self.move.commands, Move.Weapon3)
    elseif attackTarget:isa("Player") then
        local primaryWeapon, secondaryWeapon = self:GetWeapons()
        if primaryWeapon and (not primaryWeapon:isa("ClipWeapon") or primaryWeapon:GetAmmo() > 0) then
            if activeWeapon ~= primaryWeapon then
                self.move.commands = bit.bor(self.move.commands, Move.Weapon1)
            end
        elseif secondaryWeapon and (not secondaryWeapon:isa("ClipWeapon") or secondaryWeapon:GetAmmo() > 0) then
            if activeWeapon ~= secondaryWeapon then
                self.move.commands = bit.bor(self.move.commands, Move.Weapon2)
            end
        elseif outOfAmmo then
            self.move.commands = bit.bor(self.move.commands, Move.NextWeapon)
        end
    elseif outOfAmmo then
        self.move.commands = bit.bor(self.move.commands, Move.NextWeapon)
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
            self.orderLocation = engagementPoint
            return self.MoveState
        elseif not attackTarget:isa("Hive") then
            self.move.commands = bit.bor(self.move.commands, Move.Crouch)
        end
    end
    
    // as alien move to target
    if player:isa("Alien") then
        melee = true
        local engagementPoint = attackTarget:GetEngagementPoint()
        if (player:GetEyePos() - engagementPoint):GetLengthSquared() > 5 then
            self.orderLocation = engagementPoint
            return self.MoveState
        end
    end
    
    // timeout?
    if self.stateTime > 20 then
        self.orderLocation = attackTarget:GetEngagementPoint()
        return self.MoveState
    end

    // look at attack target
    local targetPosition = attackTarget:GetOrigin()
    if activeWeapon and activeWeapon:isa("ClipWeapon") then
        targetPosition.x = targetPosition.x + (math.random() - 0.5) * 1.1
        targetPosition.y = targetPosition.y + (math.random() - 0.5) * 1.1
        targetPosition.z = targetPosition.z + (math.random() - 0.5) * 1.1
    end
    self:LookAtPoint(targetPosition, melee)

    // attack!
    if math.random() < .5 then
        self.move.commands = bit.bor(self.move.commands, Move.PrimaryAttack)
    end

    return self.AttackState
end

function BotJeffco:RecoverState()

    self:StateTrace("recover")
    
    if self.stateTime > 2 or self.orderType == BotJeffco.kOrder.Attack then
        return self.IdleState
    end

    return self.RecoverState
end
