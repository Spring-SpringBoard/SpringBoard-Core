function gadget:GetInfo()
    return {
        name    = "s11n map feature loader",
        desc    = "s11n gadget for loading map features",
        author  = "gajop",
        license = "GPLv2",
        layer   = -10000,
        enabled = true,
    }
end

-- MODIFY THIS TO LOAD FEATURES FROM FILE
-- e.g.
-- local modelPath = "mapconfig/s11n_model.lua"
local modelPath = nil
-- DO NOT MODIFY ANYTHING ELSE

local LOG_LEVEL = LOG.NOTICE

if not gadgetHandler:IsSyncedCode() then
    return false
end

if (Spring.GetGameFrame() >= 1) then
  return false
end

function gadget:GamePreload()
    s11n = GG.s11n

    if not modelPath then
        Spring.Log("s11n", LOG.WARNING, "No s11n model file.")
        return
    end

    Spring.Log("s11n", LOG_LEVEL, "Loading s11n file...")
    local modelString = VFS.LoadFile(modelPath, VFS.ZIP)

    Spring.Log("s11n", LOG_LEVEL, "Parsing model...")
    local mission = loadstring(modelString)()

    Spring.Log("s11n", LOG_LEVEL, "Populating game world...")
    for name, objectS11N in pairs(s11n.s11nByName) do
        if mission[name] then
            objectS11N:Add(mission[name])
        end
    end
    Spring.Log("s11n", LOG_LEVEL, "s11n loading complete.")
end
