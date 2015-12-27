SCEN_EDIT_COMMAND_DIR = SCEN_EDIT_DIR .. "command/"
SCEN_EDIT.Include(SCEN_EDIT_COMMAND_DIR .. 'abstract_command.lua')
SCEN_EDIT.Include(SCEN_EDIT_COMMAND_DIR .. 'undoable_command.lua')
SCEN_EDIT.IncludeDir(SCEN_EDIT_COMMAND_DIR)

ObjectBridge = LCS.class.abstract{}

-- UNIT

UnitBridge = ObjectBridge:extends{}
UnitBridge.bridgeName               = "UnitBridge"
UnitBridge.spGetObjectsInCylinder   = Spring.GetUnitsInCylinder
UnitBridge.spGetObjectDefID         = Spring.GetUnitDefID
UnitBridge.spGetObjectPosition      = Spring.GetUnitPosition
UnitBridge.spValidObject            = Spring.ValidUnitID
UnitBridge.spGetObjectTeam          = Spring.GetUnitTeam
UnitBridge.spGetObjectDirection     = Spring.GetUnitDirection
UnitBridge.ObjectDefs               = UnitDefs

UnitBridge.AddObjectCommand         = AddUnitCommand
UnitBridge.RemoveObjectCommand      = RemoveUnitCommand
UnitBridge.DrawObject =             function(params)
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
    gl.UnitShape(objectDefID, objectTeamID)
end
unitBridge = UnitBridge()

-- FEATURE

FeatureBridge = ObjectBridge:extends{}
FeatureBridge.bridgeName                   = "FeatureBridge"
FeatureBridge.spGetObjectsInCylinder       = Spring.GetFeaturesInCylinder
FeatureBridge.spGetObjectDefID             = Spring.GetFeatureDefID
FeatureBridge.spGetObjectPosition          = Spring.GetFeaturePosition
FeatureBridge.spValidObject                = Spring.ValidFeatureID
FeatureBridge.spGetObjectTeam              = Spring.GetFeatureTeam
FeatureBridge.spGetObjectDirection         = Spring.GetFeatureDirection
FeatureBridge.ObjectDefs                   = FeatureDefs

FeatureBridge.AddObjectCommand             = AddFeatureCommand
FeatureBridge.RemoveObjectCommand          = RemoveFeatureCommand
FeatureBridge.DrawObject                   = function(params)
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
    gl.FeatureShape(objectDefID, objectTeamID)
end
featureBridge = FeatureBridge()