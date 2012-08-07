TerrainIncreaseState = AbstractState:extends{}

function TerrainIncreaseState:init(toDecrease)
    self.size = 100
    self.strength = 1
    self.toDecrease = toDecrease
end

function TerrainIncreaseState:AlterTerrain(x, z, amount)
    local currentFrame = Spring.GetGameFrame()
    Spring.Echo(amount)
    if not self.lastChangeFrame or currentFrame - self.lastChangeFrame >= 0 then
        self.lastChangeFrame = currentFrame
        local cmd = TerrainIncreaseCommand(x - self.size, z - self.size, x + self.size, z + self.size, amount)
        SCEN_EDIT.commandManager:execute(cmd)
        return true
    end
end

function TerrainIncreaseState:MousePress(x, y, button)
    if button == 1 or button == 3 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground"  then
            local amount = self.strength
            if button == 3 then
                amount = -amount
            end
            self:AlterTerrain(coords[1], coords[3], amount)
        end
        return true
    end
end

function TerrainIncreaseState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    return true
end

function TerrainIncreaseState:MouseWheel(up, value)
    local _, ctrl = Spring.GetModKeyState()
    if ctrl then
        if up then
            self.size = self.size + self.size * 0.2 + 2
        else
            self.size = self.size - self.size * 0.2 - 2
        end
        self.size = math.min(1000, self.size)
        self.size = math.max(20, self.size)
        return true
    end
end

function TerrainIncreaseState:GameFrame(frameNum)
	local x, y, button1, _, button3 = Spring.GetMouseState()
    if button1 or button3 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            local amount = self.strength
            if button3 then
                amount = -amount
            end
            self:AlterTerrain(coords[1], coords[3], amount)
        end
    end
end

function TerrainIncreaseState:KeyPress(key, mods, isRepeat, label, unicode)
    if key == 27 then --KEYSYMS.ESC then
        SCEN_EDIT.stateManager:SetState(DefaultState())
    end
end

function TerrainIncreaseState:DrawWorld()
	x, y = Spring.GetMouseState()
	local result, coords = Spring.TraceScreenRay(x, y, true)
	if result == "ground" then
		local x, z = coords[1], coords[3]
		local startX, startZ = x - self.size, z - self.size
		local endX, endZ = x + self.size, z + self.size
		gl.PushMatrix()
        currentState = SCEN_EDIT.stateManager:GetCurrentState()
        gl.Color(0, 255, 0, 0.3)
		SCEN_EDIT.view:drawRect(startX, startZ, endX, endZ) 
		gl.PopMatrix()
	end
end
