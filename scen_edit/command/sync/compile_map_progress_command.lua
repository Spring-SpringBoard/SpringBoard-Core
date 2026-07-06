-- Native compile-map progress, delivered as widget commands from the native
-- CompileMapCommand. The export action sets `SB.compileMapProgressID` (a
-- notification) and the terrain settings editor sets `SB.compileMapProgressBar`
-- (a progress bar); either may be nil.

CompileMapStarted = Command:extends{}
CompileMapStarted.className = "CompileMapStarted"

function CompileMapStarted:execute()
    if SB.compileMapProgressID then
        SB.ActionProgress(SB.compileMapProgressID, 0.62, "Exporting archive: Compiling map...")
    end
    if SB.compileMapProgressBar then
        SB.compileMapProgressBar:SetCaption("Starting...")
    end
end
----------------------------------------------------------
CompileMapFinished = Command:extends{}
CompileMapFinished.className = "CompileMapFinished"

function CompileMapFinished:execute()
    if SB.compileMapProgressID then
        SB.ActionProgress(SB.compileMapProgressID, 0.8, "Exporting archive: Map compiled")
    end
    if SB.compileMapProgressBar then
        SB.compileMapProgressBar:SetValue(100)
        SB.compileMapProgressBar:SetCaption("Finished")
    end
end
----------------------------------------------------------
CompileMapError = Command:extends{}
CompileMapError.className = "CompileMapError"

function CompileMapError:init(msg)
    self.msg = msg
end

function CompileMapError:execute()
    Log.Error("Failed to compile map: " .. tostring(self.msg))
    if SB.compileMapProgressBar then
        SB.compileMapProgressBar:SetCaption("Error")
        SB.compileMapProgressBar.tooltip = tostring(self.msg)
    end
end
