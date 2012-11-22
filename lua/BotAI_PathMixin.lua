//=============================================================================
//
// lua/BotAI_PathMixin.lua
//
// Created by ZycaR
// Chunks of code are inspired/reused/copyied from other NS2 parts to speed up implementation
//
// This class is an AI for Pathing mixin
//
// Edited by Sebastian J. (borstymail@googlemail.com)
//
//=============================================================================
Script.Load("lua/PathingUtility.lua")

BotAI_PathMixin = { }
BotAI_PathMixin.type = "BotAI_Path"

function BotAI_PathMixin:__initmixin()
    self:ResetAIPath()
end

function BotAI_PathMixin:ResetAIPath()
    self.pathPoints = nil
    self.pathDistance = nil
end

function BotAI_PathMixin:IsAIPathValid()
    return (self.pathPoints ~= nil and #(self.pathPoints) > 0)
end

function BotAI_PathMixin:RemainingAIPathPoint()
	if (self.pathPointIndex < 0) then
		return 0
	end
    return (#(self.pathPoints) - self.pathPointIndex)
end

function BotAI_PathMixin:CurrentAIPathPoint()
	if (self.pathPointIndex < 0) then
		return self.currentDst
	end
    if (self:IsAIPathValid()) then
        return self.pathPoints[self.pathPointIndex]
    else    
        return nil
    end
end

local kDstChangeMaximum = 0.1
local kPlayerPosChangeMaximum = 1.0

function BotAI_PathMixin:GetTargetDistance()
	self.lastDistance = (self:GetPlayer():GetOrigin() - self.currentDst):GetLengthXZ()
	return self.lastDistance
end

//Added by borsty
// Check for navigation path
// When player position or destination has been changed, calculates new path
// Returns distance to destination, -1 on invalid path
function BotAI_PathMixin:CheckTarget(dst)
    
	// pre conditioning
	if (self.lastPos == nil) then
		self.lastPos = Vector(0,0,0)
	end
	if (self.currentDst == nil) then
		self.currentDst = Vector(0,0,0)
	end
	
	local playerPos = self:GetPlayer():GetOrigin()
	
	// path valid? player teleported? destination changed?
	local pathValid = self:IsAIPathValid() and
		((playerPos - self.lastPos):GetLengthXZ() < kPlayerPosChangeMaximum) and
		((dst - self.currentDst):GetLengthXZ() < kDstChangeMaximum)
	
	// build new path when needed
	if (not pathValid) then
        if self:CreateAIPath(playerPos, dst) then
			self:FindNextAIPathPoint() // dont start with first point, find first point with desired distance
			self.lastPos = playerPos
			self.currentDst = dst
            return self:GetTargetDistance()
		else
			self.lastPos = nil
			self.currentDst = nil
        end
        
        return -1
	end
	
	// update currentSrc
	self.lastPos = playerPos
	
	// calculate distance left
	return self:GetTargetDistance()
end

function BotAI_PathMixin:CreateAIPath(src, dst)
	
	self:ResetAIPath()
	
	// generate a new AI path
	self.pathPoints = GeneratePath(src, dst)    
	self.pathDistance = GetPointDistance(self.pathPoints)
	self.pathPointIndex = 1
	
	// draw path in 'dev' mode
	//if Shared.GetDevMode() and (self.pathPoints ~= nil) then
	//    self:DrawAIPath(10)
	//end
	
	return self:IsAIPathValid()
end

function BotAI_PathMixin:FindClosestAIPathPoint(location)

    local closestIndex = -1
    local closestPointSqDist = 999999999
    
    if not self:IsAIPathValid() then
        return closestIndex
    end
    
    for index, point in ipairs(self.pathPoints) do

        local point = self.pathPoints[index]
        local dir = location - point
        local length = dir:GetLengthSquared()
        
        if length < closestPointSqDist then
            closestIndex = index
            closestPointSqDist = length
        end 
    end
    return closestIndex
end

local kNextAiPathPointRange = 1.75
local kNextAiPathPointReachedRange = 0.33

// Find the next navigation point
// call after self:CheckTarget()!
// returns location of next point or nil when no active path
function BotAI_PathMixin:FindNextAIPathPoint()

	// destination has already been reached, see below
	if (self.pathPointIndex < 0) then
		return self.currentDst
	end

	local playerPos = self:GetPlayer():GetOrigin()
	local distance = (self:CurrentAIPathPoint() - playerPos):GetLengthXZ()
	
	// current path point not reached yet
	if (distance > kNextAiPathPointReachedRange) then
		return self:CurrentAIPathPoint()
	end

    // OLD: local nextIndex = self:FindClosestAIPathPoint(playerPos)
	local nextIndex = self.pathPointIndex
    local nextPoint = self.pathPoints[nextIndex]
    
    while (nextPoint ~= nil) do
    
        // calculate and check distance
        local ptDir = playerPos - nextPoint
        local ptLength = ptDir:GetLengthXZ()
        
        if (ptLength >= kNextAiPathPointRange) then
            self.pathPointIndex = nextIndex
            return nextPoint
        end
        
        // move to next path point
        nextIndex = nextIndex + 1
        nextPoint = self.pathPoints[nextIndex]
    end
    
	// destination reached, return destination
	self.pathPointIndex = -1
	return self.currentDst
end

function BotAI_PathMixin:DrawAIPath(duration)

    if self:IsAIPathValid() then
    
        for _,p in ipairs(self.pathPoints) do
            if lst then
                DebugLine(lst, p, duration, 1, 0, 0, 1)
                DebugLine(p, p - Vector.yAxis, duration, 0, 0, 1, 1)
            end
            lst = p
        end
        
    end
end