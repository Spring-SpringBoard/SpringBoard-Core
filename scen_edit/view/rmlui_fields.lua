-- RmlUi Field Type Stubs
-- These are form field components used within editors
-- Implementation-agnostic: No need to touch RML/HTML to add fields!
-- Just use: AddField(StringField({name="foo", title="Foo"}))

-- Only load if RmlUi is available
if not RmlUi then
    return
end

-- Load dependencies for picker windows
SB.Include(Path.Join(SB.DIRS.SRC, 'view/map/material_browser.lua'))

local activeNumericDragField

function RmlUiUpdateNumericDrag()
    if activeNumericDragField then
        activeNumericDragField:UpdateActiveDrag()
    end
end

-- Base Field Class
RmlUiField = LCS.class{}

function RmlUiField:init(opts)
    self.name = opts.name
    self.title = opts.title or opts.name
    self.value = opts.value or ""  -- Default to empty string if no value provided
    self.width = opts.width or 200
    self.element = nil  -- Will be set by BindToDocument()
end

function RmlUiField:BindToDocument()
    local document = (self.ev and self.ev.document) or SB.view.mainDocument
    assert(document, "No document available for field: " .. self.name)
    self.element = document:GetElementById("field-" .. self.name)
    assert(self.element, "Failed to find field element: field-" .. self.name)
    -- Sync stored value to DOM after binding
    self.element:SetAttribute("value", tostring(self.value or ""))
end

function RmlUiField:GetValue()
    return self.value
end

function RmlUiField:SetValue(value)
    self.value = value
    -- Update element if we have one (some fields like expand-mode AssetField don't have elements)
    if self.element then
        self.element:SetAttribute("value", tostring(value or ""))
    end
end

function RmlUiField:Set(value, source)
    local valid, validatedValue = true, value
    if self.Validate then
        valid, validatedValue = self:Validate(value)
    end

    assert(valid, "Invalid value for field: " .. self.name)

    if validatedValue ~= self.value then
        -- Update value and display using SetValue (which subclasses can override)
        -- But don't trigger Update recursively
        local oldValue = self.value
        self:SetValue(validatedValue)

        -- Notify editor even if we don't have an element (e.g., expand-mode AssetFields)
        if self.ev then
            -- Prevent recursive updates by checking if we're already updating this field
            if not self.__inUpdate then
                self.__inUpdate = true
                self.ev:Update(self.name, source)
                self.__inUpdate = false
            end
        end
    end
end

function RmlUiField:Focus()
    if self.element then
        self.element:Focus(true)
    end
end

function RmlUiField:UpdateDisplay()
    -- Override in subclass
end

function RmlUiField:GenerateRml()
    -- Override in subclass to return RML string
    -- This is the ONLY place RML is generated - programmatically!
    return '<div class="field-row"><label class="field-label">' .. self.title .. '</label></div>'
end

-- String Field
RmlUiStringField = RmlUiField:extends{}

function RmlUiStringField:init(opts)
    self:super("init", opts)
end

function RmlUiStringField:GenerateRml()
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")
    local widthStyle = self.width and string.format(' style="width: %dpx;"', self.width) or ''
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="text" id="field-%s" class="field-input"%s value="%s"/></div>',
        title, self.name, widthStyle, self.value or ""
    )
end

-- Numeric Field
RmlUiNumericField = RmlUiField:extends{}

function RmlUiNumericField:init(opts)
    self:super("init", opts)
    self.min = opts.minValue or opts.min
    self.max = opts.maxValue or opts.max
    self.decimals = opts.decimals or 2
    self.format = "%." .. tostring(self.decimals) .. "f"
    self.step = opts.step
    if self.step == nil then
        self.step = 1
        if self.min and self.max then
            self.step = (self.max - self.min) / 200
        end
    end
    self.__dragSensitivity = 3
    self.__shiftMultiplier = 0.1
end

function RmlUiNumericField:Serialize()
    return self.value
end

function RmlUiNumericField:Validate(value)
    local numeric = tonumber(value)
    if not numeric then
        return false, value
    end
    if self.min and numeric < self.min then
        numeric = self.min
    end
    if self.max and numeric > self.max then
        numeric = self.max
    end
    return true, numeric
end

function RmlUiNumericField:Load(data)
    self:Set(data)
end

function RmlUiNumericField:__GetDisplayText()
    return string.format(self.format, tonumber(self.value) or 0)
end

function RmlUiNumericField:__GetButtonRml()
    local title = self.title:gsub(":$", "")
    return string.format(
        '<span class="field-button-title">%s:</span><span class="field-button-value">%s</span>',
        title, self:__GetDisplayText()
    )
end

function RmlUiNumericField:GenerateRml()
    local widthStyle = self.width and string.format(' style="width: %dpx;"', self.width) or ''

    return string.format(
        '<div class="field-row"><button id="field-%s" class="field-composite-button field-numeric-button"%s>%s</button><input type="text" id="field-%s-input" class="field-input field-numeric-input hidden"%s value="%s"/></div>',
        self.name, widthStyle, self:__GetButtonRml(), self.name, widthStyle, self:__GetDisplayText()
    )
end

function RmlUiNumericField:BindToDocument()
    local document = (self.ev and self.ev.document) or SB.view.mainDocument
    assert(document, "No document available for field: " .. self.name)
    self.element = document:GetElementById("field-" .. self.name)
    self.inputElement = document:GetElementById("field-" .. self.name .. "-input")
    assert(self.element and self.inputElement, "Failed to find numeric field elements: " .. self.name)
    self:SetValue(self.value)
end

function RmlUiNumericField:SetValue(value)
    self.value = value
    local display = self:__GetDisplayText()
    if self.element then
        self.element.inner_rml = self:__GetButtonRml()
        self.element:SetAttribute("value", display)
    end
    if self.inputElement then
        self.inputElement:SetAttribute("value", display)
    end
end

function RmlUiNumericField:__StartEditing()
    if not self.element or not self.inputElement then
        return
    end
    self.__editing = true
    self.__originalValue = self.value
    self.element:SetClass("hidden", true)
    self.inputElement:SetClass("hidden", false)
    self.inputElement:SetAttribute("value", self:__GetDisplayText())
    self.inputElement:Focus(true)
    if self.inputElement.Select then
        self.inputElement:Select()
    end
    if self.ev then
        self.ev:_OnStartChange(self.name)
    end
end

function RmlUiNumericField:__StopEditing(commit)
    if not self.__editing then
        return
    end
    if commit and self.inputElement then
        self:Set(self.inputElement.value or self.inputElement:GetAttribute("value"))
    elseif not commit then
        self:SetValue(self.__originalValue)
    end
    self.__editing = false
    self.element:SetClass("hidden", false)
    self.inputElement:SetClass("hidden", true)
    if self.ev then
        self.ev:_OnEndChange(self.name)
    end
end

function RmlUiNumericField:__StartDragging()
    if self.__isDragging then
        return
    end
    self.__isDragging = true
    self.element:SetClass("dragging", true)
    SB.SetMouseCursor("empty")
    if self.ev then
        self.ev:_OnStartChange(self.name)
    end
end

function RmlUiNumericField:__StopDragging()
    if not self.__isDragging then
        return
    end
    self.__isDragging = false
    self.__mouseDown = false
    if self.element then
        self.element:SetClass("dragging", false)
    end
    SB.SetMouseCursor()
    if self.ev then
        self.ev:_OnEndChange(self.name)
    end
    if self.__initX and self.__initY then
        Spring.WarpMouse(self.__initX, self.__initY)
    end
    self.__initX, self.__initY, self.__lastX = nil, nil, nil
end

function RmlUiNumericField:__UpdateDragging(delta)
    local _, _, _, shift = Spring.GetModKeyState()
    if shift then
        delta = delta * self.__shiftMultiplier
    end
    self:Set((tonumber(self.value) or 0) + delta * self.step, self.element)
end

function RmlUiNumericField:UpdateActiveDrag()
    if not self.__mouseDown then
        return
    end

    -- Button state comes from RmlUi's mousedown/mouseup (which capture the
    -- mouse); Spring.GetMouseState is only trusted for the cursor position.
    -- Its button flags read as released while RmlUi holds capture, which used
    -- to abort every drag on the first frame.
    local mx = Spring.GetMouseState()

    if not self.__isDragging then
        if math.abs(mx - self.__initX) <= self.__dragSensitivity then
            return
        end
        self:__StartDragging()
    end

    local dx = mx - self.__initX
    if dx ~= 0 then
        self:__UpdateDragging(dx)
        Spring.WarpMouse(self.__initX, self.__initY)
    end
end

function RmlUiNumericField:BindEvents()
    if not self.element then
        return
    end

    self.element:AddEventListener("mousedown", function(event)
        if event.parameters and event.parameters.button ~= 0 then
            return
        end
        self.__mouseDown = true
        self.__isDragging = false
        local mx, my = Spring.GetMouseState()
        self.__initX = mx
        self.__initY = my
        self.__lastX = mx
        activeNumericDragField = self
    end)

    self.element:AddEventListener("mousemove", function(event)
        self:UpdateActiveDrag()
    end)

    self.element:AddEventListener("mouseup", function(event)
        if self.__isDragging then
            self:__StopDragging()
        elseif self.__mouseDown then
            self.__mouseDown = false
            self:__StartEditing()
        end
        activeNumericDragField = nil
    end)

    if self.inputElement then
        self.inputElement:AddEventListener("change", function()
            self:__StopEditing(true)
        end)
        self.inputElement:AddEventListener("blur", function()
            self:__StopEditing(true)
        end)
        self.inputElement:AddEventListener("keydown", function(event)
            local key = event.parameters and event.parameters.key_identifier
            if key == "enter" or key == "numpad_enter" then
                self:__StopEditing(true)
            elseif key == "escape" then
                self:__StopEditing(false)
            end
        end)
    end
end

-- Boolean Field
RmlUiBooleanField = RmlUiField:extends{}

function RmlUiBooleanField:init(opts)
    self:super("init", opts)
end

function RmlUiBooleanField:GetValue()
    return self.element.checked
end

function RmlUiBooleanField:SetValue(value)
    self.value = value
    if self.element then
        if value then
            self.element:SetAttribute("checked", "checked")
        else
            self.element:RemoveAttribute("checked")
        end
    end
end

function RmlUiBooleanField:Serialize()
    return self.value
end

function RmlUiBooleanField:Load(data)
    self:Set(data)
end

function RmlUiBooleanField:GenerateRml()
    local checked = self.value and 'checked="checked"' or ''
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")
    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="checkbox" id="field-%s" class="field-checkbox" %s/></div>',
        title, self.name, checked
    )
end

-- Choice Field (Dropdown)
RmlUiChoiceField = RmlUiField:extends{}

function RmlUiChoiceField:init(opts)
    self:super("init", opts)
    self.items = opts.items or {}
    self.captions = opts.captions or self.items  -- Use items as captions if not provided
end

function RmlUiChoiceField:GenerateRml()
    local options = ""
    for i, item in ipairs(self.items) do
        local caption = self.captions[i] or tostring(item)
        local selected = (tostring(item) == tostring(self.value)) and ' selected="selected"' or ''
        options = options .. string.format('<option value="%s"%s>%s</option>', tostring(item), selected, caption)
    end
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")
    local wrapperStyle = self.width and string.format(' style="width: %dpx;"', self.width) or ''

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><div class="select-wrapper"%s><select id="field-%s" class="field-input">%s</select><div class="select-arrow">v</div></div></div>',
        title, wrapperStyle, self.name, options
    )
end

function RmlUiChoiceField:GetCaption(id)
    id = id or self.value
    -- Find index of id in items
    for i, item in ipairs(self.items) do
        if tostring(item) == tostring(id) then
            return self.captions[i]
        end
    end
    return nil
end

function RmlUiChoiceField:SetValue(value)
    self.value = value
    if self.element then
        self.element:SetAttribute("value", tostring(value or ""))
    end
end

function RmlUiChoiceField:Serialize()
    return self.value
end

function RmlUiChoiceField:Load(data)
    self:Set(data)
end

-- Color Field
RmlUiColorField = RmlUiField:extends{}

function RmlUiColorField:init(opts)
    self:super("init", opts)
end

function RmlUiColorField:__ToHex(value)
    local colorHex = "#FFFFFF"
    if value then
        if type(value) == "table" then
            local r = math.floor((value[1] or value.r or 1) * 255)
            local g = math.floor((value[2] or value.g or 1) * 255)
            local b = math.floor((value[3] or value.b or 1) * 255)
            colorHex = string.format("#%02X%02X%02X", r, g, b)
        else
            colorHex = tostring(value)
        end
    end
    return colorHex
end

function RmlUiColorField:__GetButtonRml()
    local title = self.title:gsub(":$", "")
    local colorHex = self:__ToHex(self.value)
    return string.format(
        '<span class="field-button-title">%s:</span><span class="field-swatch" style="background-color: %s;"></span>',
        title, colorHex
    )
end

function RmlUiColorField:GenerateRml()
    local widthStyle = self.width and string.format(' style="width: %dpx;"', self.width) or ''

    return string.format(
        '<div class="field-row"><button id="field-%s" class="field-composite-button field-color-button"%s>%s</button></div>',
        self.name, widthStyle, self:__GetButtonRml()
    )
end

function RmlUiColorField:SetValue(value)
    self.value = value
    if self.element then
        self.element.inner_rml = self:__GetButtonRml()
    end
end

function RmlUiColorField:BindEvents()
    local document = (self.ev and self.ev.document) or SB.view.mainDocument
    assert(document, "No document available for field: " .. self.name)
    self.element:AddEventListener("mousedown", function()
        self:ShowColorPicker()
    end)
end

function RmlUiColorField:ShowColorPicker()
    local picker = RmlUiColorPickerWindow({
        color = self.value,
        onConfirm = function(color)
            self:Set(color)
            return true
        end
    })
    picker:Show()
end

function RmlUiColorField:Serialize()
    return self.value
end

function RmlUiColorField:Load(data)
    self:Set(data)
end

-- Asset Field
RmlUiAssetField = RmlUiField:extends{}

function RmlUiAssetField:init(opts)
    self:super("init", opts)
    self.expand = opts.expand
    self.rootDir = opts.rootDir
    self.itemWidth = opts.itemWidth or 64
    self.itemHeight = opts.itemHeight or 64

    -- If opts.Update is provided, it overrides the Update method (like Chili)
    if opts.Update then
        self.Update = opts.Update
    end

    -- Create AssetView for expand mode (mimics Chili AssetPickerWindow behavior)
    if self.expand then
        -- Calculate initial dir from value or default path (matching Chili AssetPickerWindow)
        local dir = Path.ExtractDir(opts.path or
            SB.model.assetsManager:ToSpringPath(
                self.rootDir,
                SB.model.game.defaultAssetsFolder
            ))
        if self.rootDir then
            dir = SB.model.assetsManager:ToAssetPath(self.rootDir, dir)
        end

        self.assetView = AssetView({
            dir = dir,
            rootDir = self.rootDir,
            itemWidth = self.itemWidth,
            itemHeight = self.itemHeight,
            multiSelect = false,
            imageFolder = Path.Join(SB.DIRS.IMG, 'open-folder.png'),
            imageFolderUp = Path.Join(SB.DIRS.IMG, 'up-card.png'),
            OnSelectItem = {
                function(item, selected)
                    self:Set(item.path, self.assetView)
                end
            },
        })
    end
end

function RmlUiAssetField:SetValue(value)
    self.value = value
    -- Update button text if in compact mode
    if not self.expand and self.element then
        local valueStr = ""
        if value then
            valueStr = type(value) == "table" and (value.name or "") or tostring(value)
        end
        self.element.inner_rml = valueStr
    end
end

function RmlUiAssetField:Update(source)
    if not self.expand then
        return
    end
    assert(self.assetView, "AssetField in expand mode must have assetView")
    if source ~= self.assetView and self.value then
        self.assetView:SelectAsset(self.value)
    end
end

function RmlUiAssetField:BindToDocument()
    if self.expand then
        -- Expand mode doesn't have a field input element, only a grid
        -- No element to bind
        return
    end
    -- Compact mode: bind the input element
    self:super("BindToDocument")
end

function RmlUiAssetField:GenerateRml()
    if self.expand then
        assert(self.assetView, "AssetField in expand mode must have assetView")
        local html = ''
        if self.assetView.pathNav then
            html = self.assetView.pathNav:GenerateRml()
        end
        html = html .. string.format('<div id="%s" class="grid-container" style="height: 200dp;"></div>', self.assetView.gridId)
        return html
    else
        -- Compact mode: show single button
        local valueStr = ""
        if self.value then
            valueStr = type(self.value) == "table" and (self.value.name or "") or tostring(self.value)
        end
        -- Remove trailing colon from title if present
        local title = self.title:gsub(":$", "")

        return string.format(
            '<div class="field-row"><label class="field-label">%s:</label><button id="field-%s" class="field-button">%s</button></div>',
            title, self.name, valueStr
        )
    end
end

function RmlUiAssetField:BindEvents()
    local document = (self.ev and self.ev.document) or SB.view.mainDocument
    assert(document, "No document available for field: " .. self.name)

    if self.expand then
        assert(self.assetView, "AssetField in expand mode must have assetView")

        -- Bind path navigation up button
        assert(self.assetView.pathNav, "AssetView must have pathNav")
        local upBtn = document:GetElementById(self.assetView.pathNav.id .. "-up")
        assert(upBtn, "Failed to find path nav up button")
        upBtn:AddEventListener("click", function()
            for _, listener in ipairs(self.assetView.pathNav.OnUpClick) do
                listener()
            end
        end)

        -- Trigger grid population
        SB.delay(function()
            self.assetView:_UpdateRmlUiGrid()
        end)
    else
        self.element:AddEventListener("click", function()
            self:ShowAssetPicker()
        end)
    end
end

function RmlUiAssetField:ShowAssetPicker()
    local picker = RmlUiAssetPickerWindow({
        rootDir = self.rootDir,
        path = self.value,
        onConfirm = function(assetPath)
            self:Set(assetPath)
            return true
        end
    })
    picker:Show()
end

-- Material Field
RmlUiMaterialField = RmlUiField:extends{}

function RmlUiMaterialField:init(opts)
    self:super("init", opts)
    self.rootDir = opts.rootDir
end

function RmlUiMaterialField:GenerateRml()
    -- Convert value to string - material is a table with diffuse/normal/specular textures
    local valueStr = ""
    if self.value then
        if type(self.value) == "table" then
            -- Show the diffuse texture name or a summary of textures present
            if self.value.diffuse then
                valueStr = Path.ExtractFileName(self.value.diffuse)
            elseif self.value.name then
                valueStr = self.value.name
            else
                -- Count how many textures are present
                local count = 0
                for _, tex in pairs({'diffuse', 'normal', 'specular'}) do
                    if self.value[tex] then count = count + 1 end
                end
                valueStr = count > 0 and (count .. " textures") or ""
            end
        else
            valueStr = tostring(self.value)
        end
    end
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><button id="field-%s" class="field-button">%s</button></div>',
        title, self.name, valueStr
    )
end

function RmlUiMaterialField:SetValue(value)
    self.value = value
    -- Format the value for display
    local valueStr = ""
    if value then
        if type(value) == "table" then
            if value.diffuse then
                valueStr = Path.ExtractFileName(value.diffuse)
            elseif value.name then
                valueStr = value.name
            else
                local count = 0
                for _, tex in pairs({'diffuse', 'normal', 'specular'}) do
                    if value[tex] then count = count + 1 end
                end
                valueStr = count > 0 and (count .. " textures") or ""
            end
        else
            valueStr = tostring(value)
        end
    end
    -- Update element if bound
    if self.element then
        self.element.inner_rml = valueStr
    end
end

function RmlUiMaterialField:Serialize()
    return self.value
end

function RmlUiMaterialField:Load(data)
    self:Set(data)
end

function RmlUiMaterialField:BindEvents()
    local document = (self.ev and self.ev.document) or SB.view.mainDocument
    assert(document, "No document available for field: " .. self.name)
    self.element:AddEventListener("click", function()
        self:ShowMaterialPicker()
    end)
end

function RmlUiMaterialField:ShowMaterialPicker()
    -- Get path from current value (like Chili MaterialField)
    local path = nil
    if self.value and type(self.value) == "table" and self.value.diffuse then
        path = self.value.diffuse
    end

    local picker = RmlUiMaterialPickerWindow({
        rootDir = self.rootDir,
        path = path,
        onConfirm = function(material)
            self:Set(material)
            return true
        end
    })
    picker:Show()
end

-- Object Field (for object IDs)
RmlUiObjectField = RmlUiField:extends{}

function RmlUiObjectField:init(opts)
    self:super("init", opts)
end

function RmlUiObjectField:GenerateRml()
    -- Convert value to string (might be table in some cases)
    local valueStr = ""
    if self.value then
        valueStr = type(self.value) == "table" and (self.value.id or "") or tostring(self.value)
    end
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="number" id="field-%s" class="field-input" value="%s"/><button id="btn-pick-%s" class="field-button">Pick</button></div>',
        title, self.name, valueStr, self.name
    )
end

-- Object Type Field (unitDef names)
RmlUiObjectTypeField = RmlUiField:extends{}

function RmlUiObjectTypeField:init(opts)
    self:super("init", opts)
end

function RmlUiObjectTypeField:GenerateRml()
    -- Convert value to string (might be table in some cases)
    local valueStr = ""
    if self.value then
        valueStr = type(self.value) == "table" and (self.value.name or "") or tostring(self.value)
    end
    -- Remove trailing colon from title if present
    local title = self.title:gsub(":$", "")

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><input type="text" id="field-%s" class="field-input" value="%s"/><button id="btn-browse-%s" class="field-button">Browse</button></div>',
        title, self.name, valueStr, self.name
    )
end

-- Team Field
RmlUiTeamField = RmlUiField:extends{}

function RmlUiTeamField:init(opts)
    -- Set default value to 0 if not provided (matching ChoiceField behavior)
    if opts.value == nil then
        opts.value = 0
    end
    self:super("init", opts)
end

function RmlUiTeamField:GenerateRml()
    local options = ""
    for i = 0, 15 do
        local selected = (i == self.value) and ' selected="selected"' or ''
        options = options .. string.format('<option value="%d"%s>Team %d</option>', i, selected, i)
    end

    return string.format(
        '<div class="field-row"><label class="field-label">%s:</label><select id="field-%s" class="field-input">%s</select></div>',
        self.title, self.name, options
    )
end

-- Array Field
RmlUiArrayField = RmlUiField:extends{}

function RmlUiArrayField:init(opts)
    self:super("init", opts)
    self.value = opts.value or {}
    self.itemType = opts.itemType or "string"
end

function RmlUiArrayField:GenerateRml()
    local html = '<div class="array-field"><label class="field-label">' .. self.title .. ':</label>'

    for i, item in ipairs(self.value) do
        html = html .. string.format(
            '<div class="array-item"><input type="text" class="array-item-input field-input" value="%s"/><button class="array-item-remove field-button">-</button></div>',
            item
        )
    end

    html = html .. '<button class="array-add-button field-button">+ Add Item</button></div>'
    return html
end

-- Group Field (groups multiple fields together)
RmlUiGroupField = RmlUiField:extends{}

function RmlUiGroupField:init(opts)
    self:super("init", opts)
    self.fields = opts.fields or {}
end

function RmlUiGroupField:BindToDocument()
    -- GroupField doesn't create a field element itself, only its children do
    -- Bind all child fields
    for _, field in ipairs(self.fields) do
        if field.BindToDocument then
            field:BindToDocument()
        end
    end
end

function RmlUiGroupField:GenerateRml()
    -- Group fields display children inline without showing group name
    local html = '<div class="field-group">'

    -- Only show label if explicitly provided (not auto-generated "_groupField" names)
    if self.title and not self.title:match("^_groupField%d+$") then
        local title = self.title:gsub(":$", "")
        html = html .. '<label class="field-label">' .. title .. ':</label>'
    end

    for _, field in ipairs(self.fields) do
        -- Generate inline field HTML (without the field-row wrapper)
        if field.GenerateRml then
            -- For group children, generate compact inline version
            local fieldHtml = field:GenerateRml()
            -- Remove the field-row wrapper for inline display
            fieldHtml = fieldHtml:gsub('<div class="field%-row">', '<div class="field-inline">')
            html = html .. fieldHtml
        end
    end

    html = html .. '</div>'
    return html
end

-- Picker Windows
RmlUiAssetPickerWindow = RmlUiComponent:extends{}
function RmlUiAssetPickerWindow:init(opts)
    -- Calculate rootDir and dir exactly like Chili AssetPickerWindow does
    local rootDir = opts.rootDir
    local dir = Path.ExtractDir(opts.path or
        SB.model.assetsManager:ToSpringPath(
            rootDir,
            SB.model.game.defaultAssetsFolder
        ))
    if rootDir then
        dir = SB.model.assetsManager:ToAssetPath(rootDir, dir)
    end

    -- Call parent init to load document
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/fields/asset_picker.rml'), "Asset Picker")

    self.onConfirm = opts.onConfirm
    self.selectedAsset = nil
    self.rootDir = rootDir
    self.dir = dir

    -- Bind button events
    local btnOk = self.document:GetElementById("btn-ok")
    assert(btnOk, "Failed to find OK button")
    btnOk:AddEventListener("click", function()
        if self.selectedAsset and self.onConfirm then
            self.onConfirm(self.selectedAsset)
        end
        self:Close()
    end)

    local btnCancel = self.document:GetElementById("btn-cancel")
    assert(btnCancel, "Failed to find Cancel button")
    btnCancel:AddEventListener("click", function()
        self:Close()
    end)

    local btnClose = self.document:GetElementById("btn-close")
    assert(btnClose, "Failed to find Close button")
    btnClose:AddEventListener("click", function()
        self:Close()
    end)

    -- Create AssetView with document/gridId set
    self.assetView = AssetView({
        name = "assetBrowser",
        rootDir = self.rootDir,
        dir = self.dir,
        itemWidth = 64,
        itemHeight = 64,
        multiSelect = false,
        document = self.document,
        gridId = "asset-grid",
        documentDepth = 4,  -- asset_picker.rml is at scen_edit/view/rml/fields/ (4 levels deep)
        imageFolder = Path.Join(SB.DIRS.IMG, 'open-folder.png'),
        imageFolderUp = Path.Join(SB.DIRS.IMG, 'up-card.png'),
        OnSelectItem = {
            function(item, selected)
                if item then
                    self.selectedAsset = item.path
                end
            end
        },
    })

    -- Inject path navigation HTML above the grid
    assert(self.assetView.pathNav, "AssetView must have pathNav")
    local pathNavContainer = self.document:GetElementById("path-nav-container")
    assert(pathNavContainer, "Failed to find path-nav-container")
    pathNavContainer.inner_rml = self.assetView.pathNav:GenerateRml()

    -- Bind path navigation events after DOM updates
    SB.delay(function()
        local upBtn = self.document:GetElementById(self.assetView.pathNav.id .. "-up")
        upBtn:AddEventListener("click", function()
            for _, listener in ipairs(self.assetView.pathNav.OnUpClick) do
                listener()
            end
        end)

        -- Force grid update after document is ready
        self.assetView:_UpdateRmlUiGrid()
    end)
end

local function __ClampColorValue(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function __RgbToHsv(color)
    local r, g, b = color[1], color[2], color[3]
    local minC = math.min(r, g, b)
    local maxC = math.max(r, g, b)
    local delta = maxC - minC
    local h = 0
    local s = 0
    local v = maxC

    if maxC ~= 0 then
        s = delta / maxC
    end
    if delta ~= 0 then
        if r == maxC then
            h = (g - b) / delta
        elseif g == maxC then
            h = 2 + (b - r) / delta
        else
            h = 4 + (r - g) / delta
        end
        h = h * 60
        if h < 0 then
            h = h + 360
        end
        h = h / 360
    end

    return {h, s, v, color[4] or 1}
end

local function __HsvToRgb(color)
    local h, s, v = (color[1] or 0) * 360, color[2] or 0, color[3] or 1
    local chroma = v * s
    local h1 = h / 60
    local x = chroma * (1 - math.abs(h1 % 2 - 1))

    local r, g, b = 0, 0, 0
    if h1 >= 0 and h1 < 1 then
        r, g, b = chroma, x, 0
    elseif h1 < 2 then
        r, g, b = x, chroma, 0
    elseif h1 < 3 then
        r, g, b = 0, chroma, x
    elseif h1 < 4 then
        r, g, b = 0, x, chroma
    elseif h1 < 5 then
        r, g, b = x, 0, chroma
    elseif h1 < 6 then
        r, g, b = chroma, 0, x
    end

    local m = v - chroma
    return {r + m, g + m, b + m, color[4] or 1}
end

RmlUiColorPickerWindow = RmlUiComponent:extends{}
function RmlUiColorPickerWindow:init(opts)
    -- Call parent init to load document
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/fields/color_picker.rml'), "Color Picker")

    self.color = opts.color or {1, 1, 1, 1}
    self.onConfirm = opts.onConfirm

    -- Convert color to RGBA 0-255
    local r = math.floor((self.color[1] or self.color.r or 1) * 255)
    local g = math.floor((self.color[2] or self.color.g or 1) * 255)
    local b = math.floor((self.color[3] or self.color.b or 1) * 255)
    local a = math.floor((self.color[4] or self.color.a or 1) * 255)
    local hsv = __RgbToHsv({r / 255, g / 255, b / 255, a / 255})

    -- Get all elements
    local rValue = self.document:GetElementById("r-value")
    local gValue = self.document:GetElementById("g-value")
    local bValue = self.document:GetElementById("b-value")
    local aValue = self.document:GetElementById("a-value")
    local hexInput = self.document:GetElementById("hex-input")
    local colorPreview = self.document:GetElementById("color-preview")
    local colorMap = self.document:GetElementById("color-map")
    local hueMap = self.document:GetElementById("hue-map")
    local colorMapCursor = self.document:GetElementById("color-map-cursor")
    local hueCursor = self.document:GetElementById("hue-cursor")

    assert(rValue and gValue and bValue and aValue, "Failed to find color value inputs")
    assert(hexInput and colorPreview, "Failed to find hex input or color preview")
    assert(colorMap and hueMap, "Failed to find color picker image controls")

    -- Set initial values
    rValue:SetAttribute("value", tostring(r))
    gValue:SetAttribute("value", tostring(g))
    bValue:SetAttribute("value", tostring(b))
    aValue:SetAttribute("value", tostring(a))
    hexInput:SetAttribute("value", string.format("#%02X%02X%02X", r, g, b))

    local function setRgbFromHsv()
        local rgb = __HsvToRgb(hsv)
        rValue:SetAttribute("value", tostring(math.floor(rgb[1] * 255 + 0.5)))
        gValue:SetAttribute("value", tostring(math.floor(rgb[2] * 255 + 0.5)))
        bValue:SetAttribute("value", tostring(math.floor(rgb[3] * 255 + 0.5)))
        aValue:SetAttribute("value", tostring(math.floor((rgb[4] or 1) * 255 + 0.5)))
    end

    local function updatePreview(syncHsvFromRgb)
        local cr = __ClampColorValue(rValue:GetAttribute("value"), 0, 255)
        local cg = __ClampColorValue(gValue:GetAttribute("value"), 0, 255)
        local cb = __ClampColorValue(bValue:GetAttribute("value"), 0, 255)
        local ca = __ClampColorValue(aValue:GetAttribute("value"), 0, 255)
        if syncHsvFromRgb then
            hsv = __RgbToHsv({cr / 255, cg / 255, cb / 255, ca / 255})
        end
        local hexColor = string.format("#%02X%02X%02X", cr, cg, cb)
        colorPreview:SetAttribute("style", "background-color: " .. hexColor)
        hexInput:SetAttribute("value", hexColor)
        local hueRgb = __HsvToRgb({hsv[1], 1, 1, 1})
        colorMap:SetAttribute("style", "background-color: " .. string.format(
            "#%02X%02X%02X",
            math.floor(hueRgb[1] * 255 + 0.5),
            math.floor(hueRgb[2] * 255 + 0.5),
            math.floor(hueRgb[3] * 255 + 0.5)
        ))
        if colorMapCursor then
            colorMapCursor:SetAttribute("style", string.format("left: %dpx; top: %dpx;", math.floor(hsv[2] * 179), math.floor((1 - hsv[3]) * 179)))
        end
        if hueCursor then
            hueCursor:SetAttribute("style", string.format("top: %dpx;", math.floor(hsv[1] * 179)))
        end
    end
    updatePreview(false)

    local function getEventMouse(event)
        if event and event.parameters and event.parameters.mouse_x and event.parameters.mouse_y then
            return event.parameters.mouse_x, event.parameters.mouse_y
        end
        return Spring.GetMouseState()
    end

    local function updateFromColorMap(event)
        local mx, my = getEventMouse(event)
        local left, top = colorMap.absolute_left, colorMap.absolute_top
        local width = math.max(1, colorMap.offset_width or 180)
        local height = math.max(1, colorMap.offset_height or 180)
        hsv[2] = __ClampColorValue((mx - left) / width, 0, 1)
        hsv[3] = 1 - __ClampColorValue((my - top) / height, 0, 1)
        setRgbFromHsv()
        updatePreview(false)
    end

    local function updateFromHueMap(event)
        local mx, my = getEventMouse(event)
        local top = hueMap.absolute_top
        local height = math.max(1, hueMap.offset_height or 180)
        hsv[1] = __ClampColorValue((my - top) / height, 0, 1)
        setRgbFromHsv()
        updatePreview(false)
    end

    -- Bind input events
    rValue:AddEventListener("change", function() updatePreview(true) end)
    gValue:AddEventListener("change", function() updatePreview(true) end)
    bValue:AddEventListener("change", function() updatePreview(true) end)
    aValue:AddEventListener("change", function() updatePreview(true) end)

    -- Click-and-drag on the SV square / hue strip. The pressed state is tracked
    -- from RmlUi's own mousedown/mouseup: Spring.GetMouseState's button flags
    -- read as released while RmlUi holds the mouse capture, which is why
    -- dragging previously did nothing. Movement is handled at document level so
    -- the drag keeps tracking (clamped) once the cursor leaves the control.
    local draggingColorMap, draggingHueMap = false, false

    colorMap:AddEventListener("mousedown", function(event)
        draggingColorMap = true
        updateFromColorMap(event)
    end)
    hueMap:AddEventListener("mousedown", function(event)
        draggingHueMap = true
        updateFromHueMap(event)
    end)

    self.document:AddEventListener("mousemove", function(event)
        if draggingColorMap then
            updateFromColorMap(event)
        elseif draggingHueMap then
            updateFromHueMap(event)
        end
    end)
    self.document:AddEventListener("mouseup", function()
        draggingColorMap = false
        draggingHueMap = false
    end)

    -- Bind button events
    local btnOk = self.document:GetElementById("btn-ok")
    assert(btnOk, "Failed to find OK button")
    btnOk:AddEventListener("click", function()
        local finalR = (tonumber(rValue:GetAttribute("value")) or 255) / 255
        local finalG = (tonumber(gValue:GetAttribute("value")) or 255) / 255
        local finalB = (tonumber(bValue:GetAttribute("value")) or 255) / 255
        local finalA = (tonumber(aValue:GetAttribute("value")) or 255) / 255
        if self.onConfirm then
            self.onConfirm({finalR, finalG, finalB, finalA})
        end
        self:Close()
    end)

    local btnCancel = self.document:GetElementById("btn-cancel")
    assert(btnCancel, "Failed to find Cancel button")
    btnCancel:AddEventListener("click", function()
        self:Close()
    end)

    local btnClose = self.document:GetElementById("btn-close")
    assert(btnClose, "Failed to find Close button")
    btnClose:AddEventListener("click", function()
        self:Close()
    end)
end

RmlUiMaterialPickerWindow = RmlUiComponent:extends{}
function RmlUiMaterialPickerWindow:init(opts)
    -- Calculate rootDir and dir exactly like Chili AssetPickerWindow does
    local rootDir = opts.rootDir
    local springPath = SB.model.assetsManager:ToSpringPath(rootDir, SB.model.game.defaultAssetsFolder)

    local dir
    if opts.path then
        -- If we have a specific file path, extract its directory
        dir = Path.ExtractDir(opts.path)
    else
        -- If no path, use the spring path directly (don't extract its parent!)
        dir = springPath
    end

    if rootDir then
        dir = SB.model.assetsManager:ToAssetPath(rootDir, dir)
    end

    -- Call parent init to load document
    self:super("init", Path.Join(SB.DIRS.SRC, 'view/rml/fields/material_picker.rml'), "Material Picker")

    self.onConfirm = opts.onConfirm
    self.selectedMaterial = nil
    self.rootDir = rootDir
    self.dir = dir

    -- Bind button events
    local btnOk = self.document:GetElementById("btn-ok")
    assert(btnOk, "Failed to find OK button")
    btnOk:AddEventListener("click", function()
        if self.selectedMaterial and self.onConfirm then
            self.onConfirm(self.selectedMaterial)
        end
        self:Close()
    end)

    local btnCancel = self.document:GetElementById("btn-cancel")
    assert(btnCancel, "Failed to find Cancel button")
    btnCancel:AddEventListener("click", function()
        self:Close()
    end)

    local btnClose = self.document:GetElementById("btn-close")
    assert(btnClose, "Failed to find Close button")
    btnClose:AddEventListener("click", function()
        self:Close()
    end)

    -- Create MaterialBrowser with document/gridId set
    self.materialBrowser = MaterialBrowser({
        name = "materialBrowser",
        rootDir = self.rootDir,
        dir = self.dir,
        itemWidth = 64,
        itemHeight = 64,
        multiSelect = false,
        document = self.document,
        gridId = "material-grid",
        documentDepth = 4,  -- material_picker.rml is at scen_edit/view/rml/fields/ (4 levels deep)
        imageFolderUp = Path.Join(SB.DIRS.IMG, 'up-card.png'),
        OnSelectItem = {
            function(item, selected)
                if item and item.texture then
                    self.selectedMaterial = item.texture
                end
            end
        },
    })

    -- Inject path navigation HTML above the grid
    assert(self.materialBrowser.pathNav, "MaterialBrowser must have pathNav")
    local pathNavContainer = self.document:GetElementById("path-nav-container")
    assert(pathNavContainer, "Failed to find path-nav-container")
    pathNavContainer.inner_rml = self.materialBrowser.pathNav:GenerateRml()

    -- Bind path navigation events after DOM updates
    SB.delay(function()
        local upBtn = self.document:GetElementById(self.materialBrowser.pathNav.id .. "-up")
        upBtn:AddEventListener("click", function()
            for _, listener in ipairs(self.materialBrowser.pathNav.OnUpClick) do
                listener()
            end
        end)

        -- Force grid update after document is ready
        self.materialBrowser:_UpdateRmlUiGrid()
    end)
end
