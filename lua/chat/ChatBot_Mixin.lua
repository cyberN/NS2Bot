//=============================================================================
//
// lua\chat\ChatBot_Mixin.lua
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

Script.Load("lua/ConfigFileUtility.lua")

ChatBot_Mixin = { }
ChatBot_Mixin.type = "ChatBot"

ChatPhrases = {}

Script.Load("lua/chat/ChatBot_Phrases.lua")

local randomChatter = { }
randomChatter[1] = "Whoa look at all this D:"
randomChatter[2] = "I am watching your every move you know?"
randomChatter[3] = "hmm"
randomChatter[4] = "I like turtles"
randomChatter[5] = "I'm so bad at this lol"
randomChatter[6] = "What to do now?"

local joinGreetings = {}
joinGreetings[1] = "Hey guys"
joinGreetings[2] = "Hi"
joinGreetings[3] = "hi! :D"
joinGreetings[4] = "sup"

local greetings = {}
greetings[1] = "Hey! What's up?"
greetings[2] = "Hey <n>."
greetings[3] = "What's up <n> ?"
greetings[4] = "Uh oh! <n> has join :O."

local chatBots = { }

function ChatBot_Mixin:__initmixin()
	self.nextRandomChat = Shared.GetTime() + math.random(20) + 10
	table.insert(chatBots, self)
end

local function formatChat(msg, format)
	for k,v in pairs(format) do
		msg = string.gsub( msg , "<"..k..">", v )
	end
	return msg
end

// new player has connected (client, {armorId = kArmorType})
Server.HookNetworkMessage("ConnectMessage", function(client, message)
    if client then
        local player = client:GetControllingPlayer()
        if player then
			for _,cbot in ipairs(chatBots) do
				if (cbot.client) then
					cbot:PlayerConnected(player)
				end
			end
		end
	end
end)

function ChatBot_Mixin:PlayerConnected(player)
	if (math.random() < .5) then
		self:DelayedChat(formatChat(table.Random(greetings), {n = player:GetName()}), math.random() < .5)
	end
end

function ChatBot_Mixin:ChatRandom()
	if (self.nextRandomChat < Shared.GetTime()) then
		self.nextRandomChat = Shared.GetTime() + math.random(60) + 30
		self:DelayedChat(table.Random(randomChatter), math.random() < .5)
		return
	end
end

function ChatBot_Mixin:ChatSayHello()
	if math.random() < .33 then
		self:DelayedChat(table.Random(joinGreetings))
	end
end

function ChatBot_Mixin:ChatReceived(message, playerName, teamOnly)
	
	// not always :)
	if (math.random() < 0.66) then return end

	message = string.lower(message)

	for k,v in pairs( string.Explode( " ", message ) ) do
		for key, value in pairs( ChatPhrases ) do
			if v == key and (math.random() < 0.66) then
				local replacement = table.Random( value )
				self:DelayedChat(formatChat(replacement, {n = playerName}), teamOnly)
				return
			end
		end
	end
end

// Simulates real human typing ;)
function ChatBot_Mixin:DelayedChat(msg, teamOnly, delay)
	self.nextDelayedChatMessage = msg
	self.nextDelayedChatTeamOnly = teamOnly
	if (delay) then
		self.nextDelayedChatTime = Shared.GetTime() + delay
	else
		self.nextDelayedChatTime = Shared.GetTime() + string.len(msg) * 0.1 + math.random(2)
	end
end

function ChatBot_Mixin:ChatThink()
	self:ChatRandom()
	
	if (self.nextDelayedChatMessage and self.nextDelayedChatTime < Shared.GetTime()) then
		if (self.nextDelayedChatTeamOnly) then
			self:SayTeam(self.nextDelayedChatMessage)
		else
			self:SayAll(self.nextDelayedChatMessage)
		end
		self.nextDelayedChatMessage = nil
	end
end
