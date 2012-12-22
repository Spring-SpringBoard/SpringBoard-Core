WidgetFollowUnitCommand = AbstractCommand:extends{}

function WidgetFollowUnitCommand:init(unit)
    self.className = "WidgetFollowUnitCommand"
    self.unit = unit
end

function WidgetFollowUnitCommand:execute()
    SCEN_EDIT.displayUtil:followUnit(self.unit)
--    SCEN_EDIT.model.areaManager:addArea(self.value, self.id)
end
