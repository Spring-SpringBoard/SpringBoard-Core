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
UnitBridge.ObjectDefs               = UnitDefs

UnitBridge.AddObjectCommand         = AddUnitCommand
UnitBridge.RemoveObjectCommand      = RemoveUnitCommand
UnitBridge.DrawObject =             function(objectDefID, teamID)
    gl.Color(1, 1, 1, 0.8)
    gl.UnitShape(objectDefID, teamID)
end
unitBridge = UnitBridge()

-- FEATURE

FeatureBridge = ObjectBridge:extends{}
FeatureBridge.bridgeName                   = "FeatureBridge"
FeatureBridge.spGetObjectsInCylinder       = Spring.GetFeaturesInCylinder
FeatureBridge.spGetObjectDefID             = Spring.GetFeatureDefID
FeatureBridge.spGetObjectPosition          = Spring.GetFeaturePosition
FeatureBridge.spValidObject                = Spring.ValidFeatureID
FeatureBridge.ObjectDefs                   = FeatureDefs

FeatureBridge.AddObjectCommand             = AddFeatureCommand
FeatureBridge.RemoveObjectCommand          = RemoveFeatureCommand
FeatureBridge.DrawObject                   = function(objectDefID, teamID)
    local featureDef = FeatureDefs[objectDefID]
    if featureDef.drawType == 0 then
        gl.Texture(1, "%-" .. objectDefID .. ":1")
    else
        Spring.Echo("engine-tree, not sure what to do")
    end
    gl.Color(1, 1, 1, 0.8)
    gl.FeatureShape(objectDefID, teamID)
end
featureBridge = FeatureBridge()