ReloadIntoProjectCommand = NativeCommand:extends{}
ReloadIntoProjectCommand.className = "ReloadIntoProjectCommand"

function ReloadIntoProjectCommand:init(path)
    self.path = path
    self.modOptions = SB.GetPersistantModOptions()
    self.gameName = Game.gameName
    self.gameVersion = Game.gameVersion
    self.blockUndo = true
end
