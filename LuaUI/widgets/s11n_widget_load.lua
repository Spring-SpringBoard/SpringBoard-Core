----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Copy this file to the luaui/widgets folder

-- Set this line to the s11n installation folder
S11N_FOLDER = "libs/s11n"
LCS_FOLDER  = "libs/lcs"

-- Do NOT modify the following lines

function widget:GetInfo()
    return {
        name      = "s11n widget",
        desc      = "Spring serialization library",
        author    = "gajop",
        license   = "GPLv2",
        layer     = -10000,
        enabled   = true,
        handler   = true,
        api       = true,
        hidden    = true,
    }
end
function widget:Initialize()
    LCS = loadstring(VFS.LoadFile(LCS_FOLDER .. "/LCS.lua"))
    LCS = LCS()

    VFS.Include(S11N_FOLDER .. "/s11n.lua", nil, VFS.DEF_MODE)

    -- Export Widget Globals
    WG.s11n = s11n()
end