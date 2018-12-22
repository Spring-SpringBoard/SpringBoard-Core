function widget:GetInfo()
    return {
        name      = "Hides the default interface",
        desc      = "",
        author    = "gajop",
        license   = "MIT",
        layer     = 1001,
        enabled   = true,
    }
end

local gameMode
local function SetGameMode(gameMode)
    if gameMode == "play" then
        --Spring.SendCommands("Console 0")
    else
        --Spring.SendCommands("Console 1")
    end
end

function widget:Initialize()
    if not Game.gameName:find("SpringBoard Core") then
        widgetHandler:RemoveWidget(self)
    end
    gameMode = Spring.GetGameRulesParam("gameMode")
    SetGameMode(gameMode)

    -- remove Springs default UI stuff
    Spring.SendCommands("ResBar 0", "ToolTip 0", "Clock 0", "Info 0")
    Spring.SendCommands("showhealthbars 0")
    gl.SlaveMiniMap(true)
    gl.ConfigMiniMap(-1,-1,-1,-1)
end

-- sets status to ready & hide pre-game UI
function widget:GameSetup()
    return true, true
end

function widget:Update()
    local newGameMode = Spring.GetGameRulesParam("gameMode")
    if gameMode ~= newGameMode then
        gameMode = newGameMode
        SetGameMode(gameMode)
    end
end
