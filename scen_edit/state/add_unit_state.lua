AddUnitState = AbstractEditingState:extends{}

function AddUnitState:init(unitDef, teamId, unitImages, amount)
    self.unitDef = unitDef
    self.teamId = teamId
    self.unitImages = unitImages
    self.x, self.y, self.z = 0, 0, 0
    self.angle = 0
    self.amount = amount
    self.randomSeed = os.clock()
    self.mapGrid = MapGrid(100, 100)
    self.mapGrid.separatorSize = 2
end

function AddUnitState:enterState()
end

function AddUnitState:leaveState()
end

function AddUnitState:MousePress(x, y, button)
    if button == 1 then
        local result, coords = Spring.TraceScreenRay(x, y, true)
        if result == "ground" then
            self.x, self.y, self.z = unpack(coords)
            self.x, self.z = self.mapGrid:GetGridPosition(self.x, self.z)
            self.y = Spring.GetGroundHeight(self.x, self.z)
            return true
        end
    elseif button == 3 then
        self.unitImages:SelectItem(0)
        SCEN_EDIT.stateManager:SetState(DefaultState())        
    end
end

function AddUnitState:MouseMove(x, y, dx, dy, button)
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
        local dx = coords[1] - self.x
        local dz = coords[3] - self.z

        local len = math.sqrt(dx * dx + dz * dz)
        if len > 10 then
            self.angle = math.atan2(dx / len, dz / len) / math.pi * 180
        end
    end
end

function AddUnitState:MouseRelease(x, y, button)
    local commands = {}
    math.randomseed(self.randomSeed)
    for i = 1, self.amount do
        local x, y, z = self.x, self.y, self.z
        if i ~= 1 then
            x = x + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
            z = z + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
        end
        local cmd = AddUnitCommand(self.unitDef, x, y, z, self.teamId, self.angle)
        commands[#commands + 1] = cmd
    end

    local compoundCommand = CompoundCommand(commands)
    
    SCEN_EDIT.commandManager:execute(compoundCommand)
    self.x, self.y, self.z = 0, 0, 0
    self.angle = 0
    self.randomSeed = os.clock()
    return true
end

function AddUnitState:KeyPress(key, mods, isRepeat, label, unicode)
    if self:super("KeyPress", key, mods, isRepeat, label, unicode) then
        return true
    end
end

function AddUnitState:DrawWorld()
    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)

    local unitSizeX = UnitDefs[self.unitDef].footprintX
    local unitSizeZ = UnitDefs[self.unitDef].footprintZ
    if unitSizeX == nil or unitSizeZ == nil then
        local dim = Spring.GetUnitDefDimensions(self.unitDef)
        unitSizeX = math.abs(dim.minx) + math.abs(dim.maxx)
        unitSizeZ = math.abs(dim.minz) + math.abs(dim.maxz)
    end
    if result == "ground" then

        local baseX, baseY, baseZ = unpack(coords)
        self.mapGrid.rows    = Game.mapSizeX / unitSizeX
        self.mapGrid.columns = Game.mapSizeZ / unitSizeZ
        local gridX, gridZ = self.mapGrid:GetGridPosition(baseX, baseZ)
        local gridY = Spring.GetGroundHeight(gridX, gridZ)
        local blocking = Spring.TestBuildOrder(self.unitDef, gridX, gridY, gridZ, 0)
        self.mapGrid:Draw(baseX, baseZ, blocking)
        math.randomseed(self.randomSeed)
        
        for i = 1, self.amount do
            local x, y, z = gridX, gridY, gridZ
            if self.x ~= 0 or self.y ~= 0 or self.z ~= 0 then
                x, y, z = self.x, self.y, self.z
            end
            if i ~= 1 then
                x = x + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
                z = z + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
            end
            gl.PushMatrix()

            gl.Translate(x, y, z)
            if self.x ~= 0 or self.y ~= 0 or self.z ~= 0 then
                gl.Rotate(self.angle, 0, 1, 0)
            end

            gl.Color(1, 1, 1, 0.8)
            gl.UnitShape(self.unitDef, self.teamId)
            gl.PopMatrix()
        end
    end
end
