AddStartBoxState = AbstractState:extends{}

function AddStartBoxState:init(editorView)
    AbstractState.init(self, editorView)
	self.params = {}
	self.lines = {}
	self.params.box = {}
	self.ev = editorView
end

function AddStartBoxState:enterState()
    AbstractState.enterState(self)

    SB.SetGlobalRenderingFunction(function(...)
        self:__DrawInfo(...)
    end)
end

function AddStartBoxState:leaveState()
    AbstractState.leaveState(self)

    SB.SetGlobalRenderingFunction(nil)
end

local function DistSq(x1, z1, x2, z2)
	return (x1 - x2)*(x1 - x2) + (z1 - z2)*(z1 - z2)
end

local function GetBoundedLineIntersection(line1, line2)
	local x1, y1, x2, y2 = line1[1][1], line1[1][2], line1[2][1], line1[2][2]
	local x3, y3, x4, y4 = line2[1][1], line2[1][2], line2[2][1], line2[2][2]
	
	local denominator = ((x1 - x2)*(y3 - y4) - (y1 - y2)*(x3 - x4))
	if denominator == 0 then
		return false
	end
	local first = ((x1 - x3)*(y3 - y4) - (y1 - y3)*(x3 - x4))/denominator
	local second = -1*((x1 - x2)*(y1 - y3) - (y1 - y2)*(x1 - x3))/denominator
	
	if first < 0 or first > 1 or (second < 0 or second > 1) then
		return false
	end
	
	local px = x1 + first*(x2 - x1)
	local py = y1 + first*(y2 - y1)
	
	return {px, py}
end

local function AssessVertexValidity(lineList, activeLine)
	if #lineList == 0 then return true end
    for _, line in pairs(lineList) do
		if next(lineList,_) == nil then
			for _, j in pairs(line) do
				if DistSq(activeLine[1][1], activeLine[1][2], j[1], j[2]) < 1 then
					return false
				else
					return true
				end
			end
		end
		if GetBoundedLineIntersection(line, activeLine) then
			return false
		end
    end
	return true
end

function AddStartBoxState:MousePress(mx, my, button)
    if button == 1 then
		self.params.box = self.params.box or {}
        local result, coords = Spring.TraceScreenRay(mx, my, true)
        if result == "ground" then
            self.params.x, _, self.params.z = math.floor(coords[1]), coords[2], math.floor(coords[3])
			if #self.params.box > 2 then
				if DistSq(self.params.box[1][1], self.params.box[1][2], coords[1], coords[3]) < 400 then
					local ID = SB.model.startboxManager:addBox(self.params.box)
					SB.stateManager:SetState(ViewStartBoxState(self.ev))
					return true
				end
			end
			if #self.params.box ~= 0 then
				local line = {self.params.box[#self.params.box],{coords[1], coords[3]}}
				if #self.lines ~= 0 then
					if not AssessVertexValidity(self.lines, line) then
						return false
					end
				end
				table.insert(self.lines, line)
			end
			table.insert(self.params.box, {coords[1], coords[3]})
        end
    elseif button == 3 then
        SB.stateManager:SetState(ViewStartBoxState(self.ev))
    end
end

function AddStartBoxState:MouseMove(...)
end

function AddStartBoxState:MouseRelease(...)
end

local function DrawFirstPoint(x,z)
	gl.PushMatrix()
		gl.DepthTest(true)
		gl.Color(.8, .8, .8, .9)
		gl.LineWidth(6)
		gl.DrawGroundCircle(x, 1, z, 10, 21)
		gl.Color(1, 1, 1, 1)
	gl.PopMatrix()
end

local function MakeTriLine(line)
	local x, z, x0, z0 = line[1][1], line[1][2], line[2][1], line[2][2]
	local dist = math.sqrt(DistSq(x, z, x0, z0))
	local xslope, zslope = (x0 - x), (z0 - z)
	local x1, z1 = x + (zslope*3/dist), z - (xslope*3/dist)
	local x2, z2 = x - (zslope*3/dist), z + (xslope*3/dist)
	local x3, z3 = x0 + (zslope*3/dist), z0 - (xslope*3/dist)
	local x4, z4 = x0 - (zslope*3/dist), z0 + (xslope*3/dist)
	return {{x1, z1, x2, z2, x3, z3}, {x2, z2, x3, z3, x4, z4}}
end

local function DrawLine(line, alpha, isNotValid)
	local x1, z1, x2, z2 = line[1][1], line[1][2], line[2][1], line[2][2]
	local r, g = 0, 1
	if isNotValid then
		r, g = 1, 0 
	end
	if #line == 0 then return end
	local triline = MakeTriLine(line)
	for _, triangle in pairs(triline) do
		gl.PushMatrix()
			gl.Color(r, g, 0, alpha)
			gl.Utilities.DrawGroundTriangle(triangle)
		gl.PopMatrix()
	end
end

local function DrawSpot(x, z, metal, mirror)
	local y = 0
	local r, g, b = 0, 0, 0

	if mirror then r, g, b = 1, 1, 1 end
	
	local r2, g2, b2 = (r + 1) % 2, (g + 1)  % 2, (b + 1) % 2
	
	if x then y = Spring.GetGroundHeight(x,z) end
	if (y < 0  or y == nil) then y = 0 end
	gl.PushMatrix()
		gl.DepthTest(true)
		gl.Color(r,g,b,0.7)
		gl.LineWidth(6)
		gl.DrawGroundCircle(x, 1, z, 40, 21)
		gl.Color(r2,g2,b2,0.7)
		gl.LineWidth(2)
		gl.DrawGroundCircle(x, 1, z, 40, 21)
	gl.PopMatrix()
	gl.PushMatrix()
		gl.Translate(x, y, z)
		gl.Rotate(-90, 1, 0, 0)
		gl.Translate(0,-40, 0)
		gl.Text(metal, 0.0, 0.0, 40, "cno")
	gl.PopMatrix()
end

function AddStartBoxState:DrawWorld()
	for ID, params in pairs(SB.model.mexManager:getAllMexes()) do
		local x = params.x
		local z = params.z
		local metal = "+" .. string.format("%.2f", params.metal)
		DrawSpot(x, z, metal)
		if params.zmirror and params.xmirror then
			x = Game.mapSizeX-x
			z = Game.mapSizeZ-z
			DrawSpot(x, z, metal, true)
		elseif params.xmirror then
			x = Game.mapSizeX-x
			DrawSpot(x, z, metal, true)
		elseif params.zmirror then
			z = Game.mapSizeZ-z
			DrawSpot(x, z, metal, true)
		end
	end
	if (#self.params.box == 0) then return end
	DrawFirstPoint(self.params.box[1][1], self.params.box[1][2])
	local mx,my = Spring.GetMouseState()
	local result, coords = Spring.TraceScreenRay(mx, my, true)
	local activeLine ={{coords[1], coords[3]}, {self.params.box[#self.params.box][1], self.params.box[#self.params.box][2]}}
	local isNotValid = not AssessVertexValidity(self.lines, activeLine)
	DrawLine(activeLine, 0.2, isNotValid)
	if #self.lines ~= 0  then
		for _, line in pairs(self.lines) do
			DrawLine(line, 0.4)
		end
	end
end

function AddStartBoxState:__GetInfoText()
    return "Add StartBox"
end

local _displayColor = {1.0, 0.7, 0.1, 0.8}
function AddStartBoxState:__DrawInfo()
    if not self.__displayFont then
        self.__displayFont = Chili.Font:New {
            size = 12,
            color = _displayColor,
            outline = true,
        }
    end

    local mx, my, _, _, _, outsideSpring = Spring.GetMouseState()
    -- Don't draw if outside Spring
    if outsideSpring then
        return true
    end

    local _, vsy = Spring.GetViewGeometry()

    local x = mx
    local y = vsy - my - 30
    self.__displayFont:Draw(self:__GetInfoText(), x, y)

    -- return true to keep redrawing
    return true
end