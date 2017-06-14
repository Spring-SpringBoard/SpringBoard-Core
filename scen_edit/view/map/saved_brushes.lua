SB.Include(Path.Join(SB_VIEW_DIR, "grid_view.lua"))

SavedBrushes = GridView:extends{}

function SavedBrushes:init(opts)
    self.__brushIDCounter = 0

    self.savedBrushes = {}
    self.savedBrushesOrder = {}
    self.editor = opts.editor
    self:super("init", opts)
    self:_UpdateBrushes()
    self.layoutPanel:DeselectAll()
end

function SavedBrushes:GetSelectedBrush()
    local item = self:GetSelectedItems()[1]
    if not item then
        return
    end

    return self.savedBrushes[item.brushID]
end

function SavedBrushes:UpdateBrush(brushID, name, value)
    local brush = self.savedBrushes[brushID]
    brush.opts[name] = value
end

function SavedBrushes:UpdateBrushImage(brushID, image)
    local brush = self.savedBrushes[brushID]
    brush.image = image
    for itemIdx, item in pairs(self:GetAllItems()) do
        if item.brushID == brushID then
            item.imgCtrl.file = image
            item:Invalidate()
        end
    end
end

function SavedBrushes:SelectBrush(brushID)
    for itemIdx, item in pairs(self:GetAllItems()) do
        if item.brushID == brushID then
            self:SelectItem(itemIdx)
            return
        end
    end
end

function SavedBrushes:__AddBrush(brush)
    self.__brushIDCounter = self.__brushIDCounter + 1
    brush.brushID = self.__brushIDCounter
    self.savedBrushes[brush.brushID] = brush
    table.insert(self.savedBrushesOrder, brush.brushID)
    self:_UpdateBrushes()
    return brush.brushID
end

function SavedBrushes:_LoadBrush(item)
    local brushID = item.brushID
    if not brushID then
        return
    end
    local brush = self.savedBrushes[brushID]
    assert(brush, "No brush for brushID: " .. tostring(brushID))

    self.editor.initializing = true
    self.editor:Load(brush.opts)
    self.editor.initializing = false
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
                        local brushID = self:__AddBrush(brush)
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

function SavedBrushes:_MakeCloseButton(closeBrushID)
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
                self.savedBrushes[closeBrushID] = nil
                for i, brushID in pairs(self.savedBrushesOrder) do
                    if closeBrushID == brushID then
                        table.remove(self.savedBrushesOrder, i)
                    end
                end
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
    for _, brushID in pairs(self.savedBrushesOrder) do
        local brush = self.savedBrushes[brushID]
        local item = self:AddItem(brush.caption, brush.image, brush.tooltip)
        item.brushID = brush.brushID

        if not self.disableRemove then
            local btnClose = self:_MakeCloseButton()
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
