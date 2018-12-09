SpringmonManager = Observable:extends{}

function SpringmonManager:init()
    self:super('init')

    if not WG.Springmon then
        return
    end

    if SB_ASSETS_ABS_DIR then
        self:TrackAssets()
    end
    if SB_EXTS_ABS_DIR then
        self:TrackExtensions()
    end
end

function SpringmonManager:TrackExtensions()
    WG.Springmon.AddTracker("SB_EXT", SB_EXTS_ABS_DIR, function(path)
        Spring.Echo("Extension changed. path: ", path)
    end, function(path)
        return String.Starts(path, SB_EXTS_ABS_DIR)
    end)
end

function SpringmonManager:TrackAssets()
    WG.Springmon.AddTracker("SB_ASS", SB_ASSETS_ABS_DIR, function(path)
        Spring.Echo("Asset changed. path: ", path)
        SB.model.assetsManager:loadAll()
        for _, assetView in pairs(SB._assetViews) do
            Spring.Echo('rescan')
            assetView:ScanDir()
        end
        -- rescan dirs
    end, function(path)
        return String.Starts(path, SB_ASSETS_ABS_DIR)
    end)
end

