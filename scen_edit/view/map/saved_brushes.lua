SB.Include(Path.Join(SB_VIEW_DIR, "grid_view.lua"))

SavedBrushes = GridView:extends{}

function SavedBrushes:init(...)
    self.savedBushes = {}
    self:super("init", ...)
end

function SavedBrushes:AddBrush(caption, image, tooltip, opts)
    table.insert(self.savedBushes, {
        caption = caption,
        image = image,
        tooltip = tooltip,
        opts = opts
    })
    Spring.Echo(image)
    self:_UpdateBrushes()
end

function SavedBrushes:_UpdateBrushes()
    self.control:DeselectAll()
    self.control:DisableRealign()
    self.control:ClearChildren()

    self:PopulateItems()

    self.control:EnableRealign()
    self.control:RequestRealign()
    if self.control.parent then
        Spring.Echo("REQ ALIGN")
        self.control.parent:RequestRealign()
        self.control.parent:Invalidate()
    end
    self.control:UpdateLayout()
    self.control:Invalidate()
end

function SavedBrushes:PopulateItems()
    for _, brush in pairs(self.savedBushes) do
        local item = self:AddItem(brush.caption, brush.image, brush.tooltip)
        item.opts = brush.opts
        Spring.Echo("item.opts", item.opts)
    end
end
