WidgetFollowUnitCommand = Command:extends{}
WidgetFollowUnitCommand.className = "WidgetFollowUnitCommand"

function WidgetFollowUnitCommand:init(unit)
    self.unit = unit
end

function WidgetFollowUnitCommand:execute()
    SB.displayUtil:followUnit(self.unit)
--    SB.model.areaManager:addArea(self.value, self.id)
end
