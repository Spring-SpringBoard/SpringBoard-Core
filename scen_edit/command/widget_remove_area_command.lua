WidgetRemoveAreaCommand = AbstractCommand:extends{}

function WidgetRemoveAreaCommand:init(id)
    self.className = "WidgetRemoveAreaCommand"
    self.id = id
end

function WidgetRemoveAreaCommand:execute()
    SB.model.areaManager:removeArea(self.id)
end
