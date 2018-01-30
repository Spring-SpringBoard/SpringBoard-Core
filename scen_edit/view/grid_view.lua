GridView = LCS.class{}

function GridView:init(tbl)
    -- Defaults
    local layoutPanelSettings = {
        selectable = true,
        multiSelect = false,
        autosize = true,
        autoArrangeH = false,
        autoArrangeV = false,
        centerItems  = false,
        itemMargin   = {1, 1, 1, 1},
        iconX = 88,
        iconY = 88,
        --useRTT = true,
        useRTT = true,

        x = 0,
        y = 0,
        width = "100%",
        height = "100%",

        -- FIXME: Shouldn't need to set minWidth
        minWidth = 450,
    }
    local scrollPanelSettings = {
        borderColor = {0,0,0,0},
        padding = {0, 0, 0, 0},
        children = {},

        x = 0,
        y = 0,
        width = "100%",
        height = "100%",
    }
    local holderControlSettings = {
        padding = {0, 0, 0, 0},
        children = {},
        classname = "panel",
    }
    self.OnSelectItem = {}

    self.itemWidth = layoutPanelSettings.iconX
    self.itemHeight = layoutPanelSettings.iconY
    if tbl.itemWidth then
        layoutPanelSettings.iconX = tbl.itemWidth
    end
    if tbl.itemHeight then
        layoutPanelSettings.iconY = tbl.itemHeight
    end
    if tbl.multiSelect then
        layoutPanelSettings.multiSelect = tbl.multiSelect
    end

    local ctrl = tbl.ctrl
    ctrl = Table.Merge(ctrl, holderControlSettings)
    tbl.ctrl = nil

    for k, v in pairs(tbl) do
        self[k] = v
    end

    self.items = {}

    -- we're using the fake control to handle skin-based rendering
    self._fakeControl = ImageListView:New{}

    self.layoutPanel = LayoutPanel:New(layoutPanelSettings)
    self.layoutPanel.HitTest = function(ctrl, x,y)
        local cx,cy = ctrl:LocalToClient(x,y)
        local obj = LayoutPanel.HitTest(ctrl,cx,cy)
        if (obj) then return obj end
        if ctrl._cells == nil then
            return
        end
        local itemIdx = ctrl:GetItemIndexAt(cx,cy)
        return (itemIdx>=0) and ctrl
    end

    self.layoutPanel.DrawItemBkGnd = function(ctrl, index)
        local cell = ctrl._cells[index]
        local itemPadding = ctrl.itemPadding

        local child = ctrl.children[index]
        if child.__no_background then
            return
        end

        if ctrl.selectedItems[index] then
            self._fakeControl:DrawItemBackground(cell[1] - itemPadding[1], cell[2] - itemPadding[2], cell[3] + itemPadding[1] + itemPadding[3], cell[4] + itemPadding[2] + itemPadding[4], "selected")
        else
            self._fakeControl:DrawItemBackground(cell[1] - itemPadding[1], cell[2] - itemPadding[2], cell[3] + itemPadding[1] + itemPadding[3], cell[4] + itemPadding[2] + itemPadding[4], "normal")
        end
    end

    self.layoutPanel.OnSelectItem = {
        function(...)
            self:_OnSelectItem(...)
        end
    }

    table.insert(scrollPanelSettings.children, self.layoutPanel)
    self.scrollPanel = ScrollPanel:New(scrollPanelSettings)

    table.insert(ctrl.children, self.scrollPanel)
    self.holderControl = Control:New(ctrl)
end

function GridView:_OnValidateSelectItem(obj, itemIdx, selected)
    if itemIdx == 0 then
        return
    end
    local item = self.layoutPanel.children[itemIdx]
    return item
end

function GridView:_OnSelectItem(obj, itemIdx, selected)
    local item = self:_OnValidateSelectItem(obj, itemIdx, selected)
    if item then
        CallListeners(self.OnSelectItem, item, selected)
    end
end

function GridView:GetControl()
    return self.holderControl
end

function GridView:GetAllItems()
    return self.items
end

function GridView:GetSelectedItems()
    local items = {}
    for itemIdx, selected in pairs(self.layoutPanel.selectedItems) do
        if selected then
            local item = self.layoutPanel.children[itemIdx]
            table.insert(items, item)
        end
    end
    return items
end

function GridView:GetItem(itemIdx)
    return self.layoutPanel.children[itemIdx]
end

function GridView:GetItemIndex(item)
    for itemIdx, child in pairs(self.contrl.children) do
        if child == item then
            return itemIdx
        end
    end
end

function GridView:SelectItem(itemIdx)
    self.layoutPanel:SelectItem(itemIdx)
end

function GridView:DeselectAll()
    self.layoutPanel:DeselectAll()
end

function GridView:NewItem(tbl)
    local defaults = {
        width  = self.itemWidth,
        height = self.itemHeight,
        padding = {0,0,0,0},
        itemPadding = {0,0,0,0},
        itemMargin = {0,0,0,0},
        useRTT = false,
        __nofont = true,
    }
    tbl = Table.Merge(tbl, defaults)
    local item = Control:New(tbl)

    self.layoutPanel:AddChild(item)
    table.insert(self.items, item)
    return item
end

function GridView:AddItem(caption, image, tooltip, __chiliName)
    local children = {}

    local __chiliImgName
    local __chiliCtrlName
    local __chiliLabelName
    if __chiliName then
        __chiliImgName = __chiliName .. "_image"
        __chiliCtrlName = __chiliName .. "_ctrl"
        __chiliLabelName = __chiliName .. "_label"
    end

    local imgCtrl, lblCtrl
    if image then
        local bottom = 0
        if caption then
            bottom = bottom + 20
        end
        imgCtrl = Image:New {
            x = 0,
            y = 0,
            right = 0,
            bottom = bottom,
            file = image,
            name = __chiliImgName,
        }
        table.insert(children, imgCtrl)
    end
    if caption then
        lblCtrl = Label:New {
            width = "100%",
            x = 0,
            height = 20,
            right = 0,
            bottom = 0,
            align = 'center',
            autosize = false,
            caption = caption,
            --fontsize = 12,
            name = __chiliLabelName,
        }
        table.insert(children, lblCtrl)
    end

    local item = self:NewItem({
        tooltip = tooltip,
        children = children,
        imgCtrl = imgCtrl,
        lblCtrl = lblCtrl,
        name = __chiliCtrlName,
    })
    return item
end

function GridView:ClearItems()
    self.items = {}
    --self.layoutPanel:DeselectAll()
    self.layoutPanel:ClearChildren()
end

function GridView:StartMultiModify()
    self.layoutPanel:DisableRealign()
end

function GridView:EndMultiModify()
    self.layoutPanel:EnableRealign()
    self.layoutPanel:RequestRealign()
    if self.scrollPanel then
        self.scrollPanel:RequestRealign()
        self.scrollPanel:Invalidate()
    end
    self.layoutPanel:UpdateLayout()
    self.layoutPanel:Invalidate()
end
