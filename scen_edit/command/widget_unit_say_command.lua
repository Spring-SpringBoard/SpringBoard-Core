WidgetUnitSayCommand = Command:extends{}
WidgetUnitSayCommand.className = "WidgetUnitSayCommand"

function WidgetUnitSayCommand:init(unit, text)
    self.unit = unit
    self.text = text
end

function WidgetUnitSayCommand:execute()
    SB.displayUtil:unitSay(self.unit, self.text)
--    SB.model.areaManager:addArea(self.value, self.id)
end
