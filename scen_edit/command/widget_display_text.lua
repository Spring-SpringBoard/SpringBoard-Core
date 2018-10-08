WidgetDisplayTextCommand = Command:extends{}
WidgetDisplayTextCommand.className = "WidgetDisplayTextCommand"

function WidgetDisplayTextCommand:init(text, coords, color)
    self.text = text
    self.coords = coords
    self.color = color
end

function WidgetDisplayTextCommand:execute()
    SB.displayUtil:displayText(self.text, self.coords, self.color)
--    SB.model.areaManager:addArea(self.value, self.id)
end
