StartCommand = LCS.class{}

function StartCommand:init()
    self.className = "StartCommand"
end

function StartCommand:execute()
    Spring.Echo("start!")
    SCEN_EDIT.rtModel:LoadMission(SCEN_EDIT.model:GetMetaData())
    SCEN_EDIT.rtModel:GameStart()
end
