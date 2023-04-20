AddMetalState = AbstractState:extends{}

function AddMetalState:init(editorView)
    AbstractState.init(self, editorView)
	self.params = {}
	self.params.metal = editorView.fields["defaultmetal"].value
	self.params.xmirror = editorView.fields["defaultxmirror"].value
	self.params.zmirror = editorView.fields["defaultzmirror"].value
    self.params.x, self.params.z = 0, 0
	self.ev = editorView
end

function AddMetalState:enterState()
	AbstractState.enterState(self)
end

function AddMetalState:leaveState()
    AbstractState.leaveState(self)
end

function AddMetalState:MousePress(mx, my, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(mx, my, true)
        if result == "ground" then
            self.params.x, _, self.params.z = math.floor(coords[1]), coords[2], math.floor(coords[3])
			local objectID = SB.model.mexManager:addMex(self.params)
            return true
        end
    elseif button == 3 then
        SB.stateManager:SetState(ViewMetalState(self.ev))
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

function AddMetalState:DrawWorld()
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

function AddMetalState:MouseRelease(...)
	SB.stateManager:SetState(ViewMetalState(self.ev))
end