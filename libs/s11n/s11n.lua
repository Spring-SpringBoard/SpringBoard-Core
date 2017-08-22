s11n = LCS.class{}

VFS.Include(S11N_FOLDER .. "/object_s11n.lua", nil, VFS.DEF_MODE)
VFS.Include(S11N_FOLDER .. "/unit_s11n.lua", nil, VFS.DEF_MODE)
VFS.Include(S11N_FOLDER .. "/feature_s11n.lua", nil, VFS.DEF_MODE)

function s11n:init()
    self.unitS11N         = _UnitS11N()
    self.featureS11N      = _FeatureS11N()
end

function s11n:MakeNewS11N(name)
    self[name] = _ObjectS11N:extends{}
    return self[name]
end

function s11n:GetUnitS11N()
    return self.unitS11N
end

function s11n:GetFeatureS11N()
    return self.featureS11N
end
