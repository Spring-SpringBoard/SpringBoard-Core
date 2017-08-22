RectangleSelectState = AbstractState:extends{}

function RectangleSelectState:init(startScreenX, startScreenZ)
    AbstractState.init(self)

    local _, coords1 = Spring.TraceScreenRay(startScreenX, startScreenZ, true, false, true)
    self.startWorldX, self.startWorldY, self.startWorldZ = unpack(coords1)
    self.endScreenX = nil
    self.endScreenZ = nil
    self.origSel = SB.view.selectionManager:GetSelection()
    SB.view.selectionManager.__disabledChange = true
end

function RectangleSelectState:Update()
	local x, y, pressed = Spring.GetMouseState()
    self:_MouseMove(x, y)
    if not pressed then
        self:_MouseRelease(x, y, button)
    end
end

function RectangleSelectState:_MouseMove(x, y)
    self.endScreenX = x
    self.endScreenZ = y
end

function RectangleSelectState:_MouseRelease(x, y, button)
    if self.endScreenX and self.endScreenZ then
        local startScreenX, startScreenZ = Spring.WorldToScreenCoords(self.startWorldX, self.startWorldY, self.startWorldZ)

        local selection = {}
        for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
            if bridge.s11n and bridge.s11n.GetAllObjectIDs then
                selection[name] = self:GetObjectsInScreenRectangle(
                    startScreenX, startScreenZ,
                    self.endScreenX, self.endScreenZ,
                    bridge
                )
            end
        end
        local _, _, _, shift = Spring.GetModKeyState()
        if shift then
            local result = {}
            for selType, _ in pairs(self.origSel) do
                local s1 = selection[selType]
                local s2 = self.origSel[selType]
                result[selType] = {}
                for _, objectID in pairs(s1) do
                    if not Table.Contains(s2, objectID) then
                        table.insert(result[selType], objectID)
                    end
                end
                for _, objectID in pairs(s2) do
                    if not Table.Contains(s1, objectID) then
                        table.insert(result[selType], objectID)
                    end
                end
            end
            selection = result
        end
        SB.view.selectionManager:Select(selection)
    end
    SB.view.selectionManager.__disabledChange = false
    SB.stateManager:SetState(DefaultState())
end

local function minMax(v1, v2)
	if v1 > v2 then
		return v2, v1
	else
		return v1, v2
	end
end

function RectangleSelectState:GetObjectsInScreenRectangle(x1, y1, x2, y2, bridge)
	local objectIDs = bridge.s11n:GetAllObjectIDs()

	local left, right = minMax(x1, x2)
	local bottom, top = minMax(y1, y2)

	local result = {}

	for _, objectID in pairs(objectIDs) do
		local pos = bridge.s11n:Get(objectID, "pos")
		x, y = Spring.WorldToScreenCoords(pos.x, pos.y, pos.z)
		if left <= x and x <= right and
           top >= y and y >= bottom then
            table.insert(result, objectID)
		end
	end
	return result
end
