SB.Include(Path.Join(SB.DIRS.SRC, 'view/editor.lua'))

AssetPickerWindow = Editor:extends{}

function AssetPickerWindow:init(opts)
    Editor.init(self, opts)

    local rootDir = opts.rootDir
    local dir = Path.ExtractDir(opts.path or
        SB.model.assetsManager:ToSpringPath(
            rootDir,
            SB.model.game.defaultAssetsFolder
        ))
    local OnSelectItem = opts.OnSelectItem or {}
    if rootDir then
        dir = SB.model.assetsManager:ToAssetPath(rootDir, dir)
    end
    local name = opts.name

    self.selectedFile = {}

    local bottom = 30
    if opts.expand then
        bottom = 0
    end
    self.assetBrowser = self:MakeAssetView({
        name = name,
        rootDir = rootDir,
        dir = dir,
        OnSelectItem = OnSelectItem,
        bottom = bottom,
        itemWidth = opts.itemWidth,
        itemHeight = opts.itemHeight,
    })
    local children = {
        self.assetBrowser:GetControl(),
    }

    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 0,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )
    if opts.expand then
        self:Finalize(children)
    else
        self:Finalize(children, {
            notMainWindow = true,
            buttons = { "close" },
            disposeOnClose = false
        })
    end
end

function AssetPickerWindow:MakeAssetView(opts)
    return AssetView({
        name = opts.name,
        ctrl = {
            x = 0,
            right = 0,
            y = 0,
            bottom = opts.bottom,
        },
        rootDir = opts.rootDir,
        dir = opts.dir,
        itemWidth = opts.itemWidth,
        itemHeight = opts.itemHeight,
        OnSelectItem = {
            function(item, selected)
                local path = item.path
                if not path then
                    return
                end

                if selected then
                    self.selectedFile[path] = true
                else
                    self.selectedFile[path] = false
                end

                CallListeners(opts.OnSelectItem, path)
            end
        },
    })
end
