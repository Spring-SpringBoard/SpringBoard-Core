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
        license = "MIT",
        layer   = -10000,
        enabled = true,
        handler = true,
        api     = true,
    }
end
local _s11n
function gadget:Initialize()
    LCS = loadstring(VFS.LoadFile(LCS_FOLDER .. "/LCS.lua"))
    LCS = LCS()

    VFS.Include(S11N_FOLDER .. "/s11n.lua", nil, VFS.ZIP)
    -- Export Gadget Globals
    _s11n = s11n.instance
    GG.s11n = _s11n

    -- _s11n:Populate() -- we let SB control this
end

function gadget:UnitCreated(unitID)
    _s11n:GetUnitS11N():_ObjectCreated(unitID)
end
function gadget:FeatureCreated(featureID)
    _s11n:GetFeatureS11N():_ObjectCreated(featureID)
end
function gadget:UnitDestroyed(unitID, ...)
    _s11n:GetUnitS11N():_ObjectDestroyed(unitID, ...)
end
function gadget:FeatureDestroyed(featureID, ...)
    _s11n:GetFeatureS11N():_ObjectDestroyed(featureID, ...)
end
function gadget:GameFrame()
    _s11n:GetFeatureS11N():_GameFrame()
    _s11n:GetUnitS11N():_GameFrame()
end
