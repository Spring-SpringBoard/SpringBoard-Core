SB.Include(SB_MODEL_OBJECT_DIR .. 'object_bridge.lua')

local function __CheckResizeIntersections(areaID, x, z)
    local rect = SB.model.areaManager:getArea(areaID)
    local accuracy = 20
    local toResize = false
    local resx, resz = 0, 0

    local drag_diff_x, drag_diff_z
    if math.abs(x - rect[1]) < accuracy then
        resx = -1
        drag_diff_x = rect[1] - x
        toResize = true
        if z > rect[2] + accuracy and z < rect[4] - accuracy then
            resz = 0
        elseif math.abs(rect[2] - z) < accuracy then
            drag_diff_z = rect[2] - z
            resz = -1
        elseif math.abs(rect[4] - z) < accuracy then
            drag_diff_z = rect[4] - z
            resz = 1
        else
            toResize = false
        end
    elseif math.abs(x - rect[3]) < accuracy then
        resx = 1
        drag_diff_x = rect[3] - x
        toResize = true
        if z > rect[2] + accuracy and z < rect[4] - accuracy then
            resz = 0
        elseif math.abs(rect[2] - z) < accuracy then
            drag_diff_z = rect[2] - z
            resz = -1
        elseif math.abs(rect[4] - z) < accuracy then
            drag_diff_z = rect[4] - z
            resz = 1
        else
            toResize = false
        end
    elseif math.abs(z - rect[2]) < accuracy then
        resx = 0
        resz = -1
        drag_diff_z = rect[2] - z
        if x > rect[1] + accuracy and x < rect[3] + accuracy then
            toResize = true
        else
            toResize = false
        end
    elseif math.abs(z - rect[4]) < accuracy then
        resx = 0
        resz = 1
        drag_diff_z = rect[4] - z
        if x > rect[1] + accuracy and x < rect[3] + accuracy then
            toResize = true
        else
            toResize = false
        end
    end
    return toResize, resx, resz, drag_diff_x, drag_diff_z
end

local function __MakeAreaTrigger(areaID)
    local trigger = {
        name = "Enter area " .. areaID,
        enabled = true,
        actions = {},
        events = {
            {
                typeName = "UNIT_ENTER_AREA",
            },
        },
        conditions = {
            {
                typeName = "compare_area",
                first = {
                    value = areaID,
                    type = "const",
                },
                relation = {
                    value = 1,
                    type = "const",
                },
                second = {
                    value = "area",
                    type = "scoped",
                },
            },
        },
    }
    return trigger
end

AreaBridge = ObjectBridge:extends{}
AreaBridge.humanName                    = "Area"
AreaBridge.NoHorizontalDrag             = true
AreaBridge.ValidObject                = function(objectID)
    return SB.model.areaManager:getArea(objectID) ~= nil
end

AreaBridge.OnSelect                     = function(objectIDs)
    for _, areaID in pairs(SB.model.areaManager:getAllAreas()) do
        SB.view.areaViews[areaID].selected = false
    end
    for _, areaID in pairs(objectIDs) do
        SB.view.areaViews[areaID].selected = true
    end
end
AreaBridge.DrawObject                   = function(objectID, obj)
    local x1, z1, x2, z2
    if objectID then
        x1, z1, x2, z2 = unpack(SB.model.areaManager:getArea(objectID))
    else
        x1, z1, x2, z2 = unpack(obj)
    end
    local areaView = AreaView(objectID or "")
    local pos = obj.pos or {x=(x2 + x1) / 2, y=0, z=(z2 + z1) / 2}
    local sizeX = math.abs((x2 - x1) / 2)
    local sizeZ = math.abs((z2 - z1) / 2)
    areaView:_Draw(pos.x - sizeX, pos.z - sizeZ, pos.x + sizeX, pos.z + sizeZ)
end

AreaBridge.OnDoubleClick                = function(objectID, _, _, _)
    local trigger = __MakeAreaTrigger(objectID)
    local cmd = AddTriggerCommand(trigger)
    SB.commandManager:execute(cmd)
    Log.Notice(("Created new trigger for entering area ID: %d"):format(objectID))
    return
end
AreaBridge.OnClick                      = function(objectID, x, y, z)
    -- resize when there's only one area selected
    if SB.view.selectionManager:GetSelectionCount() ~= 1 then
        return
    end

    local toResize, resx, resz, drag_diff_x, drag_diff_z = __CheckResizeIntersections(objectID, x, z)
    if toResize then
        SB.stateManager:SetState(ResizeAreaState(objectID, resx, resz, drag_diff_x, drag_diff_z))
        return true
    end
end

AreaBridge.GetObjectAt                  = function(x, z)
    return SB.model.areaManager:GetAreaIn(x, z)
end

AreaBridge.OnLuaUIAdded = function(objectID, object)
    areaBridge.s11n:Add(object)
end
AreaBridge.OnLuaUIRemoved = function(objectID)
    areaBridge.s11n:Remove(objectID)
end
AreaBridge.OnLuaUIUpdated = function(objectID, name, value)
    areaBridge.s11n:Set(objectID, name, value)
end

areaBridge = AreaBridge()
AreaS11N = s11n:MakeNewS11N("areaBridge")
function AreaS11N:OnInit()
    self.funcs = {
        pos = {
            get = function(objectID)
                local area = SB.model.areaManager:getArea(objectID)
                local x, z = (area[1] + area[3]) / 2, (area[2] + area[4]) / 2
                local y = Spring.GetGroundHeight(x, z)
                return {x = x, y = y, z = z}
            end,
            set = function(objectID, value)
                local area = SB.model.areaManager:getArea(objectID)
                local centerX = (area[1] + area[3]) / 2
                local centerZ = (area[2] + area[4]) / 2
                local deltaX = value.x - centerX
                local deltaZ = value.z - centerZ
                SB.model.areaManager:setArea(objectID, {
                    area[1] + deltaX,
                    area[2] + deltaZ,
                    area[3] + deltaX,
                    area[4] + deltaZ,
                })
            end,
        },
        size = {
            get = function(objectID)
                local area = SB.model.areaManager:getArea(objectID)
                local sizeX = math.abs(area[1] - area[3])
                local sizeZ = math.abs(area[2] - area[4])
                return {x = sizeX, y = 0, z = sizeZ}
            end,
            set = function(objectID, value)
                local area = SB.model.areaManager:getArea(objectID)
                local centerX = (area[1] + area[3]) / 2
                local centerZ = (area[2] + area[4]) / 2
                local x1, x2, z1, z2
                x1 = centerX - value.x / 2
                x2 = centerX + value.x / 2
                z1 = centerZ - value.z / 2
                z2 = centerZ + value.z / 2
                SB.model.areaManager:setArea(objectID, {
                    x1, z1, x2, z2
                })
            end,
        },
    }
end
-- FIXME: Disable setting fields afterwards (faster)
function AreaS11N:CreateObject(object, objectID)
    local pos = object.pos
    local size = object.size
    local centerX = pos.x
    local centerZ = pos.z
    local x1, x2, z1, z2
    x1 = centerX - size.x / 2
    x2 = centerX + size.x / 2
    z1 = centerZ - size.z / 2
    z2 = centerZ + size.z / 2

    local area = {x1, z1, x2, z2}
    local areaID = SB.model.areaManager:addArea(area, objectID)
    return areaID
end

function AreaS11N:DestroyObject(objectID)
    SB.model.areaManager:removeArea(objectID)
end

function AreaS11N:GetAllObjectIDs()
    return SB.model.areaManager:getAllAreas()
end

areaBridge.s11n = AreaS11N()
areaBridge.s11nFieldOrder = {"pos", "size"}
ObjectBridge.Register("area", areaBridge)
