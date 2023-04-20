ViewStartBoxState = AbstractState:extends{}

local box = {}
local dragID = nil

function ViewStartBoxState:init(editorView)
    AbstractState.init(self, editorView)
	self.params = {}
	self.params.box = {}
	self.ev = editorView
end

function ViewStartBoxState:enterState()
    AbstractState.enterState(self)
end

function ViewStartBoxState:leaveState()
    AbstractState.leaveState(self)

    SB.SetGlobalRenderingFunction(nil)
end

function ViewStartBoxState:MousePress(mx, my, button)
    if button == 1 then
		local result, coords = Spring.TraceScreenRay(mx, my, true)
		local x, z = coords[1], coords[3]
		if dragID then
			local pos = SB.model.startboxManager:setBoxPos(dragID, {x = coords[1], z = coords[3]})
			SB.SetMouseCursor()
			dragID = nil
		else 
			dragID = SB.model.startboxManager:getBoxIn(x, z)
		end
		if dragID then SB.SetMouseCursor ("drag") end
    elseif button == 3 then
		local result, coords = Spring.TraceScreenRay(mx, my, true)
		local x, z = coords[1], coords[3]
		local ID = SB.model.startboxManager:getBoxIn(x, z)
        if ID then 
			SB.model.startboxManager:removeBox(ID)
			self.ev:Populate()
		end
    end
end

function ViewStartBoxState:MouseMove(mx, my, button)
end
	
function ViewStartBoxState:MouseRelease(mx, my, button)
    if button == 1 then
		local result, coords = Spring.TraceScreenRay(mx, my, true)
		if dragID then
			local pos = SB.model.startboxManager:setBoxPos(dragID, {x = coords[1], z = coords[3]})
			dragID = nil
		end
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

local function cross_product(px, pz, ax, az, bx, bz)
	return ((px - bx)*(az - bz) - (ax - bx)*(pz - bz))
end

local function triangulate(polies)
	local triangles = {}
	for ID, box in pairs(polies) do
		local polygon = box

		-- find out clockwisdom
		polygon[#polygon+1] = polygon[1]
		local clockwise = 0
		for i = 2, #polygon do
			clockwise = clockwise + (polygon[i-1][1] * polygon[i][2]) - (polygon[i-1][2] * polygon[i][1])
		end
		polygon[#polygon] = nil
		clockwise = (clockwise < 0)

		-- the van gogh concave polygon triangulation algorithm: cuts off ears
		-- is pretty shitty at O(V^3) but was easy to code and it's typically only done once anyway
		while (#polygon > 2) do

			-- get a candidate ear
			local triangle
			local c0, c1, c2 = 0
			local candidate_ok = false
			while not candidate_ok do

				c0 = c0 + 1
				c1, c2 = c0+1, c0+2
				if c1 > #polygon then c1 = c1 - #polygon end
				if c2 > #polygon then c2 = c2 - #polygon end
				triangle = {
					polygon[c0][1], polygon[c0][2],
					polygon[c1][1], polygon[c1][2],
					polygon[c2][1], polygon[c2][2],
				}

				-- make sure the ear is of proper rotation but then make it counter-clockwise
				local dir = cross_product(triangle[5], triangle[6], triangle[1], triangle[2], triangle[3], triangle[4])
				if ((dir < 0) == clockwise) then
					if dir > 0 then
						local temp = triangle[5]
						triangle[5] = triangle[3]
						triangle[3] = temp
						temp = triangle[6]
						triangle[6] = triangle[4]
						triangle[4] = temp
					end

					-- check if no point lies inside the triangle
					candidate_ok = true
					for i = 1, #polygon do
						if (i ~= c0 and i ~= c1 and i ~= c2) then
							local current_pt = polygon[i]
							if  (cross_product(current_pt[1], current_pt[2], triangle[1], triangle[2], triangle[3], triangle[4]) < 0)
							and (cross_product(current_pt[1], current_pt[2], triangle[3], triangle[4], triangle[5], triangle[6]) < 0)
							and (cross_product(current_pt[1], current_pt[2], triangle[5], triangle[6], triangle[1], triangle[2]) < 0)
							then
								candidate_ok = false
							end
						end
					end
				end
			end

			-- cut off ear
			triangles[#triangles+1] = triangle
			table.remove(polygon, c1)
		end
	end
	return triangles
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

function DrawText(boxID)
	local center = SB.model.startboxManager:getBoxPos(boxID)
    local y = Spring.GetGroundHeight(center.x, center.z)
    gl.PushMatrix()
        gl.Rotate(90, 1, 0, 0)
        local fontSize = 58
        local txt = tostring(boxID)
        local w = gl.GetTextWidth(txt) * fontSize
        local h = gl.GetTextHeight(txt) * fontSize
        gl.Translate(center.x-15, center.z+15, -y)
        gl.Color(1, 1, 1, 1)
        gl.Rotate(180, 0, 0, 1)
        gl.Scale(-1, 1, 1)
        gl.Text(txt, 0, 0, fontSize)
    gl.PopMatrix()
    gl.PushMatrix()
		local x1, z1, x2, z2 = center.x - 40, center.z - 40, center.x + 40, center.z + 40
        local bt = 4
        gl.Color(1, 1, 1, 0.7)
        gl.Utilities.DrawGroundRectangle(x1-bt, z1-bt, x1, z2+bt)
        gl.Utilities.DrawGroundRectangle(x2, z1-bt, x2+bt, z2+bt)
        gl.Utilities.DrawGroundRectangle(x1, z1-bt, x2, z1)
        gl.Utilities.DrawGroundRectangle(x1, z2, x2, z2+bt)
    gl.PopMatrix()
end

function ViewStartBoxState:DrawWorld()
	local startboxes = SB.model.startboxManager:getAllStartBoxes()
	local triboxes = triangulate(startboxes)
	for ID, _ in pairs(startboxes) do
		DrawText(ID)
	end
	for _, box in pairs(triboxes) do
		gl.PushMatrix()
			gl.DepthTest(true)
			gl.Color(0,1,0,0.2)
			gl.Utilities.DrawGroundTriangle(box)
		gl.PopMatrix()
	end
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
end