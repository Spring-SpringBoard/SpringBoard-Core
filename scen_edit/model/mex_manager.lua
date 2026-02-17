MexManager = Observable:extends{}

function MexManager:init()
    self:super('init')
    self.mexIDCount = 0
    self.mexes = {}
end

function MexManager:addMex(mex, mexID)
    if mexID == nil then
        mexID = self.mexIDCount + 1
    end
    self.mexIDCount = mexID
	if mex.xmirror == nil then
		mex.xmirror, mex.zmirror = false, false
	end
    self.mexes[mexID] = mex
    self:callListeners("onMexAdded", mexID, mex)
    return mexID
end

function MexManager:getMexIDCount(mexID)
    if mexID == nil then
        mexID = self.mexIDCount + 1
    end
    self.mexIDCount = mexID
    return self.mexIDCount
end

function MexManager:getAllMexes()
	local metalspots = {}
	for mexID, mex in pairs(self.mexes) do
		metalspots[mexID] = mex
    end
	return metalspots
end

function MexManager:getAllMexIDs()
    local metalspots = {}
    for mexID, mex in pairs(self.mexes) do
		table.insert(metalspots, mexID)
    end
    return metalspots
end

function MexManager:removeMex(mexID)
    if self.mexes[mexID] ~= nil then
		local mex = self.mexes[mexID]
        self.mexes[mexID] = nil
        self:callListeners("onMexRemoved", mexID, mex)
    end
end

function MexManager:setMex(mexID, partialObject)
    assert(self.mexes[mexID])
	local obj = partialObject
	local partialmex = {}
	for key, _ in pairs(self.mexes[mexID]) do
		if obj[key] ~= nil then
			partialmex[key] = self.mexes[mexID][key]
			self.mexes[mexID][key] = obj[key]
		end
	end
    self:callListeners("onMexChange", mexID, partialmex)
end

function MexManager:getMex(mexID)
    return self.mexes[mexID]
end
-- Utility functions
local function DistSq(x1, z1, x2, z2)
	return (x1 - x2)*(x1 - x2) + (z1 - z2)*(z1 - z2)
end

function MexManager:getMexIn(x, z)
	local x2, z2 = x, z
    local selected, dragDiffX, dragDiffZ
    for mexID, mex in pairs(self.mexes) do
		local xpos, zpos = mex.x, mex.z
        if DistSq(xpos, zpos, x2, z2) < 1600 then
            selected = mexID
            dragDiffX = mex.x - x2
            dragDiffZ = mex.z - z2
        end
    end
    return selected, dragDiffX, dragDiffZ
end

function MexManager:getPos(mexID)
	assert(self.mexes[mexID])
	local y = Spring.GetGroundHeight(self.mexes[mexID].x, self.mexes[mexID].z)
	return {x = self.mexes[mexID].x,y = y, z = self.mexes[mexID].z}
end
------------------------------------------------
-- Listener definition
------------------------------------------------
MexManagerListener = LCS.class.abstract{}

function MexManagerListener:onMexAdded(mexID, mex)
end

function MexManagerListener:onMexRemoved(mexID, mex)
end

function MexManagerListener:onMexChange(mexID, partmex, partobj)
end
------------------------------------------------
-- End listener definition
------------------------------------------------
