//=============================================================================
//
// Bot that uses class specialized AIs
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

Script.Load("lua/Bot_Base.lua")
Script.Load("lua/chat/ChatBot_Mixin.lua")

// all ai's
Script.Load("lua/ai/BotAI_Base.lua")
Script.Load("lua/ai/BotAI_Marine.lua")
Script.Load("lua/ai/BotAI_Alien.lua")
Script.Load("lua/ai/BotAI_MarineCommander.lua")
Script.Load("lua/ai/BotAI_AlienCommander.lua")

class 'BotAIUser' (Bot)

function BotAIUser:Initialize()
	// super
	Bot.Initialize(self)
	
	InitMixin(self, ChatBot_Mixin)
	
	// our AI
	self.activeAI = nil
	self.activePlayerClassName = "none"
end

function BotAIUser:OnChat(message, playerName, teamOnly)
	// super
    Bot.OnChat(message, playerName, teamOnly)
    
	// chatbot
	self:ChatReceived(message, playerName, teamOnly)
	
	// ai
    if (self.activeAI) then
        self.activeAI:OnChat(message, playerName, teamOnly)
    end
end

function BotAIUser:OnThink(deltaTime)
	// super
	Bot.OnThink(self, deltaTime)
	
	// chatbot
	self:ChatThink()
	
	local player = self:GetPlayer()
	
	// if readyroom make us base
	if (self:IsReadyRoom() and not self.base) then
		self:ChangeAI( BotAI_Base )
		self.base = true
		self.activePlayerClassName = player:GetClassName()
	end
	
	// check class of player
	if (self.activePlayerClassName ~= player:GetClassName()) then
	    Print( player:GetName() .. "'s player class has changed from " .. self.activePlayerClassName .. " to " .. player:GetClassName())
	    
	    // unload old ai
	    if (self.activeAI) then
	        self.activeAI:Dispose()
            self.activeAI._bot = nil
	        self.activeAI = nil
	    end
	    
	    self.activePlayerClassName = self:GetPlayer():GetClassName()
	    
	    if self:ChangeAI( BotAI_Base ) then
			self.base = true
	        return true
	    end
		
		self.base = false
	    
	    if self:ChangeAI( BotAI_Marine ) then
	        return true
	    end
	    
	    if self:ChangeAI( BotAI_Alien ) then
	        return true
	    end
	    
	    if self:ChangeAI( BotAI_MarineCommander ) then
	        return true
	    end
	    
	    if self:ChangeAI( BotAI_AlienCommander ) then
	        return true
	    end
	       
	    self:SayAll("For some reason there is no AI that's suitable for me as " .. self:GetPlayer():GetClassName())
	    
	end
	
    // ai
    if (self.activeAI) then
        self.activeAITime = Shared.GetTime() - self.activeAIStartTime
        
        // copy .move reference
        self.activeAI.move = self.move
            self.activeAI:OnThink(deltaTime)
        self.move = self.activeAI.move
    end
    
	return true
end

function BotAIUser:OnSpawn()
    Bot.OnSpawn(self)
    if (self.activeAI) then
        self.activeAI:OnSpawn()
    end
end

function BotAIUser:OnDeath()
    Bot.OnDeath(self)
	self:ChatDeath()
    if (self.activeAI) then
        self.activeAI:OnDeath()
    end
end

function BotAIUser:ChangeAI(newAI)
    if (newAI) then
        if newAI.IsPlayerApplicable(self:GetPlayer()) then
            
            // unload old ai
            if (self.activeAI) then
                self.activeAI:Dispose()
                self.activeAI._bot = nil
                self.activeAI = nil
            end
            
            // set new
	        self.activeAI = newAI()
	        self.activeAI._bot = self
	        self.activeAIStartTime = Shared.GetTime()
	        self.activeAITime = 0
	        self.activeAI:Initialize()
	        Print(self:GetPlayer():GetName().."'s AI has been changed to " .. self.activeAI:AIName())
	        
	        return true
        end
    end
	return false
end

// active time in current ai
function BotAIUser:GetActiveAITime()
    return self.activeAITime
end

