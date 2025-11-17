GridView = LCS.class{}

local __gridViewCounter = 0
function GridView:init(tbl)
    -- Defaults
    __gridViewCounter = __gridViewCounter + 1

    self.OnSelectItem = {}
    self.items = {}

    -- Store configuration
    self.itemWidth = tbl.itemWidth or 88
    self.itemHeight = tbl.itemHeight or 88
    self.multiSelect = tbl.multiSelect or false

    -- Copy all properties from tbl to self
    for k, v in pairs(tbl) do
        if k ~= "ctrl" then
            self[k] = v
        end
    end

    -- Check if we're in RmlUi mode
    if SB.view and SB.view.useRmlUi then
        self:_InitRmlUi(tbl)
    else
        self:_InitChili(tbl)
    end
end

function GridView:_InitRmlUi(tbl)
    -- In RmlUi mode, we don't create Chili controls
    -- The grid will be rendered to RmlUi DOM by the View class
    self.gridId = "grid_view_" .. tostring(__gridViewCounter)
    self.selectedIndices = {}
    self.childItems = {}  -- Stores items added via AddChildItem
end

function GridView:_InitChili(tbl)
    local layoutPanelSettings = {
        name = "grid_view_" .. tostring(__gridViewCounter),
        greedyHitText = true,
        selectable = true,
        multiSelect = self.multiSelect,
        autosize = true,
        autoArrangeH = false,
        autoArrangeV = false,
        centerItems  = false,
        itemMargin   = {1, 1, 1, 1},
        iconX = self.itemWidth,
        iconY = self.itemHeight,
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

    local ctrlOpt = tbl.ctrl
    ctrlOpt = Table.Merge(ctrlOpt, holderControlSettings)

    -- we're using the fake control to handle skin-based rendering
    self._fakeControl = ImageListView:New{}

    self.layoutPanel = LayoutPanel:New(layoutPanelSettings)

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

    table.insert(ctrlOpt.children, self.scrollPanel)
    self.holderControl = Control:New(ctrlOpt)
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
    if self.holderControl then
        return self.holderControl
    else
        -- RmlUi mode - return a placeholder that won't break code expecting it
        return { _isRmlUiPlaceholder = true }
    end
end

function GridView:GetAllItems()
    return self.items
end

function GridView:GetSelectedItems()
    if self.layoutPanel then
        local items = {}
        for itemIdx, selected in pairs(self.layoutPanel.selectedItems) do
            if selected then
                local item = self.layoutPanel.children[itemIdx]
                table.insert(items, item)
            end
        end
        return items
    else
        -- RmlUi mode
        local items = {}
        for itemIdx, selected in pairs(self.selectedIndices) do
            if selected then
                local item = self.childItems[itemIdx]
                if item then
                    table.insert(items, item)
                end
            end
        end
        return items
    end
end

function GridView:GetItem(itemIdx)
    if self.layoutPanel then
        return self.layoutPanel.children[itemIdx]
    else
        -- RmlUi mode
        return self.childItems[itemIdx]
    end
end

function GridView:GetItemIndex(item)
    for itemIdx, child in pairs(self.contrl.children) do
        if child == item then
            return itemIdx
        end
    end
end

function GridView:SelectItem(itemIdx)
    if self.layoutPanel then
        self.layoutPanel:SelectItem(itemIdx)
    else
        -- RmlUi mode
        if not self.multiSelect then
            self.selectedIndices = {}
        end
        self.selectedIndices[itemIdx] = true
        self:_UpdateRmlUiGrid()
        self:_OnSelectItem(nil, itemIdx, true)
    end
end

function GridView:DeselectAll()
    if self.layoutPanel then
        self.layoutPanel:DeselectAll()
    else
        -- RmlUi mode
        self.selectedIndices = {}
        self:_UpdateRmlUiGrid()
    end
end

-- FIXME: Cleanup double click handling hack
local __gridItemCounter = 0
local __previousClickedObject = nil
local __previousClickedTime = nil

function GridView:NewItem(tbl)
    __gridItemCounter = __gridItemCounter + 1
    local item

    if self.layoutPanel then
        -- Chili mode
        local defaults = {
            name = 'grid_item' .. tostring(__gridItemCounter),
            greedyHitText = true,
            width  = self.itemWidth,
            height = self.itemHeight,
            padding = {0,0,0,0},
            itemPadding = {0,0,0,0},
            itemMargin = {0,0,0,0},
            useRTT = false,
            __nofont = true,
            -- FIXME: Cleanup double click handling hack
            OnMouseUp = {
                function(obj, x, y, button)
                    if button ~= 1 then
                        return
                    end

                    local now = Spring.GetTimer()
                    if __previousClickedObject ~= obj then
                        __previousClickedObject = obj
                        __previousClickedTime = now
                        return
                    end

                    if Spring.DiffTimers(now, __previousClickedTime) < 0.45 then
                        self:DoubleClickItem(item)
                    end
                    __previousClickedTime = now
                end
            }
        }
        tbl = Table.Merge(tbl, defaults)
        item = Control:New(tbl)

        -- Add wrapper method to items for setting images
        item.SetImage = function(self, imagePath)
            if self.imgCtrl then
                self.imgCtrl.file = imagePath
                self:Invalidate()
            end
        end

        self.layoutPanel:AddChild(item)
    else
        -- RmlUi mode - create simple table item
        local gridView = self  -- Capture reference to parent grid
        item = {
            name = 'grid_item' .. tostring(__gridItemCounter),
            tooltip = tbl.tooltip,
            children = tbl.children or {},
        }

        -- Add wrapper method for setting images
        item.SetImage = function(self, imagePath)
            self.image = imagePath
            -- Trigger grid update when image changes (for RTT updates)
            if gridView then
                gridView:_UpdateRmlUiGrid()
            end
        end

        -- Stub methods that might be called
        item.Invalidate = function()
            -- Trigger grid refresh when item is invalidated (e.g., RTT texture updated)
            if gridView then
                gridView:_UpdateRmlUiGrid()
            end
        end
        item.IsInView = function() return true end
        item.AddChild = function() end
        item.SetChildLayer = function() end
    end

    table.insert(self.items, item)
    return item
end

function GridView:AddItem(caption, image, tooltip, __chiliName)
    if self.layoutPanel then
        -- Chili mode
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
    else
        -- RmlUi mode
        local item = self:NewItem({
            tooltip = tooltip,
        })
        item.caption = caption
        item.image = image
        return item
    end
end

function GridView:DoubleClickItem(item)
end

function GridView:ClearItems()
    self.items = {}
    --self.layoutPanel:DeselectAll()
    self:ClearChildren()
end

-- Wrapper methods to hide layoutPanel access
function GridView:ClearChildren()
    if self.layoutPanel then
        self.layoutPanel:ClearChildren()
    else
        -- RmlUi mode
        self.childItems = {}
        self:_UpdateRmlUiGrid()
    end
end

function GridView:AddChildItem(item)
    if self.layoutPanel then
        self.layoutPanel:AddChild(item)
    else
        -- RmlUi mode
        table.insert(self.childItems, item)
        self:_UpdateRmlUiGrid()
    end
end

function GridView:GetChildItem(idx)
    if self.layoutPanel then
        return self.layoutPanel.children[idx]
    else
        -- RmlUi mode
        return self.childItems[idx]
    end
end

function GridView:Invalidate()
    if self.layoutPanel then
        self.layoutPanel:Invalidate()
    else
        -- RmlUi mode
        self:_UpdateRmlUiGrid()
    end
end

function GridView:_UpdateRmlUiGrid()
    -- Skip updates during batching
    if self._batchingUpdates then
        return
    end

    -- Throttle updates to avoid excessive DOM manipulation (e.g., from RTT invalidations)
    -- Maximum 10 updates per second
    local now = Spring.GetTimer()
    if self._lastUpdateTime then
        local elapsed = Spring.DiffTimers(now, self._lastUpdateTime)
        if elapsed < 0.1 then
            -- Too soon, schedule delayed update
            if not self._updateScheduled then
                self._updateScheduled = true
                SB.delay(function()
                    self._updateScheduled = false
                    self:_UpdateRmlUiGrid()
                end)
            end
            return
        end
    end
    self._lastUpdateTime = now

    -- Update the RmlUi DOM to reflect current grid state
    -- This will be called whenever the grid needs to refresh
    if not SB.view or not SB.view.mainDocument then
        return
    end

    local gridContainer = SB.view.mainDocument:GetElementById(self.gridId)
    if not gridContainer then
        return
    end

    -- Generate HTML for all child items
    local html = ""
    for idx, item in ipairs(self.childItems) do
        local itemId = self.gridId .. "_item_" .. idx
        local selectedClass = self.selectedIndices[idx] and " selected" or ""

        -- Check if this is a special "Add" button item (SavedBrushes)
        local noBackground = item.__no_background and " no-background" or ""
        html = html .. string.format([[
            <div id="%s" class="grid-item%s%s" style="width: %ddp; height: %ddp;">
        ]], itemId, selectedClass, noBackground, self.itemWidth, self.itemHeight)

        -- Handle special "Add brush" item
        if item.__add_brush and item.OnAddClick then
            local addIconPath = item.addIcon or "LuaUI/images/scenedit/plus.png"
            if addIconPath:sub(1, 6) == "LuaUI/" then
                addIconPath = "../../../" .. addIconPath
            end
            html = html .. string.format([[
                <button id="%s-add-btn" class="add-brush-button">
                    <img src="%s" class="add-brush-icon"/>
                    <span class="add-brush-label">Add</span>
                </button>
            ]], itemId, addIconPath)
        -- Normal grid item
        elseif item.image then
            local imagePath = item.image
            -- Handle both file paths (strings) and texture IDs (numbers/tables)
            if type(imagePath) == "string" then
                -- Check if it's already a texture reference (!texID format)
                if imagePath:sub(1, 1) == "!" then
                    -- Already a texture reference from gl.CreateTexture, use <texture> tag
                    html = html .. string.format('<texture src="%s" class="grid-item-image"/>', imagePath)
                else
                    -- Regular file path
                    if imagePath:sub(1, 6) == "LuaUI/" then
                        imagePath = "../../../" .. imagePath
                    end
                    html = html .. string.format('<img src="%s" class="grid-item-image"/>', imagePath)
                end
            elseif type(imagePath) == "number" then
                -- OpenGL texture ID from gl.CreateTexture
                -- Format: !<texID> for RmlUi texture references, use <texture> tag
                html = html .. string.format('<texture src="!%d" class="grid-item-image"/>', imagePath)
            else
                -- Texture table/object - try to extract ID or convert to string
                local texId = imagePath.texID or imagePath.id or tostring(imagePath)
                html = html .. string.format('<texture src="!%s" class="grid-item-image"/>', tostring(texId))
            end
        end

        -- Add caption if present
        if item.caption then
            html = html .. string.format('<div class="grid-item-label">%s</div>', item.caption)
        end

        -- Add remove button if item has one (SavedBrushes)
        if item.OnRemoveClick then
            local removeIconPath = item.removeIcon or "LuaUI/images/scenedit/cancel.png"
            if removeIconPath:sub(1, 6) == "LuaUI/" then
                removeIconPath = "../../../" .. removeIconPath
            end
            html = html .. string.format([[
                <button id="%s-remove-btn" class="remove-brush-button" title="Remove brush">
                    <img src="%s"/>
                </button>
            ]], itemId, removeIconPath)
        end

        html = html .. '</div>'
    end

    gridContainer.inner_rml = html

    -- Bind click events for selection and special buttons
    local callListeners = CallListeners  -- Capture for closures
    for idx, item in ipairs(self.childItems) do
        local itemId = self.gridId .. "_item_" .. idx

        -- Bind "Add" button click
        if item.__add_brush and item.OnAddClick then
            local addBtn = SB.view.mainDocument:GetElementById(itemId .. "-add-btn")
            if addBtn then
                addBtn:AddEventListener("click", function(event)
                    callListeners(item.OnAddClick)
                    event:StopPropagation()  -- Don't trigger item selection
                end)
            end
        end

        -- Bind "Remove" button click
        if item.OnRemoveClick then
            local removeBtn = SB.view.mainDocument:GetElementById(itemId .. "-remove-btn")
            if removeBtn then
                removeBtn:AddEventListener("click", function(event)
                    callListeners(item.OnRemoveClick)
                    event:StopPropagation()  -- Don't trigger item selection
                end)
            end
        end

        -- Bind item selection click (if not an add button)
        if not item.__add_brush then
            local itemElement = SB.view.mainDocument:GetElementById(itemId)
            if itemElement then
                itemElement:AddEventListener("click", function()
                    self:_OnRmlUiItemClick(idx)
                end)
            end
        end
    end
end

function GridView:_OnRmlUiItemClick(itemIdx)
    local item = self.childItems[itemIdx]
    if not item then
        return
    end

    -- Check for double-click
    local now = Spring.GetTimer()
    if self._lastClickedItemIdx == itemIdx then
        if Spring.DiffTimers(now, self._lastClickTime) < 0.45 then
            -- Double click
            self:DoubleClickItem(item)
            self._lastClickedItemIdx = nil
            self._lastClickTime = nil
            return
        end
    end
    self._lastClickedItemIdx = itemIdx
    self._lastClickTime = now

    local selected = not self.selectedIndices[itemIdx]

    if not self.multiSelect then
        -- Clear all other selections
        self.selectedIndices = {}
    end

    if selected then
        self.selectedIndices[itemIdx] = true
    else
        self.selectedIndices[itemIdx] = nil
    end

    self:_UpdateRmlUiGrid()
    self:_OnSelectItem(nil, itemIdx, selected)
end

function GridView:StartMultiModify()
    if self.layoutPanel then
        self.layoutPanel:DisableRealign()
    else
        -- RmlUi mode - set flag to batch updates
        self._batchingUpdates = true
    end
end

function GridView:EndMultiModify()
    if self.layoutPanel then
        self.layoutPanel:EnableRealign()
        self.layoutPanel:RequestRealign()
        if self.scrollPanel then
            self.scrollPanel:RequestRealign()
            self.scrollPanel:Invalidate()
        end
        self.layoutPanel:UpdateLayout()
        self.layoutPanel:Invalidate()
    else
        -- RmlUi mode - end batching and update once
        self._batchingUpdates = false
        self:_UpdateRmlUiGrid()
    end
end
