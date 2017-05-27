WidgetFollowUnitCommand = Command:extends{}

function WidgetFollowUnitCommand:init(unit)
    self.className = "WidgetFollowUnitCommand"
    self.unit = unit
end

function WidgetFollowUnitCommand:execute()
    SB.displayUtil:followUnit(self.unit)
--    SB.model.areaManager:addArea(self.value, self.id)
end
