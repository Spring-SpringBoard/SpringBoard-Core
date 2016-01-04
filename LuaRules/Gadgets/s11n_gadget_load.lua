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
local _s11n
function gadget:Initialize()
    LCS = loadstring(VFS.LoadFile(LCS_FOLDER .. "/LCS.lua"))
    LCS = LCS()

    VFS.Include(S11N_FOLDER .. "/s11n.lua", nil, VFS.DEF_MODE)

    -- Export Gadget Globals
    _s11n = s11n()
    GG.s11n = _s11n
    for _, objectID in pairs(Spring.GetAllUnits()) do
        self:UnitCreated(objectID)
    end
    for _, objectID in pairs(Spring.GetAllFeatures()) do
        self:FeatureCreated(objectID)
    end
end
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    _s11n:GetUnitBridge():_ObjectCreated(unitID)
end
function gadget:FeatureCreated(featureID, allyTeamID)
    _s11n:GetFeatureBridge():_ObjectCreated(featureID)
end
function gadget:GameFrame()
    _s11n:GetFeatureBridge():_GameFrame()
    _s11n:GetUnitBridge():_GameFrame()
end