SB.Include(SB_MODEL_OBJECT_DIR .. 'object_bridge.lua')

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
