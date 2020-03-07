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
-- @tparam[opt=false] boolean opts.notMainWindow If true,
--   editor will not be added to the main panel (right side), but will instead be a floating window.
-- @tparam[opt=550] boolean opts.width Specifies window width. Only applicable for floating windows.
-- @tparam[opt=550] boolean opts.height Specifies window height. Only applicable for floating windows.
-- @tparam table opts.buttons Specifies what common buttons should be added to the bottom of the editor.
--  Values include "ok", "cancel" and "close"
-- @tparam boolean opts.disposeOnClose If true, the window will
--   be disposed when closed. Defaults to true if opts.notMainWindow is true, otherwise it defaults to false.
function Editor:Finalize(children, opts)
    if not self.__initializing then
        Log.Error("\"Editor.init(self)\" wasn't invoked properly.")
        Log.Error(debug.traceback())
        assert(self.__initializing, "\"Editor.init(self)\" wasn't invoked properly.")
    end

    opts = opts or {}
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
        SB.view.tabbedWindow:SetMainPanel(self.window)
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
    self.stackPanel:EnableRealign()
    self.stackPanel:Invalidate()

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

    local ctrl = field.ctrl
    --if ctrl.visible ~= visible then
    if ctrl._visible ~= visible then
        if visible then
            -- self.stackPanel:AddChild(ctrl)
            ctrl:Show()
            ctrl._visible = true
        else
            -- self.stackPanel:RemoveChild(ctrl)
            ctrl:Hide()
            ctrl._visible = false
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

    self.stackPanel:EnableRealign()
    self.stackPanel:Invalidate()
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
    field:Set(value)
end
function Editor:Update(name, _source)
    local field = self.fields[name]
    assert(field, "No such field to update: " .. tostring(name))

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
end

--- Deregister the editor.
-- @usage
-- MyEditor:Deregister()
-- -- alternatively
-- Editor.Deregister("my-editor")
function Editor:Deregister()
    if type(self) == "string" then
        SB.editorRegistry[self] = nil
    else
        SB.editorRegistry[self.name] = nil
    end
    -- TODO: Remove the editor from the GUI?
end

-- We load these fields last as they might be/contain subclasses of editor view
SB.IncludeDir(Path.Join(SB.DIRS.SRC, 'view/fields'))
