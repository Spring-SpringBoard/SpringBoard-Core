TerrainDecreaseState = AbstractState:extends{}

function TerrainDecreaseState:init()
end

function TerrainDecreaseState:AlterTerrain(x, z, amount)
    local currentFrame = Spring.GetGameFrame()
    if not self.lastChangeFrame or currentFrame - self.lastChangeFrame < 10 then
        self.lastChangeFrame = currentFrame
        local cmd = TerrainIncreaseCommand(x - 20, z - 20, x + 20, z + 20, amount)
        SCEN_EDIT.commandManager:execute(cmd)
        return true
    end
end

function TerrainDecreaseState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            self:AlterTerrain(coords[1], coords[3], -20)
        end
        return true
    elseif button == 3 then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function TerrainDecreaseState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground"  then
        self:AlterTerrain(coords[1], coords[3], -2)
        return true
    end
end

function TerrainDecreaseState:DrawWorld()
    x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local x, z = coords[1], coords[3]
        local startX, startZ = x - 20, z - 20
        local endX, endZ = x + 20, z + 20
        gl.PushMatrix()
        currentState = SCEN_EDIT.stateManager:GetCurrentState()
        gl.Color(255, 0, 0, 0.3)            
        SCEN_EDIT.view:drawRect(startX, startZ, endX, endZ) 
        gl.PopMatrix()
    end
end
