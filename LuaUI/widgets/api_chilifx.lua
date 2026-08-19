if Spring.GetGameRulesParam("sb_ui") ~= "chili" then
    return false
end

function widget:GetInfo()
    return {
        name      = "ChiliFX",
        desc      = "Chili Effects library",
        author    = "gajop",
        license   = "MIT",
        layer     = -999,
        enabled   = true,
        api       = true,
        hidden    = true,
    }
end

LCS = loadstring(VFS.LoadFile("libs_sb/lcs/LCS.lua"))
LCS = LCS()

CHILILFX_DIR = "libs_sb/chilifx/chilifx/"

function widget:Initialize()
    ChiliFX = VFS.Include(CHILILFX_DIR .. "core.lua", nil)

    WG.ChiliFX = ChiliFX()
end

function widget:Shutdown()
    WG.ChiliFX = nil
end
