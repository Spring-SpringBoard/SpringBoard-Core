--- Editor module

--- Editor class. Inherit to create custom Editors
-- @type Editor
Editor = LCS.class{}

--- Editor constructor. Make sure you invoke this in your custom editor
-- @see Editor.Finalize
-- @usage
-- MyEditor = Editor:extends{}
-- function MyEditor:init()
--     Editor.init(self)
--     -- rest of code
--     self:Finalize(children, opts)
-- end
function Editor:init()
    self.__initializing = true

    self.__isLoading = false

    self.fields = {}
    self.fieldOrder = {}

    -- Only create stackPanel in Chili mode (not RmlUi)
    if not SB.view or not SB.view.useRmlUi then
        self.stackPanel = StackPanel:New {
            y = 0,
            x = 0,
            right = 0,

            centerItems = false,

            autosize = true,
            resizeItems = false,
            preserveChildrenOrder = true,

            itemPadding = {0,10,0,0},
            padding = {0,0,0,0},
            margin = {0,0,0,0},
            itemMargin = {5,0,0,0},
        }
        self.stackPanel:DisableRealign()
    end
end

-------------------------------
-- OVERRIDE METHODS START
-------------------------------

--- Called when a field starts to change.
--- Override.
-- @tparam string name Name of the field.
function Editor:OnStartChange(name)
end
-- Called when a field stops to change.
--- Override.
-- @tparam string name Name of the field.
function Editor:OnEndChange(name)
end
--- Called when a field value was modified
--- Override.
-- @tparam string name Name of the modified field.
-- @param value New value of the modified field.
function Editor:OnFieldChange(name, value)
end
--- Should return true if state is valid for this editor.
--- Override.
-- @param name state State.
function Editor:IsValidState(state)
    return false
end
--- Called when the state was entered.
--- Override.
-- @param name state State.
function Editor:OnEnterState(state)
end
--- Called when the state was left.
--- Override.
-- @param name state State.
function Editor:OnLeaveState(state)
end

-------------------------------
-- OVERRIDE METHODS END
-------------------------------

function Editor:_OnEnterState(state)
    if self:IsValidState(state) then
        self:OnEnterState(state)
    end
end
function Editor:_OnLeaveState(state)
    if self:IsValidState(state) then
        self:OnLeaveState(state)
    end
end

--- Called at the end of :init(), to finalize the UI
--- Override.
-- @tparam table layout Layout options (UI-agnostic) or old-style children array
-- @tparam table opts Editor options
-- @tparam[opt=false] boolean opts.notMainWindow If true,
--   editor will not be added to the main panel (right side), but will instead be a floating window.
-- @tparam[opt=550] boolean opts.width Specifies window width. Only applicable for floating windows.
-- @tparam[opt=550] boolean opts.height Specifies window height. Only applicable for floating windows.
-- @tparam table opts.buttons Specifies what common buttons should be added to the bottom of the editor.
--  Values include "ok", "cancel" and "close"
-- @tparam boolean opts.disposeOnClose If true, the window will
--   be disposed when closed. Defaults to true if opts.notMainWindow is true, otherwise it defaults to false.
function Editor:Finalize(layout, opts)
    if not self.__initializing then
        Log.Error("\"Editor.init(self)\" wasn't invoked properly.")
        Log.Error(debug.traceback())
        assert(self.__initializing, "\"Editor.init(self)\" wasn't invoked properly.")
    end

    -- Support old API: if layout is an array, treat it as old-style children array
    local isOldAPI = layout and #layout > 0
    if isOldAPI then
        -- Old API compatibility: Finalize(children, opts)
        local children = layout
        opts = opts or {}

        if SB.view and SB.view.useRmlUi then
            self:_FinalizeRmlUi(children, opts)
            self.__initializing = false
            return
        end

        -- Continue with old Chili mode path
        self:_FinalizeButtons(children, opts)
        self:_FinalizeChiliWindow(children, opts)
        self.__initializing = false
        return
    end

    -- New API: Finalize({actionButtons = {...}}, opts)
    layout = layout or {}
    opts = opts or {}

    -- In RmlUi mode, generate RML from fields and buttons
    if SB.view and SB.view.useRmlUi then
        self:_FinalizeRmlUiNew(layout, opts)
        self.__initializing = false
        return
    end

    -- New Chili mode path
    self:_FinalizeChiliNew(layout, opts)
    self.__initializing = false
end

-- Old Chili mode path (extracted for old API compatibility)
function Editor:_FinalizeChiliWindow(children, opts)
    self:_FinalizeButtons(children, opts)

    local OnShow = {function() self:__OnShow() end}
    local OnHide = {function() self:__OnHide() end}
    self.__disposeOnClose = opts.disposeOnClose
    if not opts.notMainWindow then
        if opts.disposeOnClose == nil then
            self.__disposeOnClose = false
        end
        self.window = Control:New {
--         parent = screen0,
--         x = 10,
--         y = 100,
--         width = 550,
--         height = 800,
            x = 0,
            y = 0,
            bottom = 0,
            right = 0,
            caption = '',
            children = children,
            padding = {0,0,0,0},
            OnParentPost = OnShow,
            OnOrphan = OnHide,
            classname = opts.classname,
        }
        -- Only set main panel in Chili mode
        if SB.view and not SB.view.useRmlUi and SB.view.tabbedWindow then
            SB.view.tabbedWindow:SetMainPanel(self.window)
        end
    else
        if opts.disposeOnClose == nil then
            self.__disposeOnClose = true
        end
        -- TODO: Make configurable
        self.window = Window:New {
            parent = screen0,
            x = opts.x or "25%",
            y = opts.y or "20%",
            width = opts.width or 550,
            height = opts.height or 500,
            resizable  = false,
            caption = '',
            children = children,
            OnParentPost = OnShow,
            OnOrphan = OnHide,
            classname = opts.classname,
        }
        self.keyListener = function(key)
            local currentState = SB.stateManager:GetCurrentState()
            if not currentState:is_A(DefaultState) then
                return
            end
            if key == Spring.GetKeyCode("esc") then
                self:__MaybeClose()
                return true
            elseif key == Spring.GetKeyCode("enter") or
                   key == Spring.GetKeyCode("numpad_enter") then
                if self.ConfirmDialog then
                    if self:ConfirmDialog() then
                        self:__MaybeClose()
                    end
                    return true
                else
                    self:__MaybeClose()
                    return true
                end
            end
        end
        self:__AddKeyListener()

    end
    if self.stackPanel then
        self.stackPanel:EnableRealign()
        self.stackPanel:Invalidate()
    end

    self.__initializing = false
end

function Editor:_FinalizeButtons(children, opts)
    if opts.buttons == nil then
        assert(not opts.notMainWindow, "Dialogs should probably have some buttons so they can be closed")
        return
    end

    local btnCount = #opts.buttons
    -- atm we only support 'ok/cancel' or 'close'.
    -- anything else is probably a mistake so we guard against it
    assert(btnCount <= 2, "More than two buttons. This is probably a bug")
    local btnTable = {
        bottom = 0,
        width = '40%',
        height = SB.conf.B_HEIGHT,
    }
    local x = 0
    for _, btnName in ipairs(opts.buttons) do
        assert(type(btnName) == "string", "Editor buttons are specified as string")

        if btnName == "ok" then
            local btn = Table.DeepCopy(btnTable)
            Table.Merge(btn, {
                caption = "OK",
                classname = "option_button",
                x = tostring(x) .. '%',
                OnClick = {
                    function()
                        if self:ConfirmDialog() then
                            self:__MaybeClose()
                        end
                    end
                }
            })
            table.insert(children, Button:New(btn))
        elseif btnName == "cancel" then
            local btn = Table.DeepCopy(btnTable)
            Table.Merge(btn, {
                caption = "Cancel",
                classname = "negative_button",
                x = tostring(x) .. '%',
                OnClick = {
                    function()
                        self:__MaybeClose()
                    end
                }
            })
            table.insert(children, Button:New(btn))
        elseif btnName == "close" then
            local btn = Table.DeepCopy(btnTable)
            Table.Merge(btn, {
                caption = 'Close',
                right = '10%', -- close seems better on the right
                OnClick = {
                    function()
                        self:__MaybeClose()
                        -- FIXME: should be resetting to the default state?
                        -- SB.stateManager:SetState(DefaultState())
                    end
                },
            })
            table.insert(children, Button:New(btn))
        else
            error("Unexpected button name: " .. tostring(btnName))
        end
        x = x + 50
    end
end

-- Don't use this directly because ordering would be messed up.
function Editor:_SetFieldVisible(name, visible)
    local field = self.fields[name]
    if not field then
        Log.Error("Trying to set visibility on an invalid field: " .. tostring(name))
        return
    end

    if visible == nil then
        Log.Error("Visible is nil for field: " .. tostring(name))
        return
    end

    -- Skip in RmlUi mode - fields don't have Chili controls
    local ctrl = field.ctrl
    if not ctrl then
        return
    end

    --if ctrl.visible ~= visible then
    if ctrl._visible ~= visible then
        if visible then
            -- self.stackPanel:AddChild(ctrl)
            ctrl:Show()
            ctrl._visible = true
        else
            -- if self.stackPanel then self.stackPanel:RemoveChild(ctrl)
            ctrl:Hide()
            ctrl._visible = false
        end
    end
end

--- Sets fields which are to be made invisible.
-- @tparam {string, ...} ... Field names to be set invisible
function Editor:SetInvisibleFields(...)
    -- In RmlUi mode, set CSS display classes instead of manipulating Chili controls
    if SB.view and SB.view.useRmlUi then
        local fieldsToHide = {...}
        -- Hide all fields first
        for _, fieldName in ipairs(self.fieldOrder) do
            if SB.view.mainDocument then
                local fieldElement = SB.view.mainDocument:GetElementById("field-" .. fieldName)
                if fieldElement and fieldElement.parent_node then
                    -- Hide the parent row
                    fieldElement.parent_node:SetClass("hidden", true)
                end
            end
        end
        -- Show fields not in the hide list
        for _, fieldName in ipairs(self.fieldOrder) do
            if not table.ifind(fieldsToHide, fieldName) then
                if SB.view.mainDocument then
                    local fieldElement = SB.view.mainDocument:GetElementById("field-" .. fieldName)
                    if fieldElement and fieldElement.parent_node then
                        fieldElement.parent_node:SetClass("hidden", false)
                    end
                end
            end
        end
        return
    end

    if self.stackPanel then self.stackPanel:DisableRealign() end

    local fields = {...}
    for i = #self.fieldOrder, 1, -1 do
        local name = self.fieldOrder[i]
        self:_SetFieldVisible(name, false)
    end

    for i = 1, #self.fieldOrder do
        local name = self.fieldOrder[i]
        if not table.ifind(fields, name) then
            self:_SetFieldVisible(name, true)
        end
    end

    -- HACK: because we're Add/Removing items to the stackPanel instead of using Show/Hide on
    -- the control itself, we need to to execute a :_HackSetInvisibleFields later
    for _, field in pairs(self.fields) do
        if field._HackSetInvisibleFields then
            field:_HackSetInvisibleFields(fields)
        end
    end

    if self.stackPanel then self.stackPanel:EnableRealign() end
    if self.stackPanel then self.stackPanel:Invalidate() end
end

--- Remove field by name.
-- @tparam string name Name of field which should be removed.
function Editor:RemoveField(name)
    local field = self.fields[name]
    assert(field, "Trying to remove field that doesn't exist.")
    for i, orderName in pairs(self.fieldOrder) do
        if orderName == name then
            table.remove(self.fieldOrder, i)
            break
        end
    end
    if self.stackPanel then
        self.stackPanel:RemoveChild(field.ctrl)
    end
    self.fields[name] = nil
end
--- Add field.
-- @tparam field.Field field Field to be added.
-- @usage
-- self:AddField(NumericField({
--     name = "size",
--     value = 100,
--     minValue = 40,
--     maxValue = 2000,
--     title = "Size:",
--     tooltip = "Size of the paint brush",
-- }))
function Editor:AddField(field)
    if field.components then
        field.ctrl = self:_AddControl(field.name, field.components)
    end
    self:_AddField(field)

    -- Register child fields of GroupField
    -- RmlUi GroupFields have .fields but no .Added method (handled here)
    -- Chili GroupFields have .fields and .Added method (handled in Added())
    if field.fields and not field.Added then
        for _, childField in ipairs(field.fields) do
            if childField.name then
                self:_AddField(childField)
                -- Mark child field as part of a group so it won't be rendered separately
                childField._isGroupChild = true
            end
        end
    end

    -- Only call Added() if the method exists (Chili fields)
    if field.Added then
        field:Added()
    end
end

function Editor:_AddField(field)
    if not field or not field.name then
        Log.Error("Attempted to add field without name")
        return
    end
    self.fields[field.name] = field
    field.ev = self

    -- Add to fieldOrder if not already added (via _AddControl)
    -- This is needed for RmlUi fields which don't have components
    local alreadyInOrder = false
    for _, name in ipairs(self.fieldOrder) do
        if name == field.name then
            alreadyInOrder = true
            break
        end
    end
    if not alreadyInOrder then
        table.insert(self.fieldOrder, field.name)
    end
end

function Editor:AddControl(name, children)
    self.fields[name] = {
        ctrl = self:_AddControl(name, children),
        name = name,
    }
    return self.fields[name]
end

function Editor:_AddControl(name, children)
    -- In RmlUi mode, don't create Chili controls
    if SB.view and SB.view.useRmlUi then
        -- Just store the children for later use in _FinalizeRmlUi
        table.insert(self.fieldOrder, name)
        -- Return a dummy object that holds the children
        return { children = children, isRmlUiPlaceholder = true }
    end

    -- Chili mode - create actual Control
    local ctrl = Control:New {
        autosize = true,
        padding = {0, 0, 0, 0},
        children = children
    }
    if self.stackPanel then
        self.stackPanel:AddChild(ctrl)
    end
    table.insert(self.fieldOrder, name)
    return ctrl
end

function Editor:RenameField(oldName, newName)
    if newName == oldName then
        return
    end
    assert(not self.fields[newName], "Field with same name already exists")

    local field = self.fields[oldName]
    self.fields[newName] = field
    self.fields[oldName]  = nil
    field.name = newName
    for i, fname in pairs(self.fieldOrder) do
        if fname == oldName then
            self.fieldOrder[i] = newName
            break
        end
    end
end

function Editor:Validate(name, value)
    local field = self.fields[name]
    return field:Validate(value)
end

--- Set value of a field.
-- @tparam string name Field name.
-- @param value New value.
-- @usage
-- self:Set("myNumber", 15)
function Editor:Set(name, value)
    local field = self.fields[name]
    if not field then
        Log.Warning("Attempted to set non-existent field: " .. tostring(name))
        return
    end
    -- Only call Set if the method exists (Chili fields)
    if field.Set then
        field:Set(value)
    else
        -- For RmlUi fields, just set the value directly
        field.value = value
    end
end
function Editor:Update(name, _source)
    local field = self.fields[name]
    assert(field, "No such field to update: " .. tostring(name))

    -- Only call Update if the method exists (Chili fields)
    if field.Update then
        field:Update(_source)
    end

    -- update listeners and current state
    if not self.__initializing then
        self:OnFieldChange(field.name, field.value)
    end
    local currentState = SB.stateManager:GetCurrentState()
    if self:IsValidState(currentState) then
        currentState[field.name] = field.value
    end
end

function Editor:_OnStartChange(name)
    if not self._startedChanging then
        self._startedChanging = true
        self:OnStartChange(name)
    end
end

function Editor:_OnEndChange(name)
    if self._startedChanging then
        self._startedChanging = false
        self:OnEndChange(name)
    end
end

-- START Utility
--- Set default keybinding (binding button actions to 1-9).
-- @param buttons List of Chili Buttons.
function Editor:AddDefaultKeybinding(buttons)
    local KEY_ZERO = KEYSYMS.N_0
    self.__keybinding = {}
    for i, button in ipairs(buttons) do
        self:AddKeybinding(KEY_ZERO + i, button.OnClick)
        button.tooltip = button.tooltip .. " (" .. tostring(i) .. ")"
    end
end

function Editor:AddKeybinding(key, functions)
    self.__keybinding[key] = functions
end

function Editor:GetAllControls()
    local ctrls = {}
    for _, field in pairs(self.fields) do
        for _, ctrl in pairs(field.components or {}) do
            table.insert(ctrls, ctrl)
        end
    end
    return ctrls
end
-- END Utility

function Editor:KeyPress(key, mods, isRepeat, label, unicode)
    if not self.__keybinding then
        return
    end
    local listeners = self.__keybinding[key]
    if not listeners then
        return
    end
    CallListeners(listeners)
    return true
end

function Editor:__AddKeyListener()
    if not self.__addedKeyListener then
        self.__addedKeyListener = true
        SB.stateManager:AddGlobalKeyListener(self.keyListener)
    end
end

function Editor:__RemoveKeyListener()
    if self.__addedKeyListener then
        self.__addedKeyListener = false
        SB.stateManager:RemoveGlobalKeyListener(self.keyListener)
    end
end

function Editor:__OnShow()
    if self.keyListener then
        self:__AddKeyListener()
    end
end

function Editor:__OnHide()
    if self.keyListener then
        self:__RemoveKeyListener()
    end

    local currentState = SB.stateManager:GetCurrentState()
    if self:IsValidState(currentState) then
        SB.stateManager:SetState(DefaultState())
    end
    if SB.currentEditor == self then
        SB.currentEditor = nil
    end
end

function Editor:__MaybeClose()
    self.window:Hide()
    if self.__disposeOnClose then
        self.window:Dispose()
    end
end

--- Serialize editor fields into a table.
-- @return Serialized table of all fields.
function Editor:Serialize()
    local retVal = {}
    for name, field in pairs(self.fields) do
        if field.Serialize then
            retVal[name] = field:Serialize()
        end
    end
    return retVal
end

--- Load table into fields.
-- @tparam table tbl Serialized table to load.
function Editor:Load(tbl)
    self.__isLoading = true
    -- set missing fields to nil
    for name, field in pairs(self.fields) do
        -- some fields (like separator) don't have .Set
        if self.fields[name].Set and tbl[name] == nil then
            self.fields[name]:Set(nil)
        end
    end
    for name, data in pairs(tbl) do
        if self.fields[name] ~= nil then
            self.fields[name]:Load(data)
        end
    end
    self.__isLoading = false
end

-- Registered editor classes
SB.editorRegistry = {}
-- Globally available editor instances
SB.editors = {}

--- Register editor.
-- @tparam table opts Table
-- @tparam string opts.name Machine name of the editor control.
-- @tparam Editor opts.editor Class inheritng from Editor
-- @tparam string opts.tab Tab in which to place the editor button.
-- @tparam string opts.caption Title of the Editor control.
-- @tparam string opts.tooltip Mouseover tooltip.
-- @tparam string opts.image Path to the Editor icon.
-- @usage
-- MyEditor = Editor:extends{}
-- MyEditor:Register({
--     name = "myEditor",
--     tab = "MyTag",
--     caption = "MyEditor",
--     tooltip = "Edit something",
--     image = Path.Join(SB.DIRS.IMG, 'my_icon.png'),
--     order = 42,
-- })
function Editor:Register(opts)
    -- Prevents invalid invocation with missing opts table
    assert(opts ~= nil, "Missing opts table for editor. Did you mean" ..
                        "MyEditor:Register instead of MyEditor.Register?")
    assert(opts.name, "Missing name for editor.")
    assert(not SB.editorRegistry[opts.name],
        "Editor with name: " .. opts.name .. " already exists")

    Log.Notice("Registering: " .. opts.name)

    opts.editor = self

    opts.tab = opts.tab or "Other"
    opts.caption = opts.caption or opts.name
    opts.tooltip = opts.tooltip or opts.caption
    opts.image = opts.image or ""
    opts.order = opts.order or math.huge
    opts.no_serialize = opts.no_serialize

    for k, v in pairs(opts) do
        self[k] = v
    end

    SB.editorRegistry[opts.name] = opts

    if SB.view ~= nil and SB.view.tabbedWindow ~= nil then
        SB.view.tabbedWindow:AddEditor(self)
    end
end

--- Deregister the editor.
-- @usage
-- MyEditor:Deregister()
-- -- alternatively
-- Editor.Deregister("my-editor")
function Editor:Deregister()
    local editor
    if type(self) == "string" then
        editor = SB.editorRegistry[self]
        SB.editorRegistry[self] = nil
    else
        editor = SB.editorRegistry[self.name]
        SB.editorRegistry[self.name] = nil
    end

    if editor ~= nil then
        SB.view.tabbedWindow:RemoveEditor(editor)
        SB.editors[editor.name] = nil
    end
end

-- TODO: Add a scream that deregisters the Editor once it goes out of scope?
-- We need to make sure unloaded extensions don't leave anything

-- We load these fields last as they might be/contain subclasses of editor view
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/fields'))

-- Helper function to convert Chili button to RmlUi button
local function ConvertChiliButtonToRmlUi(chiliButton)
    if not chiliButton or type(chiliButton) ~= "table" then
        return nil
    end

    -- Check if it's a TabbedPanelButton (has SetPressedState and children with images/labels)
    if chiliButton.SetPressedState and chiliButton.children then
        -- Extract caption and image from children
        local caption = ""
        local image = nil
        for _, child in pairs(chiliButton.children) do
            if type(child) == "table" then
                if child.classname == "label" and child.caption then
                    caption = child.caption
                elseif child.classname == "image" and child.file then
                    image = child.file
                end
            end
        end

        -- Create RmlUi TabbedPanelButton
        return RmlUiTabbedPanelButton({
            x = chiliButton.x,
            y = chiliButton.y,
            tooltip = chiliButton.tooltip or "",
            OnClick = chiliButton.OnClick or {},
            caption = caption,
            image = image,
        })

    -- Check if it's a regular Button (has caption and OnClick)
    elseif chiliButton.caption and chiliButton.OnClick then
        return RmlUiButton({
            caption = chiliButton.caption,
            OnClick = chiliButton.OnClick or {},
            width = chiliButton.width,
            height = chiliButton.height,
            tooltip = chiliButton.tooltip,
        })
    end

    return nil
end

-- RmlUi-specific finalization
function Editor:_FinalizeRmlUi(children, opts)
    children = children or {}
    opts = opts or {}

    -- Convert Chili buttons to RmlUi buttons, and collect RmlUi filter controls
    self.actionButtons = {}
    self.regularButtons = {}
    self.filterControls = self.filterControls or {}  -- May already be set by editor

    for _, child in ipairs(children) do
        if child and type(child) == "table" then
            -- Check if this is already an RmlUi control (has GenerateRml method)
            if child.GenerateRml and type(child.GenerateRml) == "function" then
                -- It's an RmlUi control (filter control, etc.)
                if child.id and (child.id:match("^filter%-") or child.id:match("^action%-btn%-")) then
                    if not Table.Contains(self.filterControls, child) then
                        table.insert(self.filterControls, child)
                    end
                    if child.id:match("^action%-btn%-") then
                        table.insert(self.actionButtons, child)
                    end
                end
            else
                -- Try to convert Chili control to RmlUi
                local rmlButton = ConvertChiliButtonToRmlUi(child)
                if rmlButton then
                    -- TabbedPanelButtons become action buttons
                    if rmlButton.id and rmlButton.id:match("^action%-btn%-") then
                        table.insert(self.actionButtons, rmlButton)
                    -- Regular buttons
                    elseif rmlButton.id and rmlButton.id:match("^btn%-") then
                        table.insert(self.regularButtons, rmlButton)
                    end
                end
            end
        end
    end

    -- Generate RML for action buttons (placed at top)
    local buttonsHtml = ''
    if #self.actionButtons > 0 then
        buttonsHtml = '<div class="action-buttons-panel">'
        for _, button in ipairs(self.actionButtons) do
            buttonsHtml = buttonsHtml .. button:GenerateRml()
        end
        buttonsHtml = buttonsHtml .. '</div>'
    end

    -- Generate RML for filter controls
    local filtersHtml = ''
    if #self.filterControls > 0 then
        filtersHtml = '<div class="filter-panel">'
        for _, filter in ipairs(self.filterControls) do
            if filter.GenerateRml and not filter.id:match("^action%-btn%-") then
                filtersHtml = filtersHtml .. filter:GenerateRml()
            end
        end
        filtersHtml = filtersHtml .. '</div>'
    end

    -- Generate RML for all fields
    local fieldsHtml = ''
    for _, fieldName in ipairs(self.fieldOrder) do
        local field = self.fields[fieldName]
        -- Skip fields that are children of GroupFields (they're rendered by the group)
        if field and not field._isGroupChild then
            if field.GenerateRml then
                fieldsHtml = fieldsHtml .. field:GenerateRml()
            else
                -- Check if it's a control with a button inside
                if field.ctrl then
                    -- Check if this is an RmlUi placeholder (from new EditorButton API)
                    if field.ctrl.isRmlUiPlaceholder and field.ctrl.children then
                        -- Children are already RmlUi buttons, use them directly
                        for _, rmlBtn in ipairs(field.ctrl.children) do
                            if rmlBtn and rmlBtn.GenerateRml then
                                fieldsHtml = fieldsHtml .. rmlBtn:GenerateRml()
                                table.insert(self.regularButtons, rmlBtn)
                            end
                        end
                    else
                        -- Old path: try to convert Chili buttons to RmlUi buttons
                        local ctrlHtml = ''
                        if field.ctrl.children then
                            for _, btnChild in pairs(field.ctrl.children) do
                                local rmlBtn = ConvertChiliButtonToRmlUi(btnChild)
                                if rmlBtn then
                                    ctrlHtml = ctrlHtml .. rmlBtn:GenerateRml()
                                    table.insert(self.regularButtons, rmlBtn)
                                end
                            end
                        end
                        if ctrlHtml ~= '' then
                            fieldsHtml = fieldsHtml .. ctrlHtml
                        else
                            -- Fallback for other controls
                            fieldsHtml = fieldsHtml .. '<div class="field-separator"></div>'
                        end
                    end
                else
                    -- Fallback for fields without ctrl
                    fieldsHtml = fieldsHtml .. '<div class="field-separator"></div>'
                end
            end
        end
    end

    -- Generate path navigation if gridView has it (AssetView)
    local pathNavHtml = ''
    if self.gridView and self.gridView.pathNav then
        pathNavHtml = self.gridView.pathNav:GenerateRml()
    end

    -- Generate grid container if editor has a gridView
    local gridHtml = ''
    if self.gridView then
        gridHtml = string.format('<div id="%s" class="grid-container"></div>', self.gridView.gridId)
    end

    -- Combine buttons, filters, path nav, grid, and fields
    self.generatedRml = buttonsHtml .. filtersHtml .. pathNavHtml .. gridHtml .. fieldsHtml

    -- Mark as hidden by default
    self.hidden = true
end

-- New RmlUi finalization (new API with layout options)
function Editor:_FinalizeRmlUiNew(layout, opts)
    self.actionButtons = layout.actionButtons or {}
    self.regularButtons = {}
    self.filterControls = self.filterControls or {}  -- May already be set by editor

    -- Generate RML for action buttons (placed at top)
    local buttonsHtml = ''
    if #self.actionButtons > 0 then
        buttonsHtml = '<div class="action-buttons-panel">'
        for _, button in ipairs(self.actionButtons) do
            buttonsHtml = buttonsHtml .. button:GenerateRml()
        end
        buttonsHtml = buttonsHtml .. '</div>'
    end

    -- Generate RML for filter controls
    local filtersHtml = ''
    if #self.filterControls > 0 then
        filtersHtml = '<div class="filter-panel">'
        for _, filter in ipairs(self.filterControls) do
            if filter.GenerateRml then
                filtersHtml = filtersHtml .. filter:GenerateRml()
            end
        end
        filtersHtml = filtersHtml .. '</div>'
    end

    -- Generate RML for all fields
    local fieldsHtml = ''
    for _, fieldName in ipairs(self.fieldOrder) do
        local field = self.fields[fieldName]
        if field and not field._isGroupChild then
            if field.GenerateRml then
                fieldsHtml = fieldsHtml .. field:GenerateRml()
            else
                -- Check if it's a control with buttons inside
                if field.ctrl then
                    -- Check if this is an RmlUi placeholder (from new EditorButton API)
                    if field.ctrl.isRmlUiPlaceholder and field.ctrl.children then
                        -- Children are already RmlUi buttons, use them directly
                        for _, rmlBtn in ipairs(field.ctrl.children) do
                            if rmlBtn and rmlBtn.GenerateRml then
                                fieldsHtml = fieldsHtml .. rmlBtn:GenerateRml()
                                table.insert(self.regularButtons, rmlBtn)
                            end
                        end
                    elseif field.ctrl.GenerateRml then
                        -- Single button with GenerateRml method
                        fieldsHtml = fieldsHtml .. field.ctrl:GenerateRml()
                        table.insert(self.regularButtons, field.ctrl)
                    end
                end
            end
        end
    end

    -- Generate path navigation if gridView has it (AssetView)
    local pathNavHtml = ''
    if self.gridView and self.gridView.pathNav then
        pathNavHtml = self.gridView.pathNav:GenerateRml()
    end

    -- Generate grid container if editor has a gridView
    local gridHtml = ''
    if self.gridView then
        gridHtml = string.format('<div id="%s" class="grid-container"></div>', self.gridView.gridId)
    end

    -- Combine buttons, filters, path nav, grid, and fields
    self.generatedRml = buttonsHtml .. filtersHtml .. pathNavHtml .. gridHtml .. fieldsHtml

    -- Mark as hidden by default
    self.hidden = true
end

-- New Chili finalization (new API with layout options)
function Editor:_FinalizeChiliNew(layout, opts)
    local actionButtons = layout.actionButtons or {}
    local customControls = layout.customControls or {}

    -- Build children array for Chili
    local children = {}

    -- Add action buttons first
    for _, btn in ipairs(actionButtons) do
        table.insert(children, btn)
    end

    -- Add custom controls if provided
    for _, ctrl in ipairs(customControls) do
        table.insert(children, ctrl)
    end

    -- Add ScrollPanel with fields
    local yPos = #actionButtons > 0 and 70 or 0
    table.insert(children, ScrollPanel:New {
        x = 0,
        y = yPos,
        bottom = 30,
        right = 0,
        borderColor = {0,0,0,0},
        horizontalScrollbar = false,
        children = { self.stackPanel },
    })

    -- Use the old Chili window creation
    self:_FinalizeChiliWindow(children, opts)
end

-- Show the editor in RmlUi mode
function Editor:ShowRmlUi()
    self.hidden = false
    if SB.view and SB.view.OpenEditor then
        -- Trigger view to display this editor
        for name, editor in pairs(SB.editors) do
            if editor == self then
                SB.view:DisplayEditor(name)
                break
            end
        end
    end
end

-- Hide the editor in RmlUi mode
function Editor:HideRmlUi()
    self.hidden = true
end
