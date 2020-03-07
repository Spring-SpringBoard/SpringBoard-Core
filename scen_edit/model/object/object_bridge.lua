--- ObjectBridge module.

SB.Include(Path.Join(SB.DIRS.SRC, 'command/command.lua'))
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'command'))

SB.Include(Path.Join(SB.DIRS.SRC, 'state/state_manager.lua'))
SB.Include(Path.Join(SB.DIRS.SRC, 'state/abstract_state.lua'))
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'state'))

--- ObjectBridge class. Use to represent objects in the game world.
-- It can use the s11n API to provide serialization support. Consult https://github.com/Spring-SpringBoard/SpringBoard-Core/tree/master/libs/s11n for details.
-- @string humanName Human readable name.
-- @bool NoHorizontalDrag If true, disables horizontal drag
-- @tparam function ValidObject Function accepting objectID number. Returns true if objectID is valid.
-- @tparam function OnSelect Function accepting objectIDs table, invoked when selected.
-- @tparam function DrawObject Function invoked when drawing objects manually. Accepts objectID number and obj table as params.
-- @tparam function OnDoubleClick Function invoked when double clicked on an object in the game world.
-- @tparam function OnClick Function invoked when clicked on an object in the game world. Accepts objectID, x, y and z as parameters.
-- @tparam function GetObjectAt Function that returns an object at location x, z (if any exists).
-- @tparam function OnLuaUIAdded Function invoked when LuaUI gets notification that an object was added. Accepts (objectID, object).
-- @tparam function OnLuaUIRemoved Function invoked when LuaUI gets notification that an object was removed. Accepts (objectID).
-- @tparam function OnLuaUIUpdated Function invoked when LuaUI gets notification that an object was updated. Accepts (objectID, name, value).
-- @table ObjectBridge
ObjectBridge = LCS.class.abstract{}

function ObjectBridge.getObjectSpringID(modelID)
    return modelID
end
function ObjectBridge.getObjectModelID(objectID)
    return objectID
end
function ObjectBridge.setObjectModelID(objectID, modelID)
end

function ObjectBridge.ValidObject(objectID)
    return true
end

local objectBridges = {}
--- Register new bridge.
-- @tparam string name Name of the bridge.
-- @tparam ObjectBridge objectBridge Instance of a class implementing the ObjectBridge interface.
function ObjectBridge.Register(name, objectBridge)
    objectBridge.name = name
    objectBridges[name] = objectBridge
end
--- Get a associative array of name->objectBridge for all objectBridges.
-- @return table.
function ObjectBridge.GetObjectBridges()
    return objectBridges
end
--- Get a specific objectBridge
-- @tparam string name Name of the ObjectBridge.
-- @return ObjectBridge.
function ObjectBridge.GetObjectBridge(name)
    return objectBridges[name]
end

function DrawObject(params, bridge)
    gl.PushMatrix()
    local pos           = params.pos
    local angle         = params.angle
    local objectDefID   = params.objectDefID
    local objectTeamID  = params.objectTeamID
    local color         = params.color
    gl.Color(color.r, color.g, color.b, color.a)
    gl.Translate(pos.x, pos.y, pos.z)
    gl.Rotate(angle.x, 1, 0, 0)
    gl.Rotate(angle.y, 0, 1, 0)
    gl.Rotate(angle.z, 0, 0, 1)
    bridge.glObjectShapeTextures(objectDefID, true)
    bridge.glObjectShape(objectDefID, objectTeamID, true)
    bridge.glObjectShapeTextures(objectDefID, false)
    gl.PopMatrix()
end

ObjectBridge.blockedFields = {}
ObjectBridge.s11nFieldOrder = {"pos"}
