WidgetPlaySoundCommand = AbstractCommand:extends{}

function WidgetPlaySoundCommand:init(soundPath)
    self.className = "WidgetPlaySoundCommand"
    self.soundPath = soundPath
end

function WidgetPlaySoundCommand:execute()
    SCEN_EDIT.displayUtil:playSound(self.soundPath)
--    SCEN_EDIT.model.areaManager:addArea(self.value, self.id)
end
