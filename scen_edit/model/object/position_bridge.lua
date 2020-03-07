SB.Include(Path.Join(SB.DIRS.SRC, 'model/object/object_bridge.lua'))

PositionBridge = ObjectBridge:extends{}
PositionBridge.humanName                    = "Position"
PositionBridge.NoDrag                       = true
PositionBridge.NotSelectable                = true

positionBridge = PositionBridge()
ObjectBridge.Register("position", positionBridge)
