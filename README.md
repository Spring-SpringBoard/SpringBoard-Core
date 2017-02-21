SpringRTS serialization library.

Design goals

API
```lua
s11n:GetUnitBridge() -> s11nUnit
s11n:GetFeatureBridge() -> s11nFeature
s11n:Get()
s11n:Set({ "units" -> {...}, "features" -> {...}, etc. })


s11n:Get(objectIDs, names)
s11n:Get(objectIDs)

s11n:Get(objectID, "health") -> number
s11n:Get(objectID, {"health", "maxHealth"}) -> { health = number, maxHealth = number }
s11n:Get(objectID) -> { k1 = v1, k2 = v2, ... kn = vn}
s11n:Get({objectID1, objectID2}, "health") -> { objectID1 = number, objectID2 = number }
s11n:Get({objectID1, objectID2}, {"health", "maxHealth"}) -> { objectID1 = { health = number, maxHealth = number }, objectID2 = { health = number, maxHealth = number }}
s11n:Get({objectID1, objectID2}) -> { objectID1 = { k1 = v1, k2 = v2, ... kn = vn}, objectID2 = { k1 = v1, k2 = v2, ... kn = vn} }

s11n:Set(objectIDs, name, values)
s11n:Set(objectIDs, fields)
s11n:Set(objects)

s11n:Set(objectID, "health", value)
s11n:Set(objectID, { health = number, maxHealth = number })
s11n:Set({ objectID1 = { health = number, maxHealth = number },
           objectID2 = { health = number, maxHealth = number }}
```