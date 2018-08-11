SpringRTS serialization library.

Design goals

API
```lua
s11n:GetUnitS11N() -> s11nUnit
s11n:GetFeatureS11N() -> s11nFeature

s11n:Get(...)
s11n:Add(...)
s11n:Set(...)

-- API for s11n:Add()
s11n:Add(object)
s11n:Add(objects)

-- API for s11n:Get()
s11n:Get() -- Returns all objects
s11n:Get(objectID) -- Returns all fields for an object
s11n:Get(objectIDs) -- Returns all fields for objects
s11n:Get(objectID, key) -- Returns field for an object
s11n:Get(objectID, keys) -- Returns fields for an object
s11n:Get(objectIDs, key) -- Returns field for objects
s11n:Get(objectIDs, keys) -- Returns fields for objects

-- API for s11n:Set()
s11n:Set(object)
s11n:Set(objects)
s11n:Set(objectID, keyValueTable)
s11n:Set(objectIDs, keyValueTable)
s11n:Set(objectID, key, value)
s11n:Set(objectID, keys, values)
s11n:Set(objectIDs, key, value)
s11n:Set(objectIDs, keys, values)
-- TODO: maybe
-- s11n:Set(objectIDs, fields)

-- Examples for s11n:Get()
s11n:Get(objectID, "health") -> number
s11n:Get(objectID, {"health", "maxHealth"}) -> { health = number, maxHealth = number }
s11n:Get(objectID) -> { k1 = v1, k2 = v2, ... kn = vn}
s11n:Get({objectID1, objectID2}, "health") -> { objectID1 = number, objectID2 = number }
s11n:Get({objectID1, objectID2}, {"health", "maxHealth"}) -> { objectID1 = { health = number, maxHealth = number }, objectID2 = { health = number, maxHealth = number }}
s11n:Get({objectID1, objectID2}) -> { objectID1 = { k1 = v1, k2 = v2, ... kn = vn}, objectID2 = { k1 = v1, k2 = v2, ... kn = vn} }

s11n:Set(objectID, "health", value)
s11n:Set(objectID, { health = number, maxHealth = number })
s11n:Set({ objectID1 = { health = number, maxHealth = number },
           objectID2 = { health = number, maxHealth = number }}
```
