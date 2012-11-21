//=============================================================================
//
// lua\ai\BotAI_AlienCommander.lua
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

class 'BotAI_AlienCommander' (BotAI_Base)

// is the player ok with this ai type?
function BotAI_AlienCommander.IsPlayerApplicable(player)
    return player:isa("Alien") or player:isa("AlienCommander")
end

function BotAI_AlienCommander:AIName()
    return "BotAI_AlienCommander"
end

// init
function BotAI_AlienCommander:Initialize()
end

// leaving this ai
function BotAI_AlienCommander:Dispose()
end

// think
function BotAI_AlienCommander:OnThink(deltaTime)
    // super does state machinin'
    return BotAI_Base.OnThink(self, deltaTime)
end

// chat
function BotAI_AlienCommander:OnChat(message, playerName, teamOnly)
    return BotAI_Base.OnChat(self, message, playerName, teamOnly)
end

// === States ===============================================

function BotAI_AlienCommander:IdleState()
    return self.GetTheFuckOutState
end

function BotAI_AlienCommander:GetTheFuckOutState()

    // get out of here >:C
    self:Exit()
    self:SayTeam("How the hell did I become the commander?")
    
    return self.IdleState
end
