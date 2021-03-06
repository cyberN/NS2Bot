//=============================================================================
//
// lua\ai\BotAI_MarineCommander.lua
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

class 'BotAI_MarineCommander' (BotAI_Base)

// is the player ok with this ai type?
function BotAI_MarineCommander.IsPlayerApplicable(player)
    return player:isa("Marine") or player:isa("MarineCommander")
end

function BotAI_MarineCommander:AIName()
    return "BotAI_MarineCommander"
end

// init
function BotAI_MarineCommander:Initialize()
end

// leaving this ai
function BotAI_MarineCommander:Dispose()
end

// think
function BotAI_MarineCommander:OnThink(deltaTime)
    // super does state machinin'
    return BotAI_Base.OnThink(self, deltaTime)
end

// chat
function BotAI_MarineCommander:OnChat(message, playerName, teamOnly)
    return BotAI_Base.OnChat(self, message, playerName, teamOnly)
end

// === States ===============================================

function BotAI_MarineCommander:IdleState()
    return self.GetTheFuckOutState
end

function BotAI_MarineCommander:GetTheFuckOutState()

    // get out of here >:C
    self:Exit()
    self:SayTeam("How the hell did I become the commander?")
    
    return self.IdleState
end
