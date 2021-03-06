//=============================================================================
//
// lua\ai\BotAI_Alien.lua
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

class 'BotAI_Alien' (BotAI_Base)

local kOrder = enum({ "Attack", "Construct", "Move", "AttackMove", "Look", "None" })
local kMoveTimeout = 20

// is the player ok with this ai type?
function BotAI_Alien.IsPlayerApplicable(player)
    return player:isa("Alien")
end

function BotAI_Alien:AIName()
    return "BotAI_Alien"
end

// init
function BotAI_Alien:Initialize()
	self.targetReachedRange = 1.0
	self.orderType = kOrder.None
	self.orderTargetId = Entity.invalidId
end

// leaving this ai
function BotAI_Alien:Dispose()
end

// think
function BotAI_Alien:OnThink(deltaTime)
    
	// misc
	self:UpdateOrder()
	
    // super does state machinin'
    return BotAI_Base.OnThink(self, deltaTime)
end

// chat
function BotAI_Alien:OnChat(message, playerName, teamOnly)
end

// === Misc =================================================

function BotAI_Alien:UpdateOrder()

    local player = self:GetPlayer()
	
    // #1 attack opponent players / mobile objects
    local target = self:GetBot():GetMoblieAttackTarget()
    if target and target:GetHealthScalar() > 0 then
        if self.orderTargetId ~= target:GetId() then
			//Print("A UO found GetMoblieAttackTarget")
            self.orderType = kOrder.Attack
            self.orderTargetId = target:GetId()
            self.lastOrderTime = self.currentTime
            return
        end
    end

    // #2 follow commander orders
    if player.GetCurrentOrder then
		local order = player:GetCurrentOrder()
        if order then
            local orderType = order:GetType()
            local orderTarget = Shared.GetEntity(order:GetParam())
            if orderTarget then
                if orderType == kTechId.Attack then
                    if (not orderTarget:isa("PowerPoint") or not orderTarget:GetIsDestroyed()) and orderTarget:GetHealthScalar() > 0 then
                        if self.orderTargetId ~= orderTarget:GetId() then
							//Print("A UO found attack GetCurrentOrder")
                            self.orderType = kOrder.Attack
                            self.orderLocation = orderTarget:GetEngagementPoint()
                            self.orderTargetId = orderTarget:GetId()
                            self.lastOrderTime = self.currentTime
                            return
                        end
                    end
                end
                if orderType == kTechId.Construct then
                    if self.orderTargetId ~= orderTarget:GetId() then
						//Print("A UO found construct GetCurrentOrder")
                        self.orderType = kOrder.Construct
                        self.orderTargetId = orderTarget:GetId()
                        self.lastOrderTime = self.currentTime
                        return
                    end
                end
            end
            local orderLocation = order:GetLocation()
            if orderLocation then
                if orderLocation ~= self.commanderOrderLocation then
					//Print("A UO found move GetCurrentOrder")
                    self.orderType = kOrder.Move
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
                    self.orderType = kOrder.Move
                    self.orderLocation = self.commanderOrderLocation
                    self.lastOrderTime = self.currentTime
					//Print("A UO commanderOrderLocation")
                    return
                end
            end
        end    
    end
    
    // #4 attack stationary objects
    target = self:GetBot():GetStaticAttackTarget()
    if target and target:GetHealthScalar() > 0 then
        if self.orderTargetId ~= target:GetId() then
			//Print("A UO found GetStaticAttackTarget")
            self.orderType = kOrder.Attack
            self.orderTargetId = target:GetId()
            self.lastOrderTime = self.currentTime
            return
        end
    end

end

// === States ===============================================

function BotAI_Alien:StateTrace(name)
	if (Shared.GetDevMode() and self.stateName ~= name) then
        Print("[A] %s -> %s", self:GetPlayer():GetName(), name)
        self.stateName = name
	end
end

function BotAI_Alien:IdleState()

    self:StateTrace("IdleState")

    // attack order?
    if self.orderType == kOrder.Attack then
        return self.AttackState
    end
    
    // move order?
    if self.orderType == kOrder.Move then
		self.targetReachedRange = .8
        return self.MoveState
    end
    
    // walk around
    if math.random() < .1 then
        self.orderType = kOrder.None
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

function BotAI_Alien:WalkAroundState()

    self:StateTrace("WalkAroundState")
    
    if self.orderType ~= kOrder.None then
		//Print("A WAS order not none")
        self.randomWalkTarget = nil
        return self.IdleState
    end
    
    local player = self:GetPlayer()
    
    // TODO find proper random targets :)
	
	if (not self.randomWalkTarget) then
        self.randomWalkTarget = player:GetEyePos()
        self.randomWalkTarget.x = self.randomWalkTarget.x + math.random(-8, 8)
        self.randomWalkTarget.z = self.randomWalkTarget.z + math.random(-8, 8)
        
        if (math.random() < .4) then
            local ents = Shared.GetEntitiesWithClassname(ConditionalValue(math.random() < .5, "TechPoint", "ResourcePoint"))
            if ents:GetSize() > 0 then 
                local index = math.floor(math.random() * ents:GetSize())
				local target = ents:GetEntityAtIndex(index)
				
				//Print("A WAS random target set to " .. target:GetClassName())
                self.randomWalkTarget = target:GetEngagementPoint()
            end
        end
	end
    
    // bah
    if self:GetBot():MoveToPoint(self.randomWalkTarget, 2.5) or (self:GetStateTime() > kMoveTimeout) then
		//Print("A WAS destination reached")
        self.randomWalkTarget = nil
        return self.IdleState
    end
    
    //self.orderLocation = randomWalkTarget
    //self.targetReachedRange = 1.0
    //self.orderType = kOrder.Move
    return self.WalkAroundState
end

function BotAI_Alien:MoveState()
    
    self:StateTrace("MoveState")
    
    if self.orderType ~= kOrder.Move and self.orderType ~= kOrder.AttackMove then
		//Print("A MS not move or attackmove order")
        return self.IdleState
    end
    
    // target reached?
    if self:GetBot():MoveToPoint(self.orderLocation, self.targetReachedRange) or (self:GetStateTime() > kMoveTimeout) then
        if (self.orderType == kOrder.AttackMove) then
			//Print("A MS reached, attack")
            return self.AttackState
        else
			//Print("A MS reached, idle")
            return self.IdleState
        end
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

function BotAI_Alien:AttackState()
    
    self:StateTrace("AttackState")
    
    if self.orderType == kOrder.AttackMove then
        self.orderType = kOrder.Attack
    end

    // attack?
    if self.orderType ~= kOrder.Attack then
		//Print("A AS not attack order")
        return self.IdleState
    end
    
    local selfOrderTarget = Shared.GetEntity(self.orderTargetId)
    
    // still alive?
    if ( not selfOrderTarget or (self.attackTimeout and self.attackTimeout < Shared.GetTime()) or  (HasMixin(selfOrderTarget, "Live") and not selfOrderTarget:GetIsAlive()) or selfOrderTarget:GetHealthScalar() <= 0) then
        //self:GetBot():SayTeam("Target killed.") // DEBUG
        self.attackTimeout = nil
        self.orderTargetId = Entity.invalidId
        self.orderType = kOrder.None
		//Print("A AS target unavailable or dead")
        return self.IdleState
    end
    
    local player = self:GetPlayer()
    local engagementPoint = selfOrderTarget:GetEngagementPoint()
    
    // check if target visible
    local filter = EntityFilterOne(player)
    local trace = Shared.TraceRay(player:GetEyePos(), selfOrderTarget:GetModelOrigin(), CollisionRep.LOS, PhysicsMask.AllButPCs, filter)
    
    // move towards and attack dat thing when visible
    if (trace.entity == selfOrderTarget) then
        
        self:GetBot():LookAtPoint(selfOrderTarget:GetModelOrigin(), true)
        self:GetBot():MoveForward()
		
		if (math.random() < .2) then
			self:GetBot():Jump()
		end
        
        self.attackTimeout = Shared.GetTime() + 5
        if (player:GetEyePos() - engagementPoint):GetLength() < 3 then
            self:GetBot():PrimaryAttack()
        end
        
        return self.AttackState
    end
    
    // as alien move to target
    if (player:GetEyePos() - engagementPoint):GetLength() > 5 then
        self.orderLocation = engagementPoint
        self.targetReachedRange = 2.0
        self.orderType = kOrder.AttackMove
		//Print("A AS too far away, moving closer")
        return self.MoveState
    end
    
    // look at attack target
    self:GetBot():LookAtPoint(selfOrderTarget:GetOrigin(), true)
    
    return self.AttackState

end

/*
*	Idle
	*	wait for something to happen

*   LookAround
	*	look around randomly
				
*	WalkAround
	*	find your own destination, like
	*	following other players
	*	check random resource and power nodes
				
*	Attack
	*	tasty marines!
	*	GET EM!!1!11!1
*/
