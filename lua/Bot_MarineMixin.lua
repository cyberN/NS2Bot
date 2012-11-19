//=============================================================================
//
// lua\Bot_MarineMixin.lua
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

Bot_MarineMixin = { }
Bot_MarineMixin.type = "Bot_Marine"

function Bot_MarineMixin:__initmixin()
end

//=== Find helpers ============================================================

local kRepairRange = 10

function Bot_MarineMixin:FindPickupable(className)
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

function Bot_MarineMixin:FindInfantryPortal()
    local ents = Shared.GetEntitiesWithClassname("InfantryPortal")    
    if ents:GetSize() > 0 then 
        return ents:GetEntityAtIndex(0)
    end
end

function Bot_MarineMixin:FindRepairTarget()

    local player = self:GetPlayer()
    local eyePos = player:GetEyePos()
    local repairTarget, closestDistance
    local allowedDistance = kRepairRange * kRepairRange
    
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

//=== Commander ===============================================================

function Bot_MarineMixin:GetHasCommander()
    local ents = Shared.GetEntitiesWithClassname("MarineCommander")
    local count = ents:GetSize()
    local player = self:GetPlayer()
    local teamNumber = player:GetTeamNumber()
    
    for i = 0, count - 1 do
        local commander = ents:GetEntityAtIndex(i)
        if (commander ~= nil and commander:GetTeamNumber() == teamNumber) then
            return true
        end
    end
    
    return false
end

function Bot_MarineMixin:GetCommandStation()
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

//=== Weapons =================================================================

function Bot_MarineMixin:GetWeapons()

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

function Bot_MarineMixin:GetAmmoScalar()

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

//=============================================================================

//=============================================================================

//=============================================================================

//=============================================================================
