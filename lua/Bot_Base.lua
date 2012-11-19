//=============================================================================
//
// lua\Bot_Base.lua
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

class 'Bot'

Script.Load("lua/TargetCache.lua")
Script.Load("lua/BotAI_PathMixin.lua")
Script.Load("lua/BotAI_TargetingMixin.lua")

//=== General =================================================================

// When bot object gets created
function Bot:Initialize()

	// mixins
    InitMixin(self, BotAI_PathMixin)
	InitMixin(self, BotAI_TargetingMixin)
end

// Get the virtual client object
function Bot:GetClient()
	return self.client
end

// Get the player object, initializes mixins where needed
function Bot:GetPlayer()
    local player = self:GetClient():GetControllingPlayer()
    
    if not HasMixin(player, "TargetCache") then
        InitMixin(player, TargetCacheMixin)
    end

    return player
end

function Bot:GetIsFlying()
    // TODO check for lerk or jetpack?
    return false
end

//=== Callbacks ================================================================

function Bot:OnThink(deltaTime)
    
	// set default move
    local player = self:GetPlayer()
    local move = Move()
    move.yaw = player:GetAngles().yaw - player:GetBaseViewAngles().yaw // keep the current yaw/pitch
    move.pitch = player:GetAngles().pitch - player:GetBaseViewAngles().pitch
    self.move = move
	
    if Shared.GetDevMode() then
		self:DebugDrawLineOfSight()
	end
end

function Bot:OnMove()
	return self.move
end

//=== Movement =================================================================

function Bot:Jump()
	self.move.commands = bit.bor(self.move.commands, Move.Jump)
end
function Bot:Crouch()
	self.move.commands = bit.bor(self.move.commands, Move.Crouch)
end
function Bot:Reload()
	self.move.commands = bit.bor(self.move.commands, Move.Reload)
end
function Bot:PrimaryAttack()
	self.move.commands = bit.bor(self.move.commands, Move.PrimaryAttack)
end
function Bot:SecondaryAttack()
	self.move.commands = bit.bor(self.move.commands, Move.SecondaryAttack)
end
function Bot:Use()
	self.move.commands = bit.bor(self.move.commands, Move.Use)
end
function Bot:Buy()
	self.move.commands = bit.bor(self.move.commands, Move.Buy)
end
function Bot:Taunt()
	self.move.commands = bit.bor(self.move.commands, Move.Taunt)
end
function Bot:Weapon1()
	self.move.commands = bit.bor(self.move.commands, Move.Weapon1)
end
function Bot:Weapon2()
	self.move.commands = bit.bor(self.move.commands, Move.Weapon2)
end
function Bot:Weapon3()
	self.move.commands = bit.bor(self.move.commands, Move.Weapon3)
end
function Bot:Weapon4()
	self.move.commands = bit.bor(self.move.commands, Move.Weapon4)
end
function Bot:Weapon5()
	self.move.commands = bit.bor(self.move.commands, Move.Weapon5)
end
function Bot:NextWeapon()
	self.move.commands = bit.bor(self.move.commands, Move.NextWeapon)
end
function Bot:PrevWeapon()
	self.move.commands = bit.bor(self.move.commands, Move.PrevWeapon)
end

function Bot:MoveForward()
	self.move.move.z = 1
end
function Bot:MoveBackward()
	self.move.move.z = -1
end
function Bot:MoveLeft()
	self.move.move.x = -1
end
function Bot:MoveRigth()
	self.move.move.x = 1
end

function Bot:LookAtPoint(destination, direct)
    local player = self:GetPlayer()

    // compute direction to target
    local diff = destination - player:GetEyePos()
    local direction = GetNormalizedVector(diff)
    
    // look at target
    if direct then
        self.move.yaw = GetYawFromVector(direction) - player:GetBaseViewAngles().yaw
    else
        self.move.yaw = SlerpRadians(self.move.yaw, GetYawFromVector(direction) - player:GetBaseViewAngles().yaw, 0.75)
    end
    self.move.pitch = GetPitchFromVector(direction) - player:GetBaseViewAngles().pitch
end

// Navigate AI player to destination
// - destination: Vector where we should go
// - reachedRange: Distance (XZ) how close we should get to the destination
// - disablePathing: Skip the pathfinding and move directly to target
// return: true if end reached
function Bot:MoveToPoint(destination, reachedRange, disablePathing)

    local player = self:GetPlayer()
	local playerPos = player:GetOrigin()
	
	if (type(reachedRange) == "boolean") then
		disablePathing = reachedRange
	end
	
    // use pathfinder
    if disablePathing == nil then
	
		// Returns distance to target, -1 would tell us that it can't be reached
		local distanceToTarget = self:CheckTarget(destination)
		
		if (distanceToTarget > 0) then
			
			// check destination reached
			if (distanceToTarget < reachedRange) then
				return true
			end
			
			// find next navigation point
			local nextPoint = self:FindNextAIPathPoint()
			
			if (nextPoint == nil) then
				self:MarinePrint("Movedestination cant find next point")
				self:ResetAIPath()
                return true
			end
			
			// check when we haven't moved as we pleased in the last second
			if (self.mAntiStuckPos == nil) then
				self.mAntiStuckPos = playerPos
				self.mAntiStuckTime = Shared.GetTime() + 2
			else
				if (self.mAntiStuckTime < Shared.GetTime()) then
					if ((playerPos - self.mAntiStuckPos):GetLengthXZ() < 0.25) then
						self:ResetAIPath()
						self.mAntiStuckPos = nil
						return true
					end
					
					self.mAntiStuckPos = playerPos
					self.mAntiStuckTime = Shared.GetTime() + 2
				end
			end
			
			// walk!
			self.mNextPathPoint = nextPoint
            self:LookAtPoint(self.mNextPathPoint)
			self:MoveForward()
            return false
		end
		
		// can't find target, so tell em we reached it.
		self:ResetAIPath()
		return true
	else
		self.mNextPathPoint = nil
		
		self:LookAtPoint(destination)
		self:MoveForward()
		
		return false
	end
end

//=== Interaction =============================================================


//=============================================================================


//=== Misc ====================================================================

function Bot:IsMarine()
	return self:GetPlayer():isa("Marine")
end

function Bot:IsAlien()
	return self:GetPlayer():isa("Alien")
end

//=============================================================================

//=============================================================================

//=============================================================================

//=============================================================================

//=============================================================================

//=== Debug ===================================================================

local kDebugLinePause = 0.25

function Bot:DebugDrawLineOfSight()
	if (self.lastDebugLine == nil or self.lastDebugLine < Shared.GetTime()) then
		self.lastDebugLine = Shared.GetTime() + kDebugLinePause
		
		local viewPos = self:GetPlayer():GetEyePos()
		local viewVec = self:GetPlayer():GetViewAngles():GetCoords().zAxis
		
		DebugLine(viewPos, viewPos + viewVec * 3, kDebugLinePause * 1.25, 1, 0.5, 0, 1)
	end
end

function DebugDrawPoint(p, t, r, g, b, a)
    if not Shared.GetDevMode() then return end
    DebugLine(p - Vector.xAxis * .3, p + Vector.xAxis * .3, t, r, g, b, a)
    DebugLine(p - Vector.yAxis * .3, p + Vector.yAxis * .3, t, r, g, b, a)
    DebugLine(p - Vector.zAxis * .3, p + Vector.zAxis * .3, t, r, g, b, a)
end

function Bot:DebugMarinePrint(txt)
	if self:IsMarine() then
		Print("[MPRINT] "..txt)
    end
end

