SB.Include(Path.Join(SB.DIRS.SRC, 'state/abstract_map_editing_state.lua'))

BrushObjectState = AbstractMapEditingState:extends{}

local waitList = {}
function BrushObjectState:init(bridge, editorView, objectDefIDs)
    AbstractMapEditingState.init(self, editorView)

    self.bridge = bridge

    self.objectDefIDs = objectDefIDs

    self.randomSeed = os.clock()

    self.spread  = self.editorView.fields["spread"].value
    self.noise   = self.editorView.fields["noise"].value
    self.team    = self.editorView.fields["team"].value
    for _, axis in pairs({"x", "y", "z"}) do
        local fieldMinName = "brushRot" .. axis .. "Min"
        local fieldMaxName = "brushRot" .. axis .. "Max"
        self[fieldMinName] = self.editorView.fields[fieldMinName].value
        self[fieldMaxName] = self.editorView.fields[fieldMaxName].value
    end

    self.applyDelay          = 0.1
    self.initialDelay        = 0
    self.tolerance           = 5
end

function BrushObjectState:GetApplyParams(x, z, button)
    return x, z, button
end

function BrushObjectState:FilterObject(objectID)
    local objectDefID = self.bridge.GetObjectDefID(objectID)
    local isApproved = false
    for _, approvedObjectDefID in pairs(self.objectDefIDs) do
        if approvedObjectDefID == objectDefID then
            isApproved = true
            break
        end
    end
    return isApproved
end

function sunflower(n, alpha)   --  example: n=500, alpha=2
    local b = math.floor(alpha * math.sqrt(n) + 0.5)      -- number of boundary points
    local phi = (math.sqrt(5)+1) / 2           -- golden ratio
    local points = {}
    for k = 1, n do
        local r = radius(k,n,b)
        local theta = 2 * math.pi * k / (phi * phi)
        table.insert(points, {r*math.cos(theta), r*math.sin(theta)})
    end
    return points
end

function radius(k, n, b)
    if k > n - b then
        return 1 -- put on the boundary
    else
        return math.sqrt(k-1/2)/math.sqrt(n-(b+1)/2)  -- apply square root
    end
end


function BrushObjectState:Apply(bx, bz, button)
    -- Create a temporary element in the waitList to store objects which are
    -- currently being added
    waitList["temp"] = { objects = {} }

    local existing = {}
    local radius = self.size * math.sqrt(2)
    for _, objectID in pairs(self.bridge.GetObjectsInCylinder(bx, bz, radius)) do
        if button == 3 or self:FilterObject(objectID) then
            table.insert(existing, objectID)
        end
    end
    math.randomseed(self.randomSeed)
    local commands = {}

    if button == 1 then
        if self.objectDefIDs and #self.objectDefIDs > 0 then
            local spread = self.spread * 100
            local spreadSqrt = math.sqrt(spread)
            local numPoints = math.ceil(self.size * self.size / spread)
            local points = sunflower(numPoints, 2)   --  example: n=500, alpha=2
            for i = 1, #points do
                local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]
                local x, z = bx + points[i][1] * radius/2, bz + points[i][2] * radius/2
                x, z = x + math.random() * self.noise - self.noise / 2, z + math.random() * self.noise - self.noise / 2
                x, z = math.max(0, math.min(Game.mapSizeX, x)), math.max(0, math.min(Game.mapSizeZ, z))
                if not self:CheckExisting(x, z, spreadSqrt - self.tolerance) then
                    local angles = {}
                    for _, axis in pairs({"x", "y", "z"}) do
                        local fieldMinName = "brushRot" .. axis .. "Min"
                        local fieldMaxName = "brushRot" .. axis .. "Max"
                        angles[axis] = math.random() * (self[fieldMaxName] - self[fieldMinName]) + self[fieldMinName]
                    end
                    local y = Spring.GetGroundHeight(x, z)
                    local cmd = AddObjectCommand(self.bridge.name, {
                        defName = objectDefID,
                        pos = { x = x, y = y, z = z },
                        rot = angles,
                        team = self.team,
                    })
                    commands[#commands + 1] = cmd
                    table.insert(waitList["temp"].objects, { x = x, y = y, z = z })
                end
            end
            self.randomSeed = os.clock()
        end
    elseif button == 3 then
        for i = 1, #existing do
            local cmd = RemoveObjectCommand(self.bridge.name,
            self.bridge.getObjectModelID(existing[i]))
            commands[#commands + 1] = cmd
        end
    end

    if #commands > 0 then
        local compoundCommand = CompoundCommand(commands)
        local cmdID = SB.commandManager:execute(compoundCommand)
        if button == 1 then
            waitList[cmdID] = waitList["temp"]
        end
    end
    self.randomSeed = self.randomSeed + os.clock()
    waitList["temp"] = nil
    return true
end

function BrushObjectState:CheckExisting(x, z, distance)
    for _, waitCmd in pairs(waitList) do
        local objects = waitCmd.objects
        for _, object in pairs(objects) do
            local dx, dz = object.x - x, object.z - z
            local d = (dx * dx) + (dz * dz)
            if d < 4 * distance * distance then
                return true
            end
        end
    end
    for _, objectID in pairs(self.bridge.GetObjectsInCylinder(x, z, distance)) do
        if self:FilterObject(objectID) then
            return true
        end
    end
    return false
end

function BrushObjectState:KeyPress(key, mods, isRepeat, label, unicode)
    if AbstractMapEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end
--     if key == 49 then -- 1
--         local newState = TerrainShapeModifyState(self.editorView)
--         if self.size then
--             newState.size = self.size
--         end
--         SB.stateManager:SetState(newState)
--     elseif key == 50 then -- 2
--         local newState = TerrainSmoothState(self.editorView)
--         if self.size then
--             newState.size = self.size
--         end
--         SB.stateManager:SetState(newState)
--     else
--         return false
--     end
    return false
end

function BrushObjectState:DrawObject(object, bridge, shaderObj)
    local objectDefID         = object.objectDefID
    local objectTeamID        = object.objectTeamID
    local pos                 = object.pos
    gl.Uniform(shaderObj.teamColorID, Spring.GetTeamColor(objectTeamID))
    bridge.DrawObject({
        color           = { r = 0.4, g = 1, b = 0.4, a = 0.8 },
        objectDefID     = objectDefID,
        objectTeamID    = objectTeamID,
        pos             = pos,
        angle           = { x = 0, y = 0, z = 0 },
    })
end

function BrushObjectState:DrawWorld()
    local mx, my = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(mx, my, true)
    if result ~= "ground" then
        return
    end
    local baseX, baseY, baseZ = unpack(coords)
    gl.PushMatrix()
    gl.Color(0, 1, 0, 0.3)
    --gl.DepthTest(true)
    gl.Utilities.DrawGroundCircle(baseX, baseZ, self.size)
    gl.PopMatrix()

    if not self.objectDefIDs or #self.objectDefIDs == 0 then
        return
    end
    math.randomseed(self.randomSeed)
    local objectDefID = self.objectDefIDs[1]
    --local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]

    gl.DepthTest(GL.LEQUAL)
    gl.DepthMask(true)
    local shaderObj = SB.view.modelShaders:GetShader()
    gl.UseShader(shaderObj.shader)
    gl.Uniform(shaderObj.timeID, os.clock())
    baseY = Spring.GetGroundHeight(baseX, baseZ)
    local object = {
        objectDefID = objectDefID,
        objectTeamID = self.team,
        pos = { x = baseX, y = baseY, z = baseZ },
    }
    self:DrawObject(object, self.bridge, shaderObj)
    gl.UseShader(0)
end

------------------------------------------------
-- Listener definition
------------------------------------------------
BrushCommandManagerListener = CommandManagerListener:extends{}

function BrushCommandManagerListener:OnCommandExecuted(cmdIDs, isUndo, isRedo)
    if not cmdIDs or isUndo or isRedo then
        return
    end

    local currentState = SB.stateManager:GetCurrentState()
    if currentState:is_A(BrushObjectState) then
        for _, cmdID in pairs(cmdIDs) do
            local waitCmd = waitList[cmdID]
            if waitCmd then
                waitList[cmdID] = nil
            end
        end
    end
end

brushCommandManagerListener = BrushCommandManagerListener()
SB.delay(function()
    SB.commandManager:addListener(brushCommandManagerListener)
end)
------------------------------------------------
-- End listener definition
------------------------------------------------
