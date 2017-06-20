SB.Include(Path.Join(SB_MODEL_DIR, "area_manager.lua"))

----------------------------------------------------------
-- Widget callback commands
----------------------------------------------------------
WidgetAddAreaCommand = Command:extends{}

function WidgetAddAreaCommand:init(id, value)
    self.className = "WidgetAddAreaCommand"
    self.id = id
    self.value = value
end

function WidgetAddAreaCommand:execute()
    SB.model.areaManager:addArea(self.value, self.id)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetRemoveAreaCommand = Command:extends{}

function WidgetRemoveAreaCommand:init(id)
    self.className = "WidgetRemoveAreaCommand"
    self.id = id
end

function WidgetRemoveAreaCommand:execute()
    SB.model.areaManager:removeArea(self.id)
end
----------------------------------------------------------
----------------------------------------------------------
WidgetUpdateAreaCommand = Command:extends{}

function WidgetUpdateAreaCommand:init(id, opts)
    self.className = "WidgetUpdateAreaCommand"
    self.id = id
    self.opts = opts
end

function WidgetUpdateAreaCommand:execute()
    local area = SB.model.areaManager:getArea(self.id)
    for k, v in pairs(self.opts) do
        area[k] = v
    end
end
----------------------------------------------------------
-- END Widget callback commands
----------------------------------------------------------

----------------------------------------------------------
-- Widget callback listener
----------------------------------------------------------
if SB.SyncModel then

AreaManagerListenerGadget = AreaManagerListener:extends{}
SB.OnInitialize(function()
    SB.model.areaManager:addListener(AreaManagerListenerGadget())
end)

function AreaManagerListenerGadget:onAreaAdded(areaID)
    local area = SB.model.areaManager:getArea(areaID)
    local cmd = WidgetAddAreaCommand(areaID, area)
    SB.commandManager:execute(cmd, true)
end

function AreaManagerListenerGadget:onAreaRemoved(areaID)
    local cmd = WidgetRemoveAreaCommand(areaID)
    SB.commandManager:execute(cmd, true)
end

function AreaManagerListenerGadget:onAreaChange(areaID, area)
    local cmd = WidgetUpdateAreaCommand(areaID, area)
    SB.commandManager:execute(cmd, true)
end

end
----------------------------------------------------------
-- END Widget callback listener
----------------------------------------------------------
