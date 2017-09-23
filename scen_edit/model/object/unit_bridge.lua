SB.Include(SB_MODEL_OBJECT_DIR .. 'object_bridge.lua')

UnitBridge = ObjectBridge:extends{}
UnitBridge.humanName                       = "Unit"
UnitBridge.GetObjectsInCylinder            = Spring.GetUnitsInCylinder
UnitBridge.GetObjectDefID                  = Spring.GetUnitDefID
UnitBridge.ValidObject                     = Spring.ValidUnitID

UnitBridge.DrawObject                      = function(params)
    DrawObject(params, unitBridge)
end
UnitBridge.OnSelect                        = function(objectIDs)
    Spring.SelectUnitArray(objectIDs)
end

UnitBridge.getObjectSpringID               = function(modelID)
    return unitBridge.s11n:GetSpringID(modelID)
end
UnitBridge.getObjectModelID                = function(objectID)
    return unitBridge.s11n:GetModelID(objectID)
end
UnitBridge.setObjectModelID                = function(objectID, modelID)
    unitBridge.s11n:Set(objectID, "__modelID", modelID)
end

UnitBridge.OnLuaUIAdded = function(objectID, modelID)
    unitBridge.s11n:_ObjectCreated(objectID, modelID)
end
UnitBridge.OnLuaUIRemoved = function(objectID)
    unitBridge.s11n:_ObjectDestroyed(objectID)
end

unitBridge = UnitBridge()
unitBridge.s11n                            = s11n:GetUnitS11N()
unitBridge.ObjectDefs                      = UnitDefs
if gl then
    unitBridge.glObjectShape               = gl.UnitShape
    unitBridge.glObjectShapeTextures       = gl.UnitShapeTextures
end
unitBridge.s11nFieldOrder = {"pos", "rot", "vel", "team"}
unitBridge.blockedFields = {
    "collision", "blocking", "radiusHeight", "midAimPos",
    "dir", "defName", "paralyze", "commands", "rules",
    "__modelID",
}

ObjectBridge.Register("unit", unitBridge)
