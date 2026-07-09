GridView = LCS.class{}

local __gridViewCounter = 0
function GridView:init(tbl)
    -- Defaults
    __gridViewCounter = __gridViewCounter + 1
    local layoutPanelSettings = {
        name = "grid_view_" .. tostring(__gridViewCounter),
        greedyHitText = true,
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

    if tbl.itemWidth then
        layoutPanelSettings.iconX = tbl.itemWidth
    end
    if tbl.itemHeight then
        layoutPanelSettings.iconY = tbl.itemHeight
    end
    if tbl.multiSelect then
        layoutPanelSettings.multiSelect = tbl.multiSelect
    end
    self.itemWidth = layoutPanelSettings.iconX
    self.itemHeight = layoutPanelSettings.iconY

    local ctrlOpt = tbl.ctrl or {}
    ctrlOpt = Table.Merge(ctrlOpt, holderControlSettings)
    tbl.ctrl = nil

    for k, v in pairs(tbl) do
        self[k] = v
    end
    self.gridId = self.gridId or self.name or layoutPanelSettings.name

    self.items = {}

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
    return self.holderControl
end

function GridView:GetAllItems()
    return self.items
end

function GridView:GetSelectedItems()
    local items = {}
    if SB.useRmlUi then
        for item, selected in pairs(self._rmlSelected or {}) do
            if selected then
                table.insert(items, item)
            end
        end
        return items
    end
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
    if SB.useRmlUi then
        local item = self.items[itemIdx]
        if item then
            self._rmlSelected = self._rmlSelected or {}
            self._rmlSelected[item] = true
            local document = self:_GetRmlUiDocument()
            if document and item.__rmlId then
                local el = document:GetElementById(item.__rmlId)
                if el then
                    el:SetClass("selected", true)
                end
            end
        end
        return
    end
    self.layoutPanel:SelectItem(itemIdx)
end

function GridView:DeselectAll()
    if SB.useRmlUi then
        local document = self:_GetRmlUiDocument()
        for item in pairs(self._rmlSelected or {}) do
            if document and item.__rmlId then
                local el = document:GetElementById(item.__rmlId)
                if el then
                    el:SetClass("selected", false)
                end
            end
        end
        self._rmlSelected = {}
    end
    if self.layoutPanel then
        self.layoutPanel:DeselectAll()
    end
end

-- FIXME: Cleanup double click handling hack
local __gridItemCounter = 0
local __previousClickedObject = nil
local __previousClickedTime = nil

function GridView:NewItem(tbl)
    __gridItemCounter = __gridItemCounter + 1
    local item
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

    self.layoutPanel:AddChild(item)
    table.insert(self.items, item)
    -- Bump the item-set version so the RmlUi grid knows to do a full rebuild
    -- (rather than just a visibility toggle) next time it renders.
    self._itemsVersion = (self._itemsVersion or 0) + 1
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
    -- Keep the raw caption/image around for the RmlUi renderer, which builds
    -- its own markup instead of reusing the Chili child controls.
    item.__caption = caption
    item.__image = image
    return item
end

function GridView:DoubleClickItem(item)
end

function GridView:ClearItems()
    self.items = {}
    self._rmlSelected = {}
    self._itemsVersion = (self._itemsVersion or 0) + 1
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
    if SB.useRmlUi then
        self:_UpdateRmlUiGrid()
    end
end

function GridView:Invalidate()
    if self.scrollPanel then
        self.scrollPanel:Invalidate()
    end
    if self.layoutPanel then
        self.layoutPanel:Invalidate()
    end
    if SB.useRmlUi then
        self:_UpdateRmlUiGrid()
    end
end

--------------------------------------------------------------------------------
-- RmlUi rendering
--
-- In RmlUi mode the grid content lives inside a <div class="grid-container">
-- placed by the editor/field. GridView still builds its Chili controls for
-- compatibility, but the visible grid is rendered here from the raw item data.
--------------------------------------------------------------------------------

local function _EscapeRml(text)
    text = tostring(text or "")
    text = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    return text
end

-- Tooltips carry Spring colour codes ("\255rgb" plus "\b" to reset) and
-- newlines. Those raw control bytes corrupt the `title` attribute and made
-- RmlUi terminate the element early, so the label ended up as a sibling of the
-- cell instead of a child.
local function _EscapeAttribute(text)
    text = tostring(text or "")
    text = text:gsub("\255...", "")   -- colour code: marker + 3 bytes
    text = text:gsub("[\1-\31]", " ") -- control chars, incl. \b and newlines
    text = _EscapeRml(text)
    text = text:gsub('"', "&quot;")
    return text
end

function GridView:_GetRmlUiDocument()
    -- Pickers hand us their own dialog document. Without this the grid rendered
    -- into the main document instead, so the picker dialog came up empty.
    if self.document then
        return self.document
    end
    local editor = self.editor or (self.pathNav and self.pathNav.editor)
    return (editor and editor.document) or SB.view.mainDocument
end

-- Resolve a Chili-style image spec into something an RmlUi <img> can load.
-- Returns nil when the image can't be rendered (e.g. engine build pics).
function GridView:_ResolveRmlUiImage(image)
    if not image or image == "" then
        return nil
    end
    -- Engine build-picture / icon specs ("#123") are not file backed.
    if image:sub(1, 1) == "#" then
        return nil
    end
    -- Strip Chili texture decorations such as ":clr88,88:path".
    local decorated = image:match("^:[%w,]+:(.+)$")
    if decorated then
        image = decorated
    end
    -- Absolute, already-relative, or URL paths are used verbatim.
    if image:sub(1, 1) == "/" or image:match("^%.%.") or image:match("^%a+://") then
        return image
    end
    -- Repo/VFS-relative paths are resolved relative to the RML document on disk.
    local depth = self.documentDepth or 3
    return string.rep("../", depth) .. image
end

-- Whether an item should currently be shown. The RmlUi grid renders every
-- item in self.items and hides those that fail this predicate. Subclasses with
-- a filter (object-def panels) override it; note self.items and the Chili
-- layoutPanel.children are *different* object sets, so filtering must be by
-- predicate here, not by layoutPanel membership.
function GridView:_RmlUiItemVisible(item)
    return true
end

-- Toggle the .hidden class on already-rendered item elements. This is the cheap
-- path used when only the filter changed: it keeps the <texture>/<img> elements
-- (and their bound live textures) alive instead of rebuilding them.
function GridView:_RefreshRmlUiVisibility()
    local document = self:_GetRmlUiDocument()
    if not document then
        return
    end
    for _, item in ipairs(self.items) do
        if item.__rmlId then
            local el = document:GetElementById(item.__rmlId)
            if el then
                el:SetClass("hidden", not self:_RmlUiItemVisible(item))
            end
        end
    end
end

function GridView:_UpdateRmlUiGrid()
    local document = self:_GetRmlUiDocument()
    if not document then
        return
    end
    local container = document:GetElementById(self.gridId)
    if not container then
        return
    end

    self._rmlSelected = self._rmlSelected or {}
    local version = self._itemsVersion or 0

    -- If the item set is unchanged AND our previously-rendered elements are
    -- still in this container, only the filter/visibility changed -- avoid
    -- destroying and recreating the <texture> elements (which loses their live
    -- RTT content). If the container was rebuilt (e.g. by RefreshContent) the
    -- elements are gone, so fall through to a full render.
    local firstItem = self.items[1]
    local stillRendered = firstItem and firstItem.__rmlId
        and document:GetElementById(firstItem.__rmlId) ~= nil
    if self._rmlRenderedVersion == version and stillRendered then
        self:_RefreshRmlUiVisibility()
        return
    end

    -- Render every item once (visibility handled by the .hidden class), so a
    -- later filter change is a class toggle rather than a rebuild.
    local html = ''
    for index, item in ipairs(self.items) do
        item.__rmlId = self.gridId .. "-item-" .. index
        local classes = "grid-item"
        if item.__no_background then
            classes = classes .. " no-background"
        end
        if self._rmlSelected[item] then
            classes = classes .. " selected"
        end
        if not self:_RmlUiItemVisible(item) then
            classes = classes .. " hidden"
        end
        local tooltip = item.tooltip and (' title="' .. _EscapeAttribute(item.tooltip) .. '"') or ''
        -- Image box then label, both in normal flow. Absolutely positioning the
        -- label over the cell is not reliable here: RmlUi did not treat the
        -- cell as a containing block, so the label escaped to the bottom of the
        -- dialog. Sizes are px (not dp) so the panel dp-ratio cannot shrink them.
        -- display:block inline: some stylesheet gives .grid-item a flex row, which
        -- would place the label beside the thumbnail instead of under it.
        local cellStyle = string.format(' style="width:%dpx;display:block;"', self.itemWidth)
        local boxStyle = string.format(' style="width:%dpx;height:%dpx;"', self.itemWidth, self.itemHeight)
        html = html .. string.format('<div id="%s" class="%s"%s%s>', item.__rmlId, classes, cellStyle, tooltip)
        html = html .. '<div class="grid-item-image-box"' .. boxStyle .. '>'

        -- Item images are either a live Lua RTT texture (3D object previews,
        -- rendered via the <texture> element) or a file-backed thumbnail (<img>).
        if item.__luaTexture then
            -- RTT previews are square, so fill the box.
            html = html .. string.format(
                '<texture class="grid-item-image" src="%s" style="width:100%%;height:100%%;"></texture>',
                _EscapeRml(tostring(item.__luaTexture)))
        else
            local src = self:_ResolveRmlUiImage(item.__image)
            if src then
                -- File thumbnails have varied aspect ratios: fit preserving
                -- aspect rather than stretching.
                html = html .. string.format(
                    '<img class="grid-item-image" src="%s" style="max-width:100%%;max-height:100%%;"></img>',
                    _EscapeRml(src))
            end
        end
        html = html .. '</div>'
        if item.__caption then
            html = html .. '<div class="grid-item-label">' .. _EscapeRml(item.__caption) .. '</div>'
        end
        html = html .. '</div>'
    end
    container.inner_rml = html

    -- Bind click / double-click for each item.
    for index, item in ipairs(self.items) do
        local el = document:GetElementById(item.__rmlId)
        if el then
            if item.OnAddClick then
                -- Action item (e.g. the "+" add-new-brush cell): run its
                -- handler instead of selecting. Reference only upvalues here --
                -- the directly-registered RmlUi callback runs with a stripped
                -- environment where globals like SB are not visible; the method
                -- it calls keeps its own environment.
                el:AddEventListener("click", function()
                    self:_OnRmlUiAddClick(item)
                end)
            else
                el:AddEventListener("click", function()
                    self:_OnRmlUiItemClick(item, index)
                end)
            end
        end
    end

    self._rmlRenderedVersion = version
    self._rmlRenderedGridId = self.gridId
end

function GridView:_SetRmlSelected(item, selected)
    self._rmlSelected[item] = selected or nil
    local document = self:_GetRmlUiDocument()
    if document and item.__rmlId then
        local el = document:GetElementById(item.__rmlId)
        if el then
            el:SetClass("selected", selected == true)
        end
    end
end

-- React to a selection change. Base just fires the OnSelectItem listeners;
-- subclasses (object-def panels) override to drive placement state. Works on
-- the item object directly, since self.items and layoutPanel.children are
-- different object sets under RmlUi.
function GridView:_OnRmlUiSelectionChanged(item, selected)
    CallListeners(self.OnSelectItem, item, selected)
end

function GridView:_OnRmlUiAddClick(item)
    -- Defer so the handler (which may rebuild the grid) doesn't free elements
    -- while RmlUi is still dispatching this click.
    SB.delay(function()
        CallListeners(item.OnAddClick)
    end)
end

function GridView:_OnRmlUiItemClick(item, index)
    self._rmlSelected = self._rmlSelected or {}

    -- Match Chili: a plain click is single-select (replaces the selection) even
    -- on multiSelect grids; Ctrl toggles the clicked item without clearing.
    local _alt, ctrl = Spring.GetModKeyState()
    local additive = self.multiSelect and ctrl

    -- Snapshot what to deselect before mutating the selection.
    local toDeselect = {}
    if not additive then
        for other in pairs(self._rmlSelected) do
            if other ~= item then
                toDeselect[#toDeselect + 1] = other
            end
        end
    end

    local nowSelected
    if additive then
        nowSelected = not self._rmlSelected[item]
    else
        nowSelected = true
    end

    -- Apply the visual selection immediately (class toggles only, no DOM
    -- structure change).
    for _, other in ipairs(toDeselect) do
        self:_SetRmlSelected(other, false)
    end
    self:_SetRmlSelected(item, nowSelected)

    -- Defer the selection notifications. They can rebuild the editor DOM
    -- (state changes -> RefreshContent), which is a use-after-free if done
    -- while RmlUi is still dispatching this click event and would free the
    -- very elements being processed.
    SB.delay(function()
        for _, other in ipairs(toDeselect) do
            self:_OnRmlUiSelectionChanged(other, false)
        end
        self:_OnRmlUiSelectionChanged(item, nowSelected)
    end)

    -- Double-click detection mirrors the Chili timing hack.
    local now = Spring.GetTimer()
    if self.__rmlLastClickItem == item and self.__rmlLastClickTime and
       Spring.DiffTimers(now, self.__rmlLastClickTime) < 0.45 then
        self.__rmlLastClickItem = nil
        self.__rmlLastClickTime = nil
        self:DoubleClickItem(item)
    else
        self.__rmlLastClickItem = item
        self.__rmlLastClickTime = now
    end
end
