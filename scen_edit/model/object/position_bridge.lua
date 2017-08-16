SB.Include(SB_MODEL_OBJECT_DIR .. 'object_bridge.lua')

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
