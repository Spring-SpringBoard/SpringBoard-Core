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
local _s11n
function widget:Initialize()
    LCS = loadstring(VFS.LoadFile(LCS_FOLDER .. "/LCS.lua"))
    LCS = LCS()

    VFS.Include(S11N_FOLDER .. "/s11n.lua", nil, VFS.DEF_MODE)

    -- Export Widget Globals
    _s11n = s11n()
    WG.s11n = _s11n
    for _, objectID in pairs(Spring.GetAllUnits()) do
        self:UnitCreated(objectID)
    end
    for _, objectID in pairs(Spring.GetAllFeatures()) do
        self:FeatureCreated(objectID)
    end
end
function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    _s11n:GetUnitBridge():_ObjectCreated(unitID)
end
function widget:FeatureCreated(featureID, allyTeamID)
    _s11n:GetFeatureBridge():_ObjectCreated(featureID)
end
function widget:GameFrame()
    _s11n:GetFeatureBridge():_GameFrame()
    _s11n:GetUnitBridge():_GameFrame()
end