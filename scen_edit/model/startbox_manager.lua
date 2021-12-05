StartBoxManager = Observable:extends{}

function StartBoxManager:init()
    self:super('init')
    self.boxIDCount = 0
	self.boxes = {}
	self.team = {}
end

local function smallbuild(tbl)
	local matrix = {}
	count = 1
	for i = 1, #tbl, 2 do
		value = {tbl[i], tbl[i+1]}
		matrix[count] = value
		value = {}
		count = count + 1
	end
	return matrix
end

local function build2d(bigtbl)
	local value = {}
	local matrixlist = {}
	for index, tbl in pairs(bigtbl) do
		local matrix = {}
		count = 1
		for i = 1, #tbl, 2 do
			value = {tbl[i], tbl[i+1]}
			matrix[count] = value
			value = {}
			count = count + 1
		end
		matrixlist[index] = matrix
	end
	return matrixlist
end

local function unbuild(matrix)
	local tbl = {}
		for i, j in pairs (matrix) do
			table.insert(tbl, matrix[i][1])
			table.insert(tbl, matrix[i][2])
		end
	return tbl
end

function StartBoxManager:addBox(box, boxID)
    if boxID == nil then
        boxID = self.boxIDCount + 1
    end
    self.boxIDCount = boxID
    self.boxes[boxID] = unbuild(box)
    self:callListeners("onBoxAdded", boxID)
    return boxID
end

function StartBoxManager:addMirroredBox(boxID)
	local sboxes = build2d(self.boxes)
	local sbox = sboxes[boxID]
	local areaNew = {}
	for i, j in pairs(sbox) do
		table.insert(areaNew, {Game.mapSizeX - sbox[i][1], Game.mapSizeZ - sbox[i][2]})
	end
	local ID = self.boxIDCount + 1
    self.boxIDCount = ID
    self.boxes[ID] = unbuild(areaNew)
    self:callListeners("onBoxAdded", boxID)
    return ID
end

function StartBoxManager:getStartBoxIDCount(boxID)
    if boxID == nil then
        boxID = self.boxIDCount + 1
    end
    self.boxIDCount = boxID
    return self.boxIDCount
end

function StartBoxManager:getBoxPos(boxID)
	local sboxes = build2d(self.boxes)
	local sbox = sboxes[boxID]
	local x, z = 0, 0
	for i, _ in pairs(sbox) do
		x = x + sbox[i][1]
		z = z + sbox[i][2]
	end
	x, z = x / #sbox, z / #sbox
	local y = Spring.GetGroundHeight(x, z)
	return {x = x, y = y, z = z}
end

function StartBoxManager:setBoxPos(boxID, value)
	local x, z = self:getBoxPos(boxID).x, self:getBoxPos(boxID).z
	local deltaX, deltaZ = value.x - x, value.z - z
	local sbox = build2d(self.boxes)[boxID]
	areaNew = {}
	for i, j in pairs(sbox) do
		table.insert(areaNew, {deltaX + sbox[i][1], deltaZ + sbox[i][2]})
	end
	areaNew = unbuild(areaNew)
	self.boxes[boxID] = areaNew
end

function StartBoxManager:getAllStartBoxes()
	local sboxes = build2d(self.boxes)
	return sboxes
end

function StartBoxManager:getAllRawStartBoxes()
	return self.boxes
end

function StartBoxManager:getAllStartBoxIDs()
    local startboxes = {}
    for boxID, box in pairs(self.boxes) do
		table.insert(startboxes, boxID)
    end
    return startboxes
end

function StartBoxManager:removeBox(boxID)
    if self.boxes[boxID] ~= nil then
        self.boxes[boxID] = nil
        self:callListeners("onBoxRemoved", boxID)
    end
end

function StartBoxManager:setTeam(boxID, teamID)
    if teamID then
		self.team[boxID] = teamID
        return teamID
    end
	self:callListeners("onBoxChange", boxID)
end

function StartBoxManager:getTeam(boxID)
	return self.team[boxID]
end

function StartBoxManager:getBox(boxID)
    return smallbuild(self.boxes[boxID])
end

local function DistSq(x1, z1, x2, z2)
	return (x1 - x2)*(x1 - x2) + (z1 - z2)*(z1 - z2)
end

function StartBoxManager:getBoxIn(x, z)
    local selected, dragDiffX, dragDiffZ
    for boxID, box in pairs(build2d(self.boxes)) do
        local pos = self:getBoxPos(boxID)
        if DistSq(pos.x, pos.z, x, z) < 2500 then
            selected = boxID
            dragDiffX = pos.x - x
            dragDiffZ = pos.z - z
        end
    end
    return selected, dragDiffX, dragDiffZ
end
------------------------------------------------
-- Listener definition
------------------------------------------------
StartBoxManagerListener = LCS.class.abstract{}

function StartBoxManagerListener:onBoxAdded(boxID)
end

function StartBoxManagerListener:onBoxRemoved(boxID)
end

function StartBoxManagerListener:onBoxChange(boxID, box)
end
------------------------------------------------
-- End listener definition
------------------------------------------------