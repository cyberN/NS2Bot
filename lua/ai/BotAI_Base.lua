//=============================================================================
//
//  Basic AI, used when in ReadyRoom
//  Chooses a team and a name
//
// lua\ai\BotAI_Base.lua
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

class 'BotAI_Base'

local kBotNames = {
    "Flayra (bot)", "Borsty (bot)", "Jeffco (bot)", "m4x0r (bot)", "Ooghi (bot)", "Breadman (bot)", "Chops (bot)", "Numerik (bot)",
    "Comprox (bot)", "MonsieurEvil (bot)", "Joev (bot)", "puzl (bot)", "Crispix (bot)", "Kouji_San (bot)", "TychoCelchuuu (bot)",
    "Insane (bot)", "devildog (bot)", "tommyd (bot)", "Relic25 (bot)"
}

// is the player ok with this ai type?
function BotAI_Base.IsPlayerApplicable(player)
    return player:isa("ReadyRoomPlayer") or player:isa("AlienSpectator") or player:isa("MarineSpectator")
end

function BotAI_Base:AIName()
    return "BotAI_Base"
end

function BotAI_Base:Initialize()
    // Let's find us a nice name
    local myName = nil
    while (myName == nil) do
        myName = table.Random(kBotNames)
        // check other players
        for _,pl in ientitylist(Shared.GetEntitiesWithClassname("Player")) do
            if (pl:GetName() == myName) then
                myName = nil
                break
            end
        end
    end
    OnCommandSetName(self:GetClient(), myName)
    self.deltaTime = 0
end

function BotAI_Base:GetBot()
    return self._bot
end

function BotAI_Base:GetClient()
    return self._bot:GetClient()
end

function BotAI_Base:GetPlayer()
    return self._bot:GetPlayer()
end

function BotAI_Base:GetActiveAITime()
    return self:GetBot():GetActiveAITime()
end

function BotAI_Base:GetStateTime()
    return self.stateTime
end

// leaving this ai
function BotAI_Base:Dispose()
end

function BotAI_Base:DeltaTime()
    return self.deltaTime
end

// think
function BotAI_Base:OnThink(deltaTime)

    self.deltaTime = deltaTime

    // use a state machine to generate a move
	local currentTime = Shared.GetTime()
	if self.state == nil then
		self.state = self.IdleState
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

// chat
function BotAI_Base:OnChat(message, playerName, teamOnly)
end

// === States ===========================================

function BotAI_Base:IdleState()
    
    local player = self:GetPlayer()
    
    // in rr?
    if (player:GetTeamNumber() == 0) then
        return self.JoinTeamState
    end
    
    // alien respawing?
    if player:isa("AlienSpectator") then
        return self.HatchState
    end
    
    return self.IdleState
end

function BotAI_Base:JoinTeamState()
    
    // wait a little before joining
    if (self:GetActiveAITime() > 5) then
        
        local rules = GetGamerules()
        
        local playersTeam1 = rules:GetTeam(kTeam1Index):GetNumPlayers()
        local playersTeam2 = rules:GetTeam(kTeam2Index):GetNumPlayers()
        
        local joinTeam = ConditionalValue(playersTeam1 < playersTeam2, 1, 2)
        
        if rules:GetCanJoinTeamNumber(joinTeam) or Shared.GetCheatsEnabled() then
            rules:JoinTeam(self:GetPlayer(), joinTeam)
        end
        
        return self.IdleState
    end
    
    return self.JoinTeamState
end

function BotAI_Base:HatchState()

    local player = self:GetPlayer()
    
    if (not player:isa("AlienSpectator")) then
       return self.IdleState
    end
	
    self:GetBot():PrimaryAttack()
    
    return self.HatchState
end
