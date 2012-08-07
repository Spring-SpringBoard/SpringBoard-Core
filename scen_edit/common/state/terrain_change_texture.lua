TerrainChangeTextureState = AbstractState:extends{}

function TerrainChangeTextureState:init()
    self.size = 100
end

function TerrainChangeTextureState:SetTexture(x, y, textureName)
    local succ = Spring.SetMapSquareTexture(x - self.size / 2, y - self.size / 2, textureName)
--    local succ = Spring.SetMapSquareTexture(0, 0, "")--textureName)
    Spring.Echo(succ)
end

function TerrainChangeTextureState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            local textureName = SCEN_EDIT.view.textureManager:GetRandomTexture()
            Spring.Echo(textureName)
            self:SetTexture(coords[1], coords[3], textureName) 
          --  local cmd = TerrainChangeTextureCommand(coords[1] - 20, coords[3] - 20, coords[1] + 20, coords[3] + 20, 1)
          --  SCEN_EDIT.commandManager:execute(cmd)
            return true
        end
    elseif button == 3 then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function TerrainChangeTextureState:MouseMove(x, y, dx, dy, button)
end

function TerrainChangeTextureState:MouseRelease(x, y, button)
end

function TerrainChangeTextureState:KeyPress(key, mods, isRepeat, label, unicode)
end

function TerrainChangeTextureState:DrawWorld()
	x, y = Spring.GetMouseState()
	local result, coords = Spring.TraceScreenRay(x, y, true)
	if result == "ground" then
		local x, z = coords[1], coords[3]
		local startX, startZ = x - 20, z - 20
		local endX, endZ = x + 20, z + 20
		gl.PushMatrix()
        currentState = SCEN_EDIT.stateManager:GetCurrentState()
        gl.Color(0, 255, 0, 0.3)
		SCEN_EDIT.view:drawRect(startX, startZ, endX, endZ) 
		gl.PopMatrix()
	end
end
