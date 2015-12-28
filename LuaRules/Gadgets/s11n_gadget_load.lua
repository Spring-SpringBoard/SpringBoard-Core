----------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Copy this file to the luarules/gadgets folder

-- Set this line to the s11n installation folder
S11N_FOLDER = "libs/s11n"
LCS_FOLDER  = "libs/lcs"

-- Do NOT modify the following lines
if not gadgetHandler:IsSyncedCode() then
    return
end
function gadget:GetInfo()
    return {
        name    = "s11n gadget",
        desc    = "Spring serialization library gadget",
        author  = "gajop",
        license = "GPLv2",
        layer   = -10000,
        enabled = true,
        handler = true,
        api     = true,
    }
end
function gadget:Initialize()
    LCS = loadstring(VFS.LoadFile(LCS_FOLDER .. "/LCS.lua"))
    LCS = LCS()

    VFS.Include(S11N_FOLDER .. "/s11n.lua", nil, VFS.DEF_MODE)

    -- Export Gadget Globals
    GG.s11n = s11n()
end
