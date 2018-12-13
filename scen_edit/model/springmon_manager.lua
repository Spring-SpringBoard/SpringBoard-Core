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
        Log.Notice("Extension changed. path: " .. tostring(path))
    end, function(path)
        return String.Starts(path, SB_EXTS_ABS_DIR)
    end)
end

function SpringmonManager:TrackAssets()
    WG.Springmon.AddTracker("SB_ASS", SB_ASSETS_ABS_DIR, function(path)
        self:_OnAssetUpdate(path)
    end, function(path)
        return String.Starts(path, SB_ASSETS_ABS_DIR)
    end)
end

-- Updating assets consists of two tasks:
-- 1. Refreshing all views to include the latest list of assets (easy)
-- 2. Deleting all caches of old textures, including GUI, brushes, etc. (hard)
function SpringmonManager:_OnAssetUpdate(path)
    Log.Notice("Asset changed. path: " .. tostring(path))
    -- 1. Update views
    SB.model.assetsManager:loadAll()
    for _, assetView in pairs(SB._assetViews) do
        assetView:ScanDir()
    end

    -- 2. Update textures (delete cache). This applies to images only
    local ext = (Path.GetExt(path) or ""):lower()
    if table.ifind(SB_IMG_EXTS, ext) then
        -- Delete the global texture just in case (unnecessary?)
        -- gl.DeleteTexture(path)

        -- For each brush delete all matching:
        -- 1. pattern textures
        -- 2. brush textures (diffuse, specular)
        for _, savedBrushes in pairs(SB._savedBrushes) do
            local bm = savedBrushes.brushManager
            for brushID, brush in pairs(bm:GetBrushes()) do
                local found = false
                for name, bt in pairs(brush.opts.brushTexture) do
                    if path:find(bt) then
                        found = true

                        -- table.echo(brush)
                        gl.DeleteTexture(brush.image) -- lua texture (!num)
                        gl.DeleteTexture(bt) -- full path to resource
                        brush.image = nil -- unset the texture so it's recreated
                        SB.model.textureManager:UnCacheTexture(bt)
                    end
                end
                local patternTexture = brush.opts.patternTexture
                if patternTexture ~= nil and path:find(patternTexture) then
                    -- TODO: This won't remove cached textures which are no longer registered as brushes.
                    -- maybe we should iterate through all cached textures and remove matching ones manually?
                    SB.model.textureManager:UnCacheTexture(patternTexture)

                    gl.DeleteTexture(patternTexture)
                    found = true
                end

                if found then
                    SB.delayGL(function()
                        bm:UpdateBrushImage(brushID, savedBrushes.GetBrushImage(brush))
                    end)
                end
            end
        end
    end

    WG.Chotify:Post({
        title = 'Assets updated',
        body = 'The asset folder has been updated: ' ..
                'File: ' .. tostring(path),
        time = 3
    })
end
