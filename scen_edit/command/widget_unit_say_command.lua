WidgetUnitSayCommand = AbstractCommand:extends{}

function WidgetUnitSayCommand:init(unit, text)
    self.className = "WidgetUnitSayCommand"
    self.unit = unit
    self.text = text
end

function WidgetUnitSayCommand:execute()
    SCEN_EDIT.displayUtil:unitSay(self.unit, self.text)
--    SCEN_EDIT.model.areaManager:addArea(self.value, self.id)
end
