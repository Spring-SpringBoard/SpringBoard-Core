Editor = LCS.class{}

function Editor:init(opts)
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
                self.window:Hide()
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

-- Override
function Editor:OnStartChange(name, value)
end
-- Override
function Editor:OnEndChange(name, value)
end
-- Override
function Editor:OnFieldChange(name, value)
end
-- Override
function Editor:IsValidTest(state)
    return false
end
-- Override
function Editor:OnEnterState(state)
end
-- Override
function Editor:OnLeaveState(state)
end

function Editor:_OnEnterState(state)
    if self:IsValidTest(state) then
        self:OnEnterState(state)
    end
end
function Editor:_OnLeaveState(state)
    if self:IsValidTest(state) then
        self:OnLeaveState(state)
    end
end

-- NOTICE: Invoke :Finalize at the end of init
function Editor:Finalize(children, opts)
    opts = opts or {}
    if not opts.noCloseButton then
        table.insert(children, self.btnClose)
    end

    if not opts.notMainWindow then
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
        }
        self.stackPanel:EnableRealign()
        self:_MEGA_HACK()
        SB.view:SetMainPanel(self.window)
    else
        if not opts.noDispose then
            table.insert(self.btnClose.OnClick, function()
                self.window:Dispose()
            end)
        end
        -- TODO: Make configurable
        self.window = Window:New {
            parent = screen0,
            x = "40%",
            y = "40%",
            width = 550,
            height = 500,
            resizable  = false,
            caption = '',
            children = children,
        }
        self.stackPanel:EnableRealign()
        self:_MEGA_HACK()
    end
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

function Editor:RemoveField(name)
    local field = self.fields[name]
    for i, orderName in pairs(self.fieldOrder) do
        if orderName == name then
            table.remove(self.fieldOrder, i)
            break
        end
    end
    self.stackPanel:RemoveChild(field.ctrl)
    self.fields[name] = nil
end
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

function Editor:Set(name, value)
    local field = self.fields[name]
    field:Set(value)
end
function Editor:Update(name, _source)
    local field = self.fields[name]

    field:Update(_source)

    -- update listeners and current state
    self:OnFieldChange(field.name, field.value)
    local currentState = SB.stateManager:GetCurrentState()
    if self:IsValidTest(currentState) then
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

function Editor:Serialize()
    local retVal = {}
    for name, field in pairs(self.fields) do
        if field.Serialize then
            retVal[name] = field:Serialize()
        end
    end
    return retVal
end

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

-- Supported opts:
-- name (string)
-- editor (class to be instanced)
-- tab (tab in which to place the editor button)
-- caption (string)
-- tooltip (string)
-- image (string, path to file)
function Editor.Register(opts)
    assert(opts.name, "Missing name for editor.")
    assert(not SB.editorRegistry[opts.name],
        "Editor with name: " .. opts.name .. " already exists")
    assert(opts.editor, "Missing editor for: " .. opts.name)
    opts.tab = opts.tab or "Other"
    opts.caption = opts.caption or name
    opts.tooltip = opts.tooltip or opts.caption
    opts.image = opts.image or ""

    SB.editorRegistry[opts.name] = opts
end

function Editor.Deregister(name)
    assert(opts.name, "Missing name for editor.")
    SB.editorRegistry[opts.name] = opts
end

-- We load these fields last as they might be/contain subclasses of editor view
SB_VIEW_FIELDS_DIR = SB_VIEW_DIR .. "fields/"
SB.IncludeDir(SB_VIEW_FIELDS_DIR)
