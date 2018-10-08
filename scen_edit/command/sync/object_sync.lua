WidgetAddObjectCommand = Command:extends{}
WidgetAddObjectCommand.className = "WidgetAddObjectCommand"
----------------------------------------------------------
-- Widget callback commands
----------------------------------------------------------

function WidgetAddObjectCommand:init(objType, objectID, object)
    self.objType = objType
    self.objectID = objectID
    self.object = object

    -- self.springID = springID
    -- self.modelID = modelID
end

function WidgetAddObjectCommand:execute()
    local bridge = ObjectBridge.GetObjectBridge(self.objType)
    if type(self.object) == "table" then
        self.object.objectID = self.objectID
    end
    bridge.OnLuaUIAdded(self.objectID, self.object)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetRemoveObjectCommand = Command:extends{}
WidgetRemoveObjectCommand.className = "WidgetRemoveObjectCommand"

function WidgetRemoveObjectCommand:init(objType, objectID)
    self.objType = objType
    self.objectID = objectID
end

function WidgetRemoveObjectCommand:execute()
    local bridge = ObjectBridge.GetObjectBridge(self.objType)
    bridge.OnLuaUIRemoved(self.objectID)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetUpdateObjectCommand = Command:extends{}
WidgetUpdateObjectCommand.className = "WidgetUpdateObjectCommand"

function WidgetUpdateObjectCommand:init(objType, objectID, name, value)
    self.objType = objType
    self.objectID = objectID
    self.name = name
    self.value = value
end

function WidgetUpdateObjectCommand:execute()
    local bridge = ObjectBridge.GetObjectBridge(self.objType)

    bridge.OnLuaUIUpdated(self.objectID, self.name, self.value)
end
----------------------------------------------------------
-- END Widget callback commands
----------------------------------------------------------

----------------------------------------------------------
-- Widget callback listener
----------------------------------------------------------
if SB.SyncModel then

S11NGadgetListener = LCS.class{}

SB.OnInitialize(function()
    SB.delay(function()
        for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
            if bridge.s11n then
                Log.Notice("Sync: " .. tostring(name))
                local listener = S11NGadgetListener()
                listener.objType = name

                -- not using 'nil' because of metatable magix
                if not bridge.OnLuaUIAdded then
                    listener.OnCreateObject = false
                end
                if not bridge.OnLuaUIRemoved then
                    listener.OnDestroyObject = false
                end
                if not bridge.OnLuaUIUpdated then
                    listener.OnFieldSet = false
                end

                bridge.s11n:AddListener(listener)
            end
        end
    end)
end)

function S11NGadgetListener:OnCreateObject(objectID)
    local bridge = ObjectBridge.GetObjectBridge(self.objType)

    local object
    if bridge == unitBridge or bridge == featureBridge then
        object = bridge.s11n:GetModelID(objectID)
    else
        object = bridge.s11n:Get(objectID)
    end
    local cmd = WidgetAddObjectCommand(self.objType, objectID, object)
    SB.commandManager:execute(cmd, true)
end

function S11NGadgetListener:OnDestroyObject(objectID)
    local cmd = WidgetRemoveObjectCommand(self.objType, objectID)
    SB.commandManager:execute(cmd, true)
end

function S11NGadgetListener:OnFieldSet(objectID, name, value)
    local cmd = WidgetUpdateObjectCommand(self.objType, objectID, name, value)
    SB.commandManager:execute(cmd, true)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
