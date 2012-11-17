//=============================================================================
//
// lua/BotAIPathMixin.lua
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

BotAIPathMixin = { }
BotAIPathMixin.type = "BotAIPath"

function BotAIPathMixin:__initmixin()
    self:ResetAIPath()
end

function BotAIPathMixin:ResetAIPath()
    self.pathPoints = nil
    self.pathDistance = nil
end

function BotAIPathMixin:IsAIPathValid()
    return (self.pathPoints ~= nil and #(self.pathPoints) > 0)
end

function BotAIPathMixin:RemainingAIPathPoint()
    return (#(self.pathPoints) - self.pathPointIndex)
end

function BotAIPathMixin:CurrentAIPathPoint()
    if self:IsAIPathValid() then
        //Print( "  point index " .. self.pathPointIndex )
        return self.pathPoints[self.pathPointIndex]
    else    
        return nil
    end
end

//Added by borsty
// Returns true when there's a path we can follow
function BotAIPathMixin:CheckTarget(src, dst)
    
    // destination already reached?
    if self:IsAIPathValid() then
    
		if (self.lastSrc == nil) then self.lastSrc = src end
	
        local targetDist = (self.lastSrc - src):GetLengthXZ()
        self.lastSrc = src
        
        if targetDist > 1 then
            //Print("CheckTarget - Path valid, Player probably teleported, generating for " .. self:GetPlayer():GetClassName() .. " distance to last pos being " .. targetDist)
            // build new path
            if self:CreateAIPath(src, dst) then
                self.targetPoint = dst
                return true
            end
            return false
        end
		
        targetDist = (src - dst):GetLengthXZ()
		
        if targetDist < 0.1 then
            //Print("CheckTarget - Path valid, Target reached for " .. self:GetPlayer():GetClassName() .. " distance to target being " .. targetDist)
            self.targetPoint = nil
            self:ResetAIPath()
            return false
        end
        
        
        targetDist = (self.targetPoint - dst):GetLengthXZ()
        
        if targetDist > 0.25 then
            //Print("CheckTarget - Path valid, different target, generating for " .. self:GetPlayer():GetClassName() .. " distance being " .. targetDist)
            // build new path
            if self:CreateAIPath(src, dst) then
                self.targetPoint = dst
                return true
            end
            return false
        end
    
        return true
    else
       
        //Print("CheckTarget - Path invalid, generating for " .. self:GetPlayer():GetClassName())
        
        // build new path
        if self:CreateAIPath(src, dst) then
            self.targetPoint = dst
            return true
        end
        
        return false
    end
end

function BotAIPathMixin:CreateAIPath(src, dst)

    if self:IsAIPathValid() then
        self:ResetAIPath()
    end
    
    // generate a new AI path
    self.pathPoints = GeneratePath(src, dst)    
    self.pathDistance = GetPointDistance(self.pathPoints)
    self.pathPointIndex = 1
    
    // draw path in 'dev' mode
    //if Shared.GetDevMode() and (self.pathPoints ~= nil) then
    //    self:DrawAIPath(10)
    //end
    
    return (self.pathPoints ~= nil)
end

function BotAIPathMixin:FindClosestAIPathPoint(location)

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

function BotAIPathMixin:FindNextAIPathPoint(location, range)

    local nextIndex = self:FindClosestAIPathPoint(location)
    local nextPoint = self.pathPoints[nextIndex]
    
    while (nextPoint ~= nil) do
    
        // calculate and check distance
        local ptDir = location - nextPoint
        local ptLength = ptDir:GetLength()
        
        if (ptLength >= range) then
            self.pathPointIndex = nextIndex
            return true
        end
        
        // move to next path point
        nextIndex = nextIndex + 1
        nextPoint = self.pathPoints[nextIndex]
    end
    
    // return to end of path if it's still in range
    if (nextIndex >= #(self.pathPoints)) then 
        self.pathPointIndex = #(self.pathPoints)
        return true
    end
    
    return false
end

function BotAIPathMixin:DrawAIPath(duration)

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