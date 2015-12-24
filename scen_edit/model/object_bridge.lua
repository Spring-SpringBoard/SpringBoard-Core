SCEN_EDIT_COMMAND_DIR = SCEN_EDIT_DIR .. "command/"
SCEN_EDIT.Include(SCEN_EDIT_COMMAND_DIR .. 'abstract_command.lua')
SCEN_EDIT.Include(SCEN_EDIT_COMMAND_DIR .. 'undoable_command.lua')
SCEN_EDIT.IncludeDir(SCEN_EDIT_COMMAND_DIR)

ObjectBridge = LCS.class.abstract{}

-- UNIT

UnitBridge = ObjectBridge:extends{}
UnitBridge.spGetObjectsInCylinder   = Spring.GetUnitsInCylinder
UnitBridge.spGetObjectDefID         = Spring.GetUnitDefID
UnitBridge.spGetObjectPosition      = Spring.GetUnitPosition
UnitBridge.spValidObject            = Spring.ValidUnitID

UnitBridge.AddObjectCommand         = AddUnitCommand
UnitBridge.RemoveObjectCommand      = RemoveUnitCommand
UnitBridge.DrawObject =             function(objectDefID, team)
    gl.Color(1, 1, 1, 0.8)
    gl.UnitShape(objectDefID, team)
end
unitBridge = UnitBridge()

-- FEATURE

FeatureBridge = ObjectBridge:extends{}
FeatureBridge.spGetObjectsInCylinder       = Spring.GetFeaturesInCylinder
FeatureBridge.spGetObjectDefID             = Spring.GetFeatureDefID
FeatureBridge.spGetObjectPosition          = Spring.GetFeaturePosition
FeatureBridge.spValidObject                = Spring.ValidFeatureID

FeatureBridge.AddObjectCommand             = AddFeatureCommand
FeatureBridge.RemoveObjectCommand          = RemoveFeatureCommand
FeatureBridge.DrawObject                   = function(objectDefID, team)
    gl.Texture(1, "%-" .. objectDefID .. ":1")
    gl.Color(1, 1, 1, 0.8)
    gl.FeatureShape(objectDefID, team)
end
featureBridge = FeatureBridge()