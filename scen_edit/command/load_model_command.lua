LoadModelCommand = Command:extends{}
LoadModelCommand.className = "LoadModelCommand"

function LoadModelCommand:init(modelString)
    -- Since the introduction of the data packing/unpacking, is much more
    -- efficient passing tables than strings
    if modelString then
        self.mission = loadstring(modelString)()
    end
end

function LoadModelCommand:execute()
    SB.model:Clear()
    GG.Delay.DelayCall(function()
        self:Load()
    end, {}, 8)
end

function LoadModelCommand:Load()
    Log.Notice("Loading model...")
    SB.model:Load(self.mission)
    Log.Notice("Loading model finished")
end
