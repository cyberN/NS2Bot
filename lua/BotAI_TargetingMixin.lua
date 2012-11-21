//=============================================================================
//
// lua\BotAI_TargetingMixin.lua
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

BotAI_TargetingMixin = { }
BotAI_TargetingMixin.type = "BotAI_Targeting"

function BotAI_TargetingMixin:__initmixin()
end

local kRange = 30
local kMaxPitch = 85
local kMinPitch = -85

//
// Removes targets that are not inside the maxYaw
// TODO
/*
function PitchTargetFilter(attacker, minPitchDegree, maxPitchDegree)
    return function(target, targetPoint)
        local origin = GetEntityEyePos(attacker)
        local viewCoords = GetEntityViewAngles(attacker):GetCoords()
        local v = targetPoint - origin
        local distY = Math.DotProduct(viewCoords.yAxis, v)
        local distZ = Math.DotProduct(viewCoords.zAxis, v)
        local pitch = 180 * math.atan2(distY,distZ) / math.pi
        result = pitch >= minPitchDegree and pitch <= maxPitchDegree
        // Log("filter %s for %s, v %s, pitch %s, result %s (%s,%s)", target, attacker, v, pitch, result, minPitchDegree, maxPitchDegree)
        return result
    end  
end
*/

function BotAI_TargetingMixin:GetMoblieAttackTarget()

    local player = self:GetPlayer()

    if not player.mobileTargetSelector then
        if player:isa("Marine") then
            player.mobileTargetSelector = TargetSelector():Init(
                player,
                kRange, 
                true,
                { kMarineMobileTargets },
                { PitchTargetFilter(player,  -kMaxPitch, kMaxPitch), CloakTargetFilter() })
        end
        if player:isa("Alien") then
            player.mobileTargetSelector = TargetSelector():Init(
                player,
                kRange, 
                true,
                { kAlienMobileTargets },
                { PitchTargetFilter(player,  -kMaxPitch, kMaxPitch) })
        end
    end
    
    if player.mobileTargetSelector then
        player.mobileTargetSelector:AttackerMoved()
        return player.mobileTargetSelector:AcquireTarget()
    end
end

function BotAI_TargetingMixin:GetStaticAttackTarget()

    local player = self:GetPlayer()

    if not player.staticTargetSelector then
        if player:isa("Marine") then
            player.staticTargetSelector = TargetSelector():Init(
                player,
                kRange, 
                true,
                { kMarineStaticTargets },
                { CloakTargetFilter() })
        end
        if player:isa("Alien") then
            player.staticTargetSelector = TargetSelector():Init(
                player,
                kRange, 
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
