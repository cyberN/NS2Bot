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
    if target then
        if self.orderTarget ~= target then
            self.orderType = kOrder.Attack
            self.orderTarget = target
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
                    if not orderTarget:isa("PowerPoint") or not orderTarget:GetIsDestroyed() then
                        if self.orderTarget ~= orderTarget then
                            self.orderType = kOrder.Attack
                            self.orderLocation = orderTarget:GetEngagementPoint()
                            self.orderTarget = orderTarget
                            self.lastOrderTime = self.currentTime
                            return
                        end
                    end
                end
                if orderType == kTechId.Construct then
                    if self.orderTarget ~= orderTarget then
                        self.orderType = kOrder.Construct
                        self.orderTarget = orderTarget
                        self.lastOrderTime = self.currentTime
                        return
                    end
                end
            end
            local orderLocation = order:GetLocation()
            if orderLocation then
                if orderLocation ~= self.commanderOrderLocation then
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
                    return
                end
            end
        end    
    end
    
    // #4 attack stationary objects
    target = self:GetBot():GetStaticAttackTarget()
    if target then
        if self.orderTarget ~= orderTarget then
            self.orderType = kOrder.Attack
            self.orderTarget = target
            self.lastOrderTime = self.currentTime
            return
        end
    end

end

// === States ===============================================

function BotAI_Alien:IdleState()

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
    if math.random() < .05 then
        return self.WalkAroundState
    end

    // look around
    if math.random() < .1 then
        return self.LookAroundState
    end

    return self.IdleState
end

function BotAI_Alien:LookAroundState()
    
    if self.orderType ~= kOrder.None then
        return self.IdleState
    end
    
    if self.randomLookTarget == nil then
        local player = self:GetPlayer()
        self.randomLookTarget = player:GetEyePos()
        self.randomLookTarget.x = self.randomLookTarget.x + math.random(-50, 50)
        self.randomLookTarget.z = self.randomLookTarget.z + math.random(-50, 50)
    end

    self:GetBot():LookAtPoint(self.randomLookTarget)
    
    if self.lastYaw then
        if (math.abs(self.move.yaw - self.lastYaw) < .05 and math.abs(self.move.pitch - self.lastPitch) < .05) or self.stateTime > 10 then
            self.randomLookTarget = nil
            return self.IdleState
        end
    end
    self.lastYaw = self.move.yaw
    self.lastPitch = self.move.pitch
    
    return self.LookAroundState
end

function BotAI_Alien:WalkAroundState()

    if self.orderType ~= kOrder.None then
        return self.IdleState
    end
    
    local player = self:GetPlayer()
    
    // TODO find proper random targets :)
	
    local randomWalkTarget = player:GetEyePos()
    randomWalkTarget.x = randomWalkTarget.x + math.random(-8, 8)
    randomWalkTarget.z = randomWalkTarget.z + math.random(-8, 8)

    local ents = Shared.GetEntitiesWithClassname(ConditionalValue(math.random() < .5, "TechPoint", "ResourcePoint"))
    if ents:GetSize() > 0 then 
        local index = math.floor(math.random() * ents:GetSize())
        local target = ents:GetEntityAtIndex(index)
        randomWalkTarget = target:GetEngagementPoint()
    end
    
    self.orderLocation = randomWalkTarget
    self.targetReachedRange = 1.0
    self.orderType = kOrder.Move
    return self.MoveState
end

function BotAI_Alien:MoveState()
    
    if self.orderType ~= kOrder.Move and self.orderType ~= kOrder.AttackMove then
        return self.IdleState
    end
    
    // target reached?
    if self:GetBot():MoveToPoint(self.orderLocation, self.targetReachedRange) or (self:GetStateTime() > kMoveTimeout) then
        if (self.orderType == kOrder.AttackMove) then
            return self.AttackState
        else
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
    
	// silly errors, so let's pcall dis
	local ok, state = pcall( function(self)
		
		if self.orderType == kOrder.AttackMove then
			self.orderType = kOrder.Attack
		end

		// attack?
		if self.orderType ~= kOrder.Attack then
			return self.IdleState
		end
		
		// still valid?
		if not self.orderTarget then
			self.orderTarget = nil
			return self.IdleState
		end
		
		local player = self:GetPlayer()
		
		// as alien move to target
		local engagementPoint = self.orderTarget:GetEngagementPoint()
		if (player:GetEyePos() - engagementPoint):GetLengthSquared() > 5 then
			self.orderLocation = engagementPoint
			self.targetReachedRange = 1.0
			self.orderType = kOrder.AttackMove
			return self.MoveState
		end
		
		// timeout?
		if self:GetStateTime() > 20 then
			self.orderLocation = self.orderTarget:GetEngagementPoint()
			self.targetReachedRange = 1.0
			self.orderType = kOrder.Move
			return self.MoveState
		end
		
		// look at attack target
		self:GetBot():LookAtPoint(self.orderTarget:GetOrigin(), true)
		
		// attack!
		if math.random() < .6 then
			self:GetBot():PrimaryAttack()
		end

		return self.AttackState
	end )
	
	if (ok) then
		return state
	else
		self.orderTarget = nil
		return self.IdleState
	end
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
