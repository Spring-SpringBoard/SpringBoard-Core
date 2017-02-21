s11n = LCS.class{}

VFS.Include(S11N_FOLDER .. "/object_bridge.lua", nil, VFS.DEF_MODE)
VFS.Include(S11N_FOLDER .. "/unit_bridge.lua", nil, VFS.DEF_MODE)
VFS.Include(S11N_FOLDER .. "/feature_bridge.lua", nil, VFS.DEF_MODE)

function s11n:init()
    self.unitBridge         = _UnitBridge()
    self.featureBridge      = _FeatureBridge()
end

function s11n:GetUnitBridge()
    return self.unitBridge
end

function s11n:GetFeatureBridge()
    return self.featureBridge
end

function s11n:Get()
end

function s11n:Set()
end

function boolToNumber(bool)
    if bool then
        return 1
    else
        return 0
    end
end