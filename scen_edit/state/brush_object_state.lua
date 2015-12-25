SCEN_EDIT.Include("scen_edit/state/abstract_map_editing_state.lua")
BrushObjectState = AbstractMapEditingState:extends{}

function BrushObjectState:init(editorView, objectDefIDs)
    AbstractMapEditingState.init(self, editorView)

    self.objectDefIDs = objectDefIDs
    self.randomSeed = os.clock()

    self.amount  = self.editorView.fields["amount"].value
    self.team    = self.editorView.fields["team"].value

    self.applyDelay          = 0.1
    self.initialDelay        = 0
end

function BrushObjectState:GetApplyParams(x, z, button)
	return x, z, button
end

function BrushObjectState:FilterObject(objectID)
    local objectDefID = self.bridge.spGetObjectDefID(objectID)
    local isApproved = false
    for _, approvedObjectDefID in pairs(self.objectDefIDs) do
        if approvedObjectDefID == objectDefID then
            isApproved = true
            break
        end
    end
    return isApproved
end

function BrushObjectState:Apply(bx, bz, button)
    local size = self.size / 2
    local existing = {}
    for _, objectID in pairs(self.bridge.spGetObjectsInCylinder(bx, bz, size * math.sqrt(2))) do
        if button == 3 or self:FilterObject(objectID) then
            table.insert(existing, objectID)
        end
    end
    local commands = {}
    if button == 1 then
        local area = size * size
        local desired = area / 100 / 100 * self.amount -- self.amount
        desired = math.max(1, math.floor(desired))
        for i = #existing+1, desired do
            local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]

            local t = 2 * math.pi * math.random()
            local r = math.sqrt(math.random()) * self.size
            local dx, dz = r * math.cos(t), r * math.sin(t)
            x = bx + dx
            z = bz + dz
            y = Spring.GetGroundHeight(x, z)
            local angle = math.random() * 360
            local cmd = self.bridge.AddObjectCommand(objectDefID, x, y, z, self.team, angle)
            commands[#commands + 1] = cmd
        end
        self.randomSeed = os.clock()
    elseif button == 3 then
        for i = 1, #existing do
            local cmd = self.bridge.RemoveObjectCommand(existing[i])
            commands[#commands + 1] = cmd
        end
    end

    if #commands > 0 then
        local compoundCommand = CompoundCommand(commands)
        SCEN_EDIT.commandManager:execute(compoundCommand)
    end
    return true
end

function BrushObjectState:KeyPress(key, mods, isRepeat, label, unicode)
    -- FIXME: cannot use "super" here in the current version of LCS and the new version is broken
    if AbstractMapEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end
--     if key == 49 then -- 1
--         local newState = TerrainShapeModifyState(self.editorView)
--         if self.size then
--             newState.size = self.size
--         end
--         SCEN_EDIT.stateManager:SetState(newState)
--     elseif key == 50 then -- 2
--         local newState = TerrainSmoothState(self.editorView)
--         if self.size then
--             newState.size = self.size
--         end
--         SCEN_EDIT.stateManager:SetState(newState)
--     else
--         return false
--     end
    return false
end

function BrushObjectState:DrawWorld()
    if not self.objectDefIDs or #self.objectDefIDs == 0 then
        return
    end
    --math.randomseed(self.randomSeed)
    local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]

    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result == "ground" then
--         local feature = FeatureDefs[objectDefID]
--         local drawFeature = feature.drawType
--         if drawFeature == 0 then
--             drawFeature = objectDefID
--         end

        local baseX, baseY, baseZ = unpack(coords)
        gl.PushMatrix()
        gl.Color(0, 1, 0, 0.3)
        --gl.DepthTest(true)
        gl.Utilities.DrawGroundCircle(baseX, baseZ, self.size)
        gl.PopMatrix()

        for i = 1, self.amount do
            local x, y, z = baseX, baseY, baseZ
            if i ~= 1 then
                x = x + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
                z = z + (math.random() - 0.5) * 100 * math.sqrt(self.amount)
            end
            y = Spring.GetGroundHeight(x, z)
            gl.PushMatrix()

            gl.Translate(x, y, z)

            self.bridge.DrawObject(objectDefID, self.team)
            gl.PopMatrix()
        end
    end
end

-- Custom unit/feature classes
BrushUnitState = BrushObjectState:extends{}
function BrushUnitState:init(...)
    BrushObjectState.init(self, ...)
    self.bridge = unitBridge
end

BrushFeatureState = BrushObjectState:extends{}
function BrushFeatureState:init(...)
    BrushObjectState.init(self, ...)
    self.bridge = featureBridge
end