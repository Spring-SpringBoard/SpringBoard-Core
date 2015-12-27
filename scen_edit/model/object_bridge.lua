SCEN_EDIT_COMMAND_DIR = SCEN_EDIT_DIR .. "command/"
SCEN_EDIT.Include(SCEN_EDIT_COMMAND_DIR .. 'abstract_command.lua')
SCEN_EDIT.Include(SCEN_EDIT_COMMAND_DIR .. 'undoable_command.lua')
SCEN_EDIT.IncludeDir(SCEN_EDIT_COMMAND_DIR)

ObjectBridge = LCS.class.abstract{}

-- UNIT

UnitBridge = ObjectBridge:extends{}
UnitBridge.bridgeName                      = "UnitBridge"
UnitBridge.spGetObjectsInCylinder          = Spring.GetUnitsInCylinder
UnitBridge.spGetObjectDefID                = Spring.GetUnitDefID
UnitBridge.spGetObjectPosition             = Spring.GetUnitPosition
UnitBridge.spValidObject                   = Spring.ValidUnitID
UnitBridge.spGetObjectTeam                 = Spring.GetUnitTeam
UnitBridge.spGetObjectDirection            = Spring.GetUnitDirection
UnitBridge.spGetAllObjects                 = Spring.GetAllUnits
UnitBridge.spGetObjectCollisionVolumeData  = Spring.GetUnitCollisionVolumeData
UnitBridge.spSetObjectCollisionVolumeData  = Spring.SetUnitCollisionVolumeData
UnitBridge.spGetObjectRadius               = Spring.GetUnitRadius
UnitBridge.spGetObjectHeight               = Spring.GetUnitHeight
UnitBridge.spSetObjectRadiusAndHeight      = Spring.SetUnitRadiusAndHeight
UnitBridge.spSetObjectMidAndAimPos         = Spring.SetUnitMidAndAimPos
UnitBridge.spGetObjectBlocking             = Spring.GetUnitBlocking
UnitBridge.spSetObjectBlocking             = Spring.SetUnitBlocking
UnitBridge.ObjectDefs                      = UnitDefs
if gl then
    UnitBridge.glObjectShape               = gl.UnitShape
end

UnitBridge.AddObjectCommand                = AddUnitCommand
UnitBridge.RemoveObjectCommand             = RemoveUnitCommand
UnitBridge.DrawObject                      = function(params)
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
    unitBridge.glObjectShape(objectDefID, objectTeamID)
end
UnitBridge.getSpringObjectID               = function(modelID)
    return SCEN_EDIT.model.unitManager:getSpringUnitId(modelID)
end
unitBridge = UnitBridge()

-- FEATURE

FeatureBridge = ObjectBridge:extends{}
FeatureBridge.bridgeName                      = "FeatureBridge"
FeatureBridge.spGetObjectsInCylinder          = Spring.GetFeaturesInCylinder
FeatureBridge.spGetObjectDefID                = Spring.GetFeatureDefID
FeatureBridge.spGetObjectPosition             = Spring.GetFeaturePosition
FeatureBridge.spValidObject                   = Spring.ValidFeatureID
FeatureBridge.spGetObjectTeam                 = Spring.GetFeatureTeam
FeatureBridge.spGetObjectDirection            = Spring.GetFeatureDirection
FeatureBridge.spGetAllObjects                 = Spring.GetAllFeatures
FeatureBridge.spGetObjectCollisionVolumeData  = Spring.GetFeatureCollisionVolumeData
FeatureBridge.spSetObjectCollisionVolumeData  = Spring.SetFeatureCollisionVolumeData
FeatureBridge.spGetObjectRadius               = Spring.GetFeatureRadius
FeatureBridge.spGetObjectHeight               = Spring.GetFeatureHeight
FeatureBridge.spSetObjectRadiusAndHeight      = Spring.SetFeatureRadiusAndHeight
FeatureBridge.spSetObjectRadiusAndHeight      = Spring.SetFeatureRadiusAndHeight
FeatureBridge.spSetObjectMidAndAimPos         = Spring.SetFeatureMidAndAimPos
FeatureBridge.spGetObjectBlocking             = Spring.GetFeatureBlocking
FeatureBridge.spSetObjectBlocking             = Spring.SetFeatureBlocking
FeatureBridge.ObjectDefs                      = FeatureDefs
if gl then
    FeatureBridge.glObjectShape               = gl.FeatureShape
end

FeatureBridge.AddObjectCommand                = AddFeatureCommand
FeatureBridge.RemoveObjectCommand             = RemoveFeatureCommand
FeatureBridge.DrawObject                      = function(params)
    local pos           = params.pos
    local angle         = params.angle
    local objectDefID   = params.objectDefID
    local objectTeamID  = params.objectTeamID
    local color         = params.color
    local featureDef    = FeatureDefs[objectDefID]

    gl.Color(color.r, color.g, color.b, color.a)
    if featureDef.drawType == 0 then
        gl.Texture(1, "%-" .. objectDefID .. ":1")
        gl.Texture(2, "%-" .. objectDefID .. ":2")
    else
        Spring.Echo("engine-tree, not sure what to do")
    end
    gl.Translate(pos.x, pos.y, pos.z)
    gl.Rotate(angle.x, 1, 0, 0)
    gl.Rotate(angle.y, 0, 1, 0)
    gl.Rotate(angle.z, 0, 0, 1)
    featureBridge.glObjectShape(objectDefID, objectTeamID)
end
FeatureBridge.getSpringObjectID               = function(modelID)
    return SCEN_EDIT.model.featureManager:getSpringFeatureId(modelID)
end
featureBridge = FeatureBridge()

-- AREA

AreaBridge = ObjectBridge:extends{}
AreaBridge.bridgeName                   = "AreaBridge"
AreaBridge.spGetObjectPosition          = function(objectID)
    local pos = SCEN_EDIT.model.areaManager:getArea(objectID)
    local x, z = (pos[1] + pos[3]) / 2, (pos[2] + pos[4]) / 2
    local y = Spring.GetGroundHeight(x, z)
    return x, y, z
end
AreaBridge.spGetAllObjects              = function()
    return SCEN_EDIT.model.areaManager:getAllAreas()
end
AreaBridge.spValidObject                = function(objectID)
    return SCEN_EDIT.model.areaManager:getArea(objectID) ~= nil
end

areaBridge = AreaBridge()