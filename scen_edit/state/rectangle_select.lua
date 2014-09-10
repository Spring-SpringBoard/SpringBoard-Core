RectangleSelectState = AbstractState:extends{}

function RectangleSelectState:init(startScreenX, startScreenZ)
    local _, coords1 = Spring.TraceScreenRay(startScreenX, startScreenZ, true, false, true)
    self.startWorldX, self.startWorldY, self.startWorldZ = unpack(coords1)
    self.endScreenX = nil
    self.endScreenZ = nil
end

function RectangleSelectState:enterState()
    SCEN_EDIT.view.selected = nil
end

function RectangleSelectState:leaveState()
end

function RectangleSelectState:MousePress(x, y, button)
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

        local unitIds = self:GetUnitsInScreenRectangle(startScreenX, startScreenZ, self.endScreenX, self.endScreenZ)
        local featureIds = self:GetFeaturesInScreenRectangle(startScreenX, startScreenZ, self.endScreenX, self.endScreenZ)
        if #unitIds > 0 then
            SCEN_EDIT.view.selectionManager:SelectUnits(unitIds)
        elseif #featureIds > 0 then
            SCEN_EDIT.view.selectionManager:SelectFeatures(featureIds)
        end
    end
    SCEN_EDIT.stateManager:SetState(DefaultState())
end

local function sort(v1, v2)
	if v1 > v2 then
		return v2, v1
	else
		return v1, v2
	end
end

function RectangleSelectState:GetUnitsInScreenRectangle(x1, y1, x2, y2, team)
	local units
	if (team) then
		units = Spring.GetTeamUnits(team)
	else
		units = Spring.GetAllUnits()
	end
	
	local left, right = sort(x1, x2)
	local bottom, top = sort(y1, y2)

	local result = {}

	for i=1, #units do
		local uid = units[i]
		x, y, z = Spring.GetUnitPosition(uid)
		x, y = Spring.WorldToScreenCoords(x, y, z)
		if (left <= x and x <= right) and (top >= y and y >= bottom) then
			result[#result+1] = uid
		end
	end
	return result
end

function RectangleSelectState:GetFeaturesInScreenRectangle(x1, y1, x2, y2, team)
	local features
	if (team) then
		features = Spring.GetTeamFeatures(team)
	else
		features = Spring.GetAllFeatures()
	end
	
	local left, right = sort(x1, x2)
	local bottom, top = sort(y1, y2)

	local result = {}

	for i=1, #features do
		local uid = features[i]
		local x, y, z = Spring.GetFeaturePosition(uid)
		local x, y = Spring.WorldToScreenCoords(x, y, z)
		if (left <= x and x <= right) and (top >= y and y >= bottom) then
			result[#result+1] = uid
		end
	end
	return result
end

function RectangleSelectState:KeyPress(key, mods, isRepeat, label, unicode)
end

function RectangleSelectState:DrawScreen()
    -- we actually don't need to draw anything since that's being done by the engine's default selection
    --[[
    if self.endScreenX and self.endScreenZ then
		local x1, z1 = Spring.WorldToScreenCoords(self.startWorldX, self.startWorldY, self.startWorldZ)
        local x2, z2 = self.endScreenX, self.endScreenZ
        gl.BeginEnd(GL.LINE_LOOP,
            function()
                gl.Vertex(x1, z1)
                gl.Vertex(x1, z2)
                gl.Vertex(x2, z2)
                gl.Vertex(x2, z1)
                gl.Vertex(x1, z1)
            end
        )
    end
    --]]
end
