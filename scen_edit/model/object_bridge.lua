SB_COMMAND_DIR = SB_DIR .. "command/"
SB.Include(SB_COMMAND_DIR .. 'command.lua')
SB.IncludeDir(SB_COMMAND_DIR)

SB_STATE_DIR = SB_DIR .. "state/"
SB.Include(SB_STATE_DIR .. 'state_manager.lua')
SB.Include(SB_STATE_DIR .. 'abstract_state.lua')
SB.Include(SB_STATE_DIR .. 'abstract_state.lua')
SB.IncludeDir(SB_STATE_DIR)

ObjectBridge = LCS.class.abstract{}
function ObjectBridge.getObjectSpringID(modelID)
    return modelID
end
function ObjectBridge.getObjectModelID(objectID)
    return objectID
end
function ObjectBridge.setObjectModelID(objectID, modelID)
end
function ObjectBridge.spValidObject(objectID)
    return true
end

local objectBridges = {}
function ObjectBridge.Register(name, objectBridge)
    objectBridge.name = name
    objectBridges[name] = objectBridge
end
function ObjectBridge.GetObjectBridges()
    return objectBridges
end
function ObjectBridge.GetObjectBridge(name)
    return objectBridges[name]
end

-- UNIT

function DrawObject(params, bridge)
    gl.PushMatrix()
    local pos           = params.pos
    local angle         = params.angle
    local objectDefID   = params.objectDefID
    local objectTeamID  = params.objectTeamID
    local color         = params.color
    gl.Color(color.r, color.g, color.b, color.a)
    gl.Translate(pos.x, pos.y, pos.z)
    gl.Rotate(angle.x, 1, 0, 0)
    gl.Rotate(angle.y, 0, 1, 0)
    gl.Rotate(angle.z, 0, 0, 1)
    bridge.glObjectShapeTextures(objectDefID, true)
    bridge.glObjectShape(objectDefID, objectTeamID, true)
    bridge.glObjectShapeTextures(objectDefID, false)
    gl.PopMatrix()
end

UnitBridge = ObjectBridge:extends{}
UnitBridge.humanName                       = "Unit"
UnitBridge.spGetObjectsInCylinder          = Spring.GetUnitsInCylinder
UnitBridge.spGetObjectDefID                = Spring.GetUnitDefID
UnitBridge.spGetObjectPosition             = Spring.GetUnitPosition
UnitBridge.spValidObject                   = Spring.ValidUnitID
UnitBridge.spGetObjectTeam                 = Spring.GetUnitTeam
UnitBridge.spGetObjectDirection            = Spring.GetUnitDirection
UnitBridge.spGetAllObjects                 = Spring.GetAllUnits
UnitBridge.spDestroyObject                 = Spring.DestroyUnit

UnitBridge.AddObjectCommand                = AddUnitCommand
UnitBridge.RemoveObjectCommand             = RemoveUnitCommand
UnitBridge.SetObjectParamCommand           = SetUnitParamCommand

UnitBridge.SelectObjectState               = SelectUnitState
UnitBridge.SelectObjectTypeState           = SelectUnitTypeState

UnitBridge.DrawObject                      = function(params)
    DrawObject(params, unitBridge)
end
UnitBridge.Select                          = function(objectIDs)
    SB.view.selectionManager:Select({
        unit = objectIDs
    })
end
UnitBridge.OnSelect                        = function(objectIDs)
    Spring.SelectUnitArray(objectIDs)
end

UnitBridge.getObjectSpringID               = function(modelID)
    return SB.model.unitManager:getSpringUnitID(modelID)
end
UnitBridge.getObjectModelID                = function(objectID)
    return SB.model.unitManager:getModelUnitID(objectID)
end
UnitBridge.setObjectModelID                = function(objectID, modelID)
    SB.model.unitManager:setUnitModelID(objectID, modelID)
end
unitBridge = UnitBridge()
unitBridge.s11n                            = s11n:GetUnitBridge()
unitBridge.ObjectDefs                      = UnitDefs
if gl then
    unitBridge.glObjectShape               = gl.UnitShape
    unitBridge.glObjectShapeTextures       = gl.UnitShapeTextures
end
ObjectBridge.Register("unit", unitBridge)

-- FEATURE

FeatureBridge = ObjectBridge:extends{}
FeatureBridge.humanName                       = "Feature"
FeatureBridge.spGetObjectsInCylinder          = Spring.GetFeaturesInCylinder
FeatureBridge.spGetObjectDefID                = Spring.GetFeatureDefID
FeatureBridge.spGetObjectPosition             = Spring.GetFeaturePosition
FeatureBridge.spValidObject                   = Spring.ValidFeatureID
FeatureBridge.spGetObjectTeam                 = Spring.GetFeatureTeam
FeatureBridge.spGetObjectDirection            = Spring.GetFeatureDirection
FeatureBridge.spGetAllObjects                 = Spring.GetAllFeatures
FeatureBridge.spDestroyObject                 = Spring.DestroyFeature

FeatureBridge.AddObjectCommand                = AddFeatureCommand
FeatureBridge.RemoveObjectCommand             = RemoveFeatureCommand
FeatureBridge.SetObjectParamCommand           = SetFeatureParamCommand

FeatureBridge.SelectObjectState               = SelectFeatureState
FeatureBridge.SelectObjectTypeState           = SelectFeatureTypeState

FeatureBridge.DrawObject                      = function(params)
    DrawObject(params, featureBridge)
--     local featureDef    = FeatureDefs[objectDefID]
--
--     if featureDef.drawType ~= 0 then
--         Log.Warning("engine-tree, not sure what to do")
--     end
end
-- we cache minx, maxx, minz, maxz for each feature def
-- this saves us a lot of memory
local __cachedDefs = {}
local function _GetFeatureDefSize(featureDefID)
    if __cachedDefs[featureDefID] == nil then
        local featureDef = FeatureDefs[featureDefID]
        local minx, maxx = featureDef.model.minx or -10, featureDef.model.maxx or 10
        local minz, maxz = featureDef.model.minz or -10, featureDef.model.maxz or 10
        if maxx - minx < 20 then
            minx, maxx = -10, 10
        end
        if maxz - minz < 20 then
            minz, maxz = -10, 10
        end
        __cachedDefs[featureDefID] = {minx, maxx, minz, maxz}
    end
    local c = __cachedDefs[featureDefID]
    return c[1], c[2], c[3], c[4]
end

local function DrawLines(x1, x2, z1, z2, by)
    gl.Vertex(x1, by, z1)
    gl.Vertex(x2, by, z1)
    gl.Vertex(x2, by, z2)
    gl.Vertex(x1, by, z2)
    gl.Vertex(x1, by, z1)
end
FeatureBridge.DrawSelected                    = function(objectID)
    local bx, by, bz = Spring.GetFeaturePosition(objectID)
    local minx, maxx, minz, maxz = _GetFeatureDefSize(Spring.GetFeatureDefID(objectID))
    local x1, z1 = bx + minx - 5, bz + minz + 5
    local x2, z2 = bx + maxx - 5, bz + maxz + 5
    gl.BeginEnd(GL.LINE_STRIP, DrawLines, x1, x2, z1, z2, by)
end
FeatureBridge.Select                          = function(objectIDs)
    SB.view.selectionManager:Select({
        feature = objectIDs
    })
end

FeatureBridge.getObjectSpringID               = function(modelID)
    return SB.model.featureManager:getSpringFeatureID(modelID)
end
FeatureBridge.getObjectModelID                = function(objectID)
    return SB.model.featureManager:getModelFeatureID(objectID)
end
FeatureBridge.setObjectModelID                = function(objectID, modelID)
    SB.model.featureManager:setFeatureModelID(objectID, modelID)
end
featureBridge = FeatureBridge()
featureBridge.s11n                            = s11n:GetFeatureBridge()
featureBridge.ObjectDefs                      = FeatureDefs
if gl then
    featureBridge.glObjectShape               = gl.FeatureShape
    featureBridge.glObjectShapeTextures       = gl.FeatureShapeTextures
end
ObjectBridge.Register("feature", featureBridge)

-- AREA

local function __CheckResizeIntersections(areaID, x, z)
    local rect = SB.model.areaManager:getArea(areaID)
    local accuracy = 20
    local toResize = false
    local resx, resz = 0, 0
    if math.abs(x - rect[1]) < accuracy then
        resx = -1
        drag_diff_x = rect[1] - x
        toResize = true
        if z > rect[2] + accuracy and z < rect[4] - accuracy then
            resz = 0
        elseif math.abs(rect[2] - z) < accuracy then
            drag_diff_z = rect[2] - z
            resz = -1
        elseif math.abs(rect[4] - z) < accuracy then
            drag_diff_z = rect[4] - z
            resz = 1
        else
            toResize = false
        end
    elseif math.abs(x - rect[3]) < accuracy then
        resx = 1
        drag_diff_x = rect[3] - x
        toResize = true
        if z > rect[2] + accuracy and z < rect[4] - accuracy then
            resz = 0
        elseif math.abs(rect[2] - z) < accuracy then
            drag_diff_z = rect[2] - z
            resz = -1
        elseif math.abs(rect[4] - z) < accuracy then
            drag_diff_z = rect[4] - z
            resz = 1
        else
            toResize = false
        end
    elseif math.abs(z - rect[2]) < accuracy then
        resx = 0
        resz = -1
        drag_diff_z = rect[2] - z
        if x > rect[1] + accuracy and x < rect[3] + accuracy then
            toResize = true
        else
            toResize = false
        end
    elseif math.abs(z - rect[4]) < accuracy then
        resx = 0
        resz = 1
        drag_diff_z = rect[4] - z
        if x > rect[1] + accuracy and x < rect[3] + accuracy then
            toResize = true
        else
            toResize = false
        end
    end
    return toResize, resx, resz
end

local function __MakeAreaTrigger(areaID)
    local trigger = {
        name = "Enter area " .. areaID,
        enabled = true,
        actions = {},
        events = {
            {
                typeName = "UNIT_ENTER_AREA",
            },
        },
        conditions = {
            {
                typeName = "compare_area",
                first = {
                    value = areaID,
                    type = "const",
                },
                relation = {
                    value = 1,
                    type = "const",
                },
                second = {
                    value = "area",
                    type = "scoped",
                },
            },
        },
    }
    return trigger
end

AreaBridge = ObjectBridge:extends{}
AreaBridge.humanName                    = "Area"
AreaBridge.NoHorizontalDrag             = true
AreaBridge.spGetObjectPosition          = function(objectID)
    local pos = SB.model.areaManager:getArea(objectID)
    local x, z = (pos[1] + pos[3]) / 2, (pos[2] + pos[4]) / 2
    local y = Spring.GetGroundHeight(x, z)
    return x, y, z
end
AreaBridge.spGetAllObjects              = function()
    return SB.model.areaManager:getAllAreas()
end
AreaBridge.spDestroyObject              = function(objectID)
    SB.model.areaManager:removeArea(objectID)
end
AreaBridge.spValidObject                = function(objectID)
    return SB.model.areaManager:getArea(objectID) ~= nil
end

AreaBridge.AddObjectCommand             = AddAreaCommand
AreaBridge.RemoveObjectCommand          = RemoveAreaCommand
AreaBridge.SetObjectParamCommand        = SetAreaParamCommand

AreaBridge.SelectObjectState            = SelectAreaState
AreaBridge.Select                       = function(objectIDs)
    SB.view.selectionManager:Select({
        area = objectIDs
    })
end
AreaBridge.OnSelect                     = function(objectIDs)
    for _, areaID in pairs(SB.model.areaManager:getAllAreas()) do
        SB.view.areaViews[areaID].selected = false
    end
    for _, areaID in pairs(objectIDs) do
        SB.view.areaViews[areaID].selected = true
    end
end
AreaBridge.DrawObject                   = function(objectID, obj)
    local x1, z1, x2, z2
    if objectID then
        x1, z1, x2, z2 = unpack(SB.model.areaManager:getArea(objectID))
    else
        x1, z1, x2, z2 = unpack(obj)
    end
    local areaView = AreaView(objectID or "")
    local pos = obj.pos or {x=(x2 + x1) / 2, y=0, z=(z2 + z1) / 2}
    local sizeX = math.abs((x2 - x1) / 2)
    local sizeZ = math.abs((z2 - z1) / 2)
    areaView:_Draw(pos.x - sizeX, pos.z - sizeZ, pos.x + sizeX, pos.z + sizeZ)
end

AreaBridge.OnDoubleClick                = function(objectID, _, _, _)
    local trigger = __MakeAreaTrigger(objectID)
    local cmd = AddTriggerCommand(trigger)
    SB.commandManager:execute(cmd)
    Log.Notice(("Created new trigger for entering area ID: %d"):format(objectID))
    return
end
AreaBridge.OnClick                      = function(objectID, x, y, z)
    -- resize when there's only one area selected
    if SB.view.selectionManager:GetSelectionCount() ~= 1 then
        return
    end

    local toResize, resx, resz = __CheckResizeIntersections(objectID, x, z)
    if toResize then
        SB.stateManager:SetState(ResizeAreaState(objectID, resx, resz))
        return true
    end
end

AreaBridge.GetObjectAt                  = function(x, z)
    return SB.model.areaManager:GetAreaIn(x, z)
end

areaBridge = AreaBridge()
AreaS11N = s11n:MakeNewBridge("areaBridge")
function AreaS11N:OnInit()
    self.getFuncs = {
        pos = function(objectID)
            local area = SB.model.areaManager:getArea(objectID)
            local x, z = (area[1] + area[3]) / 2, (area[2] + area[4]) / 2
            local y = Spring.GetGroundHeight(x, z)
            return {x = x, y = y, z = z}
        end,
        size = function(objectID)
            local area = SB.model.areaManager:getArea(objectID)
            local sizeX = math.abs(area[1] - area[3])
            local sizeZ = math.abs(area[2] - area[4])
            return {x = sizeX, y = 0, z = sizeZ}
        end,
    }
    self.setFuncs = {
        pos = function(objectID, value)
            local area = SB.model.areaManager:getArea(objectID)
            local centerX = (area[1] + area[3]) / 2
            local centerZ = (area[2] + area[4]) / 2
            local deltaX = value.x - centerX
            local deltaZ = value.z - centerZ
            SB.model.areaManager:setArea(objectID, {
                area[1] + deltaX,
                area[2] + deltaZ,
                area[3] + deltaX,
                area[4] + deltaZ,
            })
        end,
        size = function(objectID, value)
            local area = SB.model.areaManager:getArea(objectID)
            local centerX = (area[1] + area[3]) / 2
            local centerZ = (area[2] + area[4]) / 2
            local x1, x2, z1, z2
            x1 = centerX - value.x / 2
            x2 = centerX + value.x / 2
            z1 = centerZ - value.z / 2
            z2 = centerZ + value.z / 2
            SB.model.areaManager:setArea(objectID, {
                x1, z1, x2, z2
            })
        end,
    }
end
-- FIXME: Disable setting fields afterwards (faster)
function AreaS11N:CreateObject(object, objectID)
    local pos = object.pos
    local size = object.size
    local centerX = pos.x
    local centerZ = pos.z
    local x1, x2, z1, z2
    x1 = centerX - size.x / 2
    x2 = centerX + size.x / 2
    z1 = centerZ - size.z / 2
    z2 = centerZ + size.z / 2

    local area = {x1, z1, x2, z2}
    local areaID = SB.model.areaManager:addArea(area, objectID)
    return areaID
end

function AreaS11N:GetAllObjectIDs()
    return
end
areaBridge.s11n                         = AreaS11N()
ObjectBridge.Register("area", areaBridge)

-- POSITION

PositionBridge = ObjectBridge:extends{}
PositionBridge.humanName                    = "Position"
PositionBridge.NoDrag                       = true
PositionBridge.spGetObjectPosition          = function(objectID)
    return objectID.x, objectID.y, objectID.z
end

PositionBridge.SelectObjectState            = SelectPositionState
PositionBridge.Select                       = function(objectIDs)
    -- no-op
    -- SB.view.selectionManager:Select({})
end

positionBridge = PositionBridge()
ObjectBridge.Register("position", positionBridge)
