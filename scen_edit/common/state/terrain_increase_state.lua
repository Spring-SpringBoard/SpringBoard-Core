TerrainIncreaseState = AbstractState:extends{}

function TerrainIncreaseState:init()
end

function TerrainIncreaseState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            local cmd = TerrainIncreaseCommand(coords[1] - 20, coords[3] - 20, coords[1] + 20, coords[3] + 20, 20)
            SCEN_EDIT.commandManager:execute(cmd)
            return true
        end
    elseif button == 3 then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function TerrainIncreaseState:MouseMove(x, y, dx, dy, button)
end

function TerrainIncreaseState:MouseRelease(x, y, button)
end

function TerrainIncreaseState:KeyPress(key, mods, isRepeat, label, unicode)
end

function TerrainIncreaseState:DrawWorld()
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
