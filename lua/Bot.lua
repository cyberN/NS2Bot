//=============================================================================
//
// lua\Bot.lua
//
// Implementation of Natural Selection 2 bot commands and event hooks
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

// some utility functions/expansions

-- explode(seperator, string)
if (not string.Explode) then
	function string.Explode(d,p)
	  local t, ll
	  t={}
	  ll=0
	  if(#p == 1) then return {p} end
		while true do
		  l=string.find(p,d,ll,true) -- find the next d in the string
		  if l~=nil then -- if "not not" found then..
			table.insert(t, string.sub(p,ll,l-1)) -- Save it in our array.
			ll=l+1 -- save just after where we found it for searching next time.
		  else
			table.insert(t, string.sub(p,ll)) -- Save what's left in our array.
			break -- Break at end, as it should be, according to the lua manual.
		  end
		end
	  return t
	end
end

if (not table.Random) then
	function table.Random(t)
		return t[math.random(#t)]
	end
end

//=============================================================================



local botBots = { }
local botMaxCount = 0

// we need a little delay here :)
local _OriginalServerAddChatToHistory = nil
local function installOverrides()

	if (_OriginalServerAddChatToHistory ~= nil) then return end
	
	// override Server.AddChatToHistory so we can listen for incoming chatter
	_OriginalServerAddChatToHistory = Server.AddChatToHistory
	function Server.AddChatToHistory(message, playerName, steamId, teamNumber, teamOnly)
		// call original
		_OriginalServerAddChatToHistory(message, playerName, steamId, teamNumber, teamOnly)
		
		for _, bot in ipairs(botBots) do
			if (not teamOnly or bot:GetPlayer():GetTeamNumber() == teamNumber) and (playerName ~= bot:GetPlayer():GetName()) then
				return bot:OnChat(message, playerName, teamOnly)
			end
		end
	end
	
	// a commander gave us ping (client, {position = Vector}), overriding NetworkMessages_Server.lua:209
	Server.HookNetworkMessage("CommanderPing", function(client, message)

		local player = client:GetControllingPlayer()
		if player then
			local team = player:GetTeam()
			team:SetCommanderPing(message.position)
			
			local team = player:GetTeamNumber()
			for _, bot in ipairs(botBots) do
				if bot:GetPlayer():GetTeamNumber() == team then
					bot:OnCommanderPing(message.position)
				end
			end
		end
	end)
end

function Bot_OnConsoleSetBots(client, countParam)

    // admin rights?
    if client ~= nil and not Shared.GetCheatsEnabled() and not Shared.GetDevMode() then
        return
    end

    // set max bot count
    if countParam then
        botMaxCount = math.min(10, math.max(0, tonumber(countParam)))
    end
    
    // compute new bot count
    local totalPlayerCount = Shared.GetEntitiesWithClassname("Player"):GetSize()
    local normalPlayerCount = totalPlayerCount - table.maxn(botBots)
    local botCount = math.min(math.max(botMaxCount + 1 - normalPlayerCount, 0), botMaxCount)
    
    // add more bots
    while table.maxn(botBots) < botCount do
    
	
		Print("######################## ADDED A BOT ######################")
		
        local bot = BotAIUser()
        bot:Initialize()
        bot.client = Server.AddVirtualClient()
        table.insert(botBots, bot)
   
    end
    
    // remove bots
    while table.maxn(botBots) > botCount do

        // find larger team
        local largerTeam
        local rules = GetGamerules()
        local playersTeam1 = rules:GetTeam(kTeam1Index):GetNumPlayers()
        local playersTeam2 = rules:GetTeam(kTeam2Index):GetNumPlayers()
        if playersTeam1 > playersTeam2 then
            largerTeam = kTeam1Index
        elseif playersTeam2 > playersTeam1 then
            largerTeam = kTeam2Index
        else
            largerTeam = ConditionalValue(math.random() < 0.5, kTeam1Index, kTeam2Index)
        end
    
        // find bot from larger team
        local botToRemove = 1
        for i, bot in ipairs(botBots) do
            local player = bot.client:GetControllingPlayer()
            if player:GetTeamNumber() == largerTeam then
                botToRemove = i
                break
            end
        end
        
		Print("######################## REMOVED A BOT ######################")
		
        // remove bot
        local bot = botBots[botToRemove]
        Server.DisconnectClient(bot.client)
        bot.client = nil
        table.remove(botBots, botToRemove)
    end

end

function Bot_OnConsoleAddBots(client, countParam)

    // admin rights?
    if client ~= nil and not Shared.GetCheatsEnabled() and not Shared.GetDevMode() then
        return
    end
    
    // update bot count
    local count = 1
    if countParam then
        count = math.max(1, tonumber(countParam))
    end    
    Bot_OnConsoleSetBots(client, botMaxCount + count)
    
end

function Bot_OnConsoleRemoveBots(client, countParam)
    
    // admin rights?
    if client ~= nil and not Shared.GetCheatsEnabled() and not Shared.GetDevMode() then
        return
    end
    
    // update bot count
    local count = 1
    if countParam then
        count = math.max(1, tonumber(countParam))
    end    
    Bot_OnConsoleSetBots(client, botMaxCount - count)
    
end

function Bot_OnVirtualClientMove(client)

    for _, bot in ipairs(botBots) do    
        if bot.client == client then
            return bot:OnMove()
        end        
    end

end

function Bot_OnVirtualClientThink(client, deltaTime)
	installOverrides()
	
    for _, bot in ipairs(botBots) do
        if bot.client == client then
            return bot:OnThink(deltaTime)
        end
    end
end

function Bot_OnUpdateServer()
    if math.random() < .005 then
        Bot_OnConsoleSetBots()
    end
end

Event.Hook("Console_addbot",         Bot_OnConsoleAddBots)
Event.Hook("Console_removebot",      Bot_OnConsoleRemoveBots)
Event.Hook("Console_addbots",        Bot_OnConsoleAddBots)
Event.Hook("Console_removebots",     Bot_OnConsoleRemoveBots)
Event.Hook("Console_setbots",        Bot_OnConsoleSetBots)

Event.Hook("VirtualClientThink",     Bot_OnVirtualClientThink)
Event.Hook("VirtualClientMove",      Bot_OnVirtualClientMove)

Event.Hook("UpdateServer",           Bot_OnUpdateServer)

Script.Load("lua/Bot_Base.lua")
//Script.Load("lua/Bot_Jeffco.lua")
Script.Load("lua/Bot_AiUser.lua")
