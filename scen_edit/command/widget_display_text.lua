WidgetDisplayTextCommand = AbstractCommand:extends{}

function WidgetDisplayTextCommand:init(text, coords, color)
    self.className = "WidgetDisplayTextCommand"
    self.text = text
    self.coords = coords
    self.color = color
end

function WidgetDisplayTextCommand:execute()
    SCEN_EDIT.displayUtil:displayText(self.text, self.coords, self.color)
--    SCEN_EDIT.model.areaManager:addArea(self.value, self.id)
end
