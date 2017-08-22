SB_COMMAND_DIR = SB_DIR .. "command/"
SB.Include(SB_COMMAND_DIR .. 'command.lua')
SB.IncludeDir(SB_COMMAND_DIR)

SB_STATE_DIR = SB_DIR .. "state/"
SB.Include(SB_STATE_DIR .. 'state_manager.lua')
SB.Include(SB_STATE_DIR .. 'abstract_state.lua')
SB.IncludeDir(SB_STATE_DIR)

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
function ObjectBridge.Register(name, objectBridge)
    objectBridge.name = name
    objectBridges[name] = objectBridge
end
function ObjectBridge.GetObjectBridges()
    return objectBridges
end
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
