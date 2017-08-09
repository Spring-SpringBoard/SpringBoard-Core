SB.Include(Path.Join(SB_VIEW_DIR, "grid_view.lua"))

SavedBrushes = GridView:extends{}

function SavedBrushes:init(opts)
    self.editor = opts.editor
    self:super("init", opts)

    self.brushManager = SB.model.brushManagers:GetBrushManager(opts.name)
    self.brushManager:addListener(self)
    self:_UpdateBrushes()
end

function SavedBrushes:GetSelectedBrush()
    local item = self:GetSelectedItems()[1]
    if not item then
        return
    end

    return self.brushManager:GetBrush(item.brushID)
end

function SavedBrushes:UpdateBrush(brushID, key, value)
    self.brushManager:UpdateBrush(brushID, key, value)
end

function SavedBrushes:RefreshBrushImage(brushID)
    SB.delayGL(function()
        local brush = self.brushManager:GetBrush(brushID)
        local texName = self.GetBrushImage(brush)
        self.brushManager:UpdateBrushImage(brushID, texName)
    end)
end

function SavedBrushes:SelectBrush(brushID)
    for itemIdx, item in pairs(self:GetAllItems()) do
        if item.brushID == brushID then
            self:SelectItem(itemIdx)
            return
        end
    end
end

function SavedBrushes:OnBrushAdded(brush)
    SB.delayGL(function()
        self:RefreshBrushImage(brush.brushID)
    end)
    self:_UpdateBrushes()
end

function SavedBrushes:OnBrushRemoved(brush)
    self:_UpdateBrushes()
end

function SavedBrushes:OnBrushUpdated()
end

function SavedBrushes:OnBrushImageUpdated(brush, image)
    for itemIdx, item in pairs(self:GetAllItems()) do
        if item.brushID == brush.brushID then
            item.imgCtrl.file = image
            item:Invalidate()
            break
        end
    end
end

function SavedBrushes:_LoadBrush(item)
    local brushID = item.brushID
    if not brushID then
        return
    end
    local brush = self.brushManager:GetBrush(brushID)
    assert(brush, "No brush for brushID: " .. tostring(brushID))

    self.editor.__initializing = true
    self.editor:Load(brush.opts)
    self.editor.__initializing = false
    --self.brushTextureImages.control:DeselectAll()
    --self.textureBrowser.control:DeselectAll()
end

function SavedBrushes:_OnSelectItem(obj, itemIdx, selected)
    local item = self:_OnValidateSelectItem(obj, itemIdx, selected)
	if item then
        if selected then
            self:_LoadBrush(item)
        end
        CallListeners(self.OnSelectItem, item, selected)
	end
end

function SavedBrushes:_UpdateBrushes()
    self:ClearItems()
    self:StartMultiModify()
    self:PopulateItems()
    self:EndMultiModify()
end

function SavedBrushes:AddBrush(brush)
    return self.brushManager:AddBrush(brush)
end

function SavedBrushes:RemoveBrush(brushID)
    self.brushManager:RemoveBrush(brushID)
end

function SavedBrushes:_AddAddBrush()
    local addBrush = self:NewItem({
        tooltip = "Add new brush",
        children = {
            Button:New {
                x = 0, y = 0, right = 0, bottom = 0,
                caption = "",
                padding = {5, 5, 5, 5},
                children = {
                    Image:New {
                        x = 0, y = 0, right = 0, bottom = 15,
                        file = Path.Join(SB_IMG_DIR, "plus.png"),
                    },
                    Label:New {
                        x = 0, height = 10, right = 0, bottom = 0,
                        align = 'center',
                        autosize = false,
                        caption = "Add",
                    }
                },
                OnClick = {
                    function()
                        local brush = self.GetNewBrush()
                        local brushID = self:AddBrush(brush)
                        self:SelectBrush(brushID)
                    end
                }
            },
        }
    })
    --local addBrush = self:AddItem("Add", Path.Join(SB_IMG_DIR, "add-plus-button.png"), "Add new brush")
    addBrush.__add_brush = true
    addBrush.__no_background = true
end

function SavedBrushes:_MakeCloseButton(brushID)
    local btnClose = Button:New {
        caption = "",
        width = 20,
        height = 20,
        right = 0,
        y = 0,
        padding = {2, 2, 2, 2},
        tooltip = "Remove brush",
        classname = "negative_button",
        children = {
            Image:New {
                file = SB_IMG_DIR .. "cancel.png",
                height = "100%",
                width = "100%",
            },
        },
        OnClick = {
            function()
                self:RemoveBrush(brushID)
                self:_UpdateBrushes()
            end
        }
    }
    return btnClose
end

function SavedBrushes:PopulateItems()
    if not self.disableAdd then
        self:_AddAddBrush()
    end
    for _, brushID in pairs(self.brushManager:GetBrushes()) do
        local brush = self.brushManager:GetBrush(brushID)
        local item = self:AddItem(brush.caption, brush.image, brush.tooltip)
        item.brushID = brush.brushID

        if not self.disableRemove then
            local btnClose = self:_MakeCloseButton(brushID)
            item:AddChild(btnClose)
            item.btnClose = btnClose

            item:SetChildLayer(item.imgCtrl, 2)
            item:SetChildLayer(item.btnClose, 1)
        end
        item:Invalidate()
    end

    SB.delay(function()
        self.layoutPanel:Invalidate()
    end)
end
