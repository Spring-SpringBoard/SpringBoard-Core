SB.Include(Path.Join(SB_VIEW_DIR, "editor_view.lua"))

AssetPickerWindow = EditorView:extends{}

function AssetPickerWindow:init(opts)
    self:super("init")

    local rootDir = opts.rootDir
    local dir = Path.ExtractDir(opts.path or '/')
    local OnSelectItem = opts.OnSelectItem or {}
    dir = SB.model.assetsManager:ToAssetPath(rootDir, dir)

    self.selectedFile = {}

    self.assetBrowser = self:MakeAssetView(rootDir, dir, OnSelectItem)
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
    self:Finalize(children, {notMainWindow = true})
end

function AssetPickerWindow:MakeAssetView(rootDir, dir, OnSelectItem)
    return AssetView({
        ctrl = {
            x = 0,
            right = 0,
            y = 0,
            bottom = 30,
        },
        rootDir = rootDir,
        dir = dir,
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

                CallListeners(OnSelectItem, path)
            end
        },
    })
end
