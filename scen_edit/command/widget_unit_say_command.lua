WidgetUnitSayCommand = Command:extends{}

function WidgetUnitSayCommand:init(unit, text)
    self.className = "WidgetUnitSayCommand"
    self.unit = unit
    self.text = text
end

function WidgetUnitSayCommand:execute()
    SB.displayUtil:unitSay(self.unit, self.text)
--    SB.model.areaManager:addArea(self.value, self.id)
end
