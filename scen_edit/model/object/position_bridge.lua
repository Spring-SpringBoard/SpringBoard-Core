SB.Include(SB_MODEL_OBJECT_DIR .. 'object_bridge.lua')

PositionBridge = ObjectBridge:extends{}
PositionBridge.humanName                    = "Position"
PositionBridge.NoDrag                       = true
PositionBridge.NotSelectable                = true

positionBridge = PositionBridge()
ObjectBridge.Register("position", positionBridge)
