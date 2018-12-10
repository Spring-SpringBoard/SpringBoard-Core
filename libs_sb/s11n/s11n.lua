s11n = LCS.class{}

function s11n:init()
    self.s11nByName = {}
    self.s11nDefs = {
        unit = _UnitS11N,
        feature = _FeatureS11N,
    }
end

function s11n:__CreateDefaults()
    VFS.Include(S11N_FOLDER .. "/object_s11n.lua", nil, VFS.ZIP)
    VFS.Include(S11N_FOLDER .. "/unit_s11n.lua", nil, VFS.ZIP)
    VFS.Include(S11N_FOLDER .. "/feature_s11n.lua", nil, VFS.ZIP)

    _UnitS11N.__name = "unitS11N"
    _FeatureS11N.__name = "featureS11N"
    _UnitS11N()
    _FeatureS11N()
end

-- Register class
function s11n:MakeNewS11N(name)
    self.s11nDefs[name] = _ObjectS11N:extends{}
    self.s11nDefs[name].__name = name
    return self.s11nDefs[name]
end

function s11n:GetUnitS11N()
    return self.unitS11N
end

function s11n:GetFeatureS11N()
    return self.featureS11N
end

function s11n:Populate()
    for _, objectID in pairs(Spring.GetAllUnits()) do
        gadget:UnitCreated(objectID)
    end
    for _, objectID in pairs(Spring.GetAllFeatures()) do
        gadget:FeatureCreated(objectID)
    end
end

s11n.instance = s11n()
s11n.instance:__CreateDefaults()
