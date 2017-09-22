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

    self.fields = {}
    self.fieldOrder = {}

    self.btnClose = Button:New {
        caption = 'Close',
        width = 100,
        right = 15,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        OnClick = {
            function()
                self:__MaybeClose()
                -- FIXME: should be resetting to the default state?
                -- SB.stateManager:SetState(DefaultState())
            end
        },
    }

    self.stackPanel = StackPanel:New {
        y = 0,
        x = 0,
        right = 0,

        centerItems = false,

        -- autosize = true, -- FIXME: autosize is not working. If enabled (and height disabled) it will cause controls not to render any changes.
        -- debug = true,
        resizeItems = true, -- FIXME: This is also temporarily enabled because of the bug above

        itemPadding = {0,10,0,0},
        padding = {0,0,0,0},
        margin = {0,0,0,0},
        itemMargin = {5,0,0,0},
    }
    self.stackPanel:DisableRealign()
end

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
-- @tparam table children List of Chili controls.
-- @tparam table opts Editor options
-- @tparam[opt=false] boolean opts.notMainWindow If true, editor will not be added to the main panel (right side), but will instead be a floating window.
-- @tparam[opt=550] boolean opts.width Specifies window width. Only applicable for floating windows.
-- @tparam[opt=550] boolean opts.height Specifies window height. Only applicable for floating windows.
-- @tparam[opt=false] boolean opts.noCloseButton If true, there will be no close button.
-- @tparam boolean opts.disposeOnClose If true, the window will be disposed when closed. Defaults to true if opts.notMainWindow is true, otherwise it defaults to false.
function Editor:Finalize(children, opts)
    if not self.__initializing then
        Log.Error("\"Editor.init(self)\" wasn't invoked properly.")
        Log.Error(debug.traceback())
    end

    opts = opts or {}
    if not opts.noCloseButton then
        table.insert(children, self.btnClose)
    end

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
        }
        self.stackPanel:EnableRealign()
        self:_MEGA_HACK()
        SB.view.tabbedWindow:SetMainPanel(self.window)
    else
        if opts.disposeOnClose == nil then
            self.__disposeOnClose = true
        end
        -- TODO: Make configurable
        self.window = Window:New {
            parent = screen0,
            x = opts.x or "40%",
            y = opts.y or "40%",
            width = opts.width or 550,
            height = opts.height or 500,
            resizable  = false,
            caption = '',
            children = children,
            OnParentPost = OnShow,
            OnOrphan = OnHide,
        }
        self.keyListener = function(key)
            if key == Spring.GetKeyCode("esc") then
                self:__MaybeClose()
                return true
            elseif key == Spring.GetKeyCode("enter") or key == Spring.GetKeyCode("numpad_enter") then
                if self.ConfirmDialog then
                    if self:ConfirmDialog() then
                        self:__MaybeClose()
                    end
                    return true
                elseif not opts.noCloseButton then
                    self:__MaybeClose()
                    return true
                end
            end
        end
        self:__AddKeyListener()

        self.stackPanel:EnableRealign()
        self:_MEGA_HACK()
    end

    self.__initializing = false
end

function Editor:_MEGA_HACK()
    -- FIXME: Mega hack to manually resize the stackPanel since autosize is broken
    SB.delay(function()
    SB.delay(function()
    self.stackPanel.resizeItems = false
    local h = 0
    for _, c in pairs(self.stackPanel.children) do
        if type(c) == "table" then
            c:UpdateLayout()
            h = h + c.height + self.stackPanel.itemPadding[2]
        end
    end
    self.stackPanel:Resize(nil, h)
    end)
    end)
end

-- Don't use this directly because ordering would be messed up.
function Editor:_SetFieldVisible(name, visible)
    if not self.fields[name] then
        Log.Error("Trying to set visibility on an invalid field: " .. tostring(name))
        return
    end

    if visible == nil then
        return
    end

    local ctrl = self.fields[name].ctrl
    -- HACK: use Add/Remove instead of Show/Hide to have proper ordering
    --if ctrl.visible ~= visible then
    if ctrl._visible ~= visible then
        if visible then
            self.stackPanel:AddChild(ctrl)
            ctrl._visible = true
-- 			ctrl:Show()
        else
            self.stackPanel:RemoveChild(ctrl)
            ctrl._visible = false
-- 			ctrl:Hide()
        end
    end
end

--- Sets fields which are to be made invisible.
-- @tparam {string, ...} ... Field names to be set invisible
function Editor:SetInvisibleFields(...)
    self.stackPanel:DisableRealign()

    local fields = {...}
    for i = #self.fieldOrder, 1, -1 do
        local name = self.fieldOrder[i]
        self:_SetFieldVisible(name, false)
    end

    self.stackPanel.resizeItems = true

    for i = 1, #self.fieldOrder do
        local name = self.fieldOrder[i]
        if not table.ifind(fields, name) then
            self:_SetFieldVisible(name, true)
        end
    end

    -- HACK: because we're Add/Removing items to the stackPanel instead of using Show/Hide on the control itself, we need to to execute a :_HackSetInvisibleFields later
    for _, field in pairs(self.fields) do
        if field._HackSetInvisibleFields then
            field:_HackSetInvisibleFields(fields)
        end
    end

    self.stackPanel:EnableRealign()
    self:_MEGA_HACK()
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
    self.stackPanel:RemoveChild(field.ctrl)
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
    field:Added()
end

function Editor:_AddField(field)
    self.fields[field.name] = field
    field.ev = self
end

function Editor:AddControl(name, children)
    self.fields[name] = {
        ctrl = self:_AddControl(name, children),
        name = name,
    }
    return self.fields[name]
end

function Editor:_AddControl(name, children)
    local ctrl = Control:New {
        autosize = true,
        padding = {0, 0, 0, 0},
        children = children
    }
    self.stackPanel:AddChild(ctrl)
    table.insert(self.fieldOrder, name)
    return ctrl
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
    field:Set(value)
end
function Editor:Update(name, _source)
    local field = self.fields[name]
    if not field then
        return
    end

    field:Update(_source)

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
        self.__keybinding[KEY_ZERO + i] = button.OnClick
        button.tooltip = button.tooltip .. " (" .. tostring(i) .. ")"
    end
end

function Editor:AddKeybinding(key, f)
    self.__keybinding[key] = {f}
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
    -- set missing fields to nil
    for name, field in pairs(self.fields) do
        -- some fields (like separator) don't have .Set
        if self.fields[name].Set and tbl[name] == nil then
            self.fields[name]:Set(nil)
        end
    end
    for name, data in pairs(tbl) do
        self.fields[name]:Load(data)
    end
end

-- Registered editor classes
SB.editorRegistry = {}
-- Globally available editor instances
SB.editors = {}

--- Register editor globally.
-- @tparam table opts Table
-- @tparam string opts.name Machine name of the editor control.
-- @tparam Editor opts.editor Class inheritng from Editor
-- @tparam string opts.tab Tab in which to place the editor button.
-- @tparam string opts.caption Title of the Editor control.
-- @tparam string opts.tooltip Mouseover tooltip.
-- @tparam string opts.image Path to the Editor icon.
-- @usage
-- GrassEditor = Editor:extends{}
-- Editor.Register({
--     name = "grassEditor",
--     editor = GrassEditor,
--     tab = "Map",
--     caption = "Grass",
--     tooltip = "Edit grass",
--     image = SB_IMG_DIR .. "grass.png",
--     order = 4,
-- })
function Editor.Register(opts)
    assert(opts.name, "Missing name for editor.")
    assert(not SB.editorRegistry[opts.name],
        "Editor with name: " .. opts.name .. " already exists")
    assert(opts.editor, "Missing editor for: " .. opts.name)

    Log.Notice("Registering: " .. opts.name)

    opts.tab = opts.tab or "Other"
    opts.caption = opts.caption or name
    opts.tooltip = opts.tooltip or opts.caption
    opts.image = opts.image or ""
    opts.order = opts.order or math.huge

    SB.editorRegistry[opts.name] = opts
end

--- Deregister editor globally.
-- @tparam string name Name of Editor to unregister
function Editor.Deregister(name)
    assert(opts.name, "Missing name for editor.")
    SB.editorRegistry[opts.name] = opts
end

-- We load these fields last as they might be/contain subclasses of editor view
SB_VIEW_FIELDS_DIR = SB_VIEW_DIR .. "fields/"
SB.IncludeDir(SB_VIEW_FIELDS_DIR)
