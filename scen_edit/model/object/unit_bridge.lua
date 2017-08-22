SB.Include(SB_MODEL_OBJECT_DIR .. 'object_bridge.lua')

UnitBridge = ObjectBridge:extends{}
UnitBridge.humanName                       = "Unit"
UnitBridge.GetObjectsInCylinder            = Spring.GetUnitsInCylinder
UnitBridge.GetObjectDefID                  = Spring.GetUnitDefID
UnitBridge.ValidObject                     = Spring.ValidUnitID

UnitBridge.SelectObjectTypeState           = SelectUnitTypeState

UnitBridge.DrawObject                      = function(params)
    DrawObject(params, unitBridge)
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

UnitBridge.OnLuaUIAdded = function(objectID, modelID)
    SB.model.unitManager:addUnit(objectID, modelID)
end
UnitBridge.OnLuaUIRemoved = function(objectID)
    SB.model.unitManager:removeUnitByModelID(objectID)
end

unitBridge = UnitBridge()
unitBridge.s11n                            = s11n:GetUnitBridge()
unitBridge.ObjectDefs                      = UnitDefs
if gl then
    unitBridge.glObjectShape               = gl.UnitShape
    unitBridge.glObjectShapeTextures       = gl.UnitShapeTextures
end
unitBridge.s11nFieldOrder = {"pos", "rot", "vel", "team"}
unitBridge.blockedFields = {
    "collision", "blocking", "radiusHeight", "midAimPos",
    "dir", "defName", "paralyze", "commands", "rules"
}

ObjectBridge.Register("unit", unitBridge)
