--- Action module

--- Action class. Inherit to create custom Actions
-- @type Action
Action = LCS.class{}

-- Registered action classes
SB.actionRegistry = {}

function Table.FindKey(tbl, value)
    for k, v in pairs(tbl) do
        if v == value then
            return k
        end
    end
end

--- Register the action.
-- @tparam table opts Table
-- @tparam string opts.name Machine name of the action control. Built-in actions have the "sb_" prefix.
-- @tparam Action opts.action Class inheritng from Action
-- @tparam string opts.tooltip Mouseover tooltip.
-- @tparam string opts.image Path to the icon.
-- Use this if you want to show the action in the toolbar
-- @tparam number[opt=0] opts.toolbar_order Order in the control toolbar.
-- @tparam string opts.hotkey Hotkey configuration.
-- @usage
-- SaveAction = Action:extends{}
-- SaveAction:Register({
--     name = "myAction",
--     tooltip = "Do something",
--     image = SB_IMG_DIR .. "my_icon.png",
--     toolbar_order = 42,
-- })
function Action:Register(opts)
    assert(opts.name, "Missing name for action.")
    assert(not SB.actionRegistry[opts.name],
        "Action with name: " .. opts.name .. " already exists")

    Log.Notice("Registering action: " .. opts.name)

    opts.action = self

    if opts.image and opts.toolbar_order == nil then
        opts.toolbar_order = 0
    end

    if opts.tooltip == nil then
        opts.tooltip = ""
    elseif opts.hotkey ~= nil then
        local keyText = " ("
        if opts.hotkey.alt then
            keyText = keyText .. "Alt "
        end
        if opts.hotkey.ctrl then
            keyText = keyText .. "Ctrl "
        end
        if opts.hotkey.shift then
            keyText = keyText .. "Shift "
        end

        -- local keySymbol = Spring.GetKeySymbol(opts.hotkey.key) or ""
        -- keySymbol = String.Capitalize(keySymbol)
        local keySymbol = Table.FindKey(KEYSYMS, opts.hotkey.key) or ""
        keyText = keyText .. keySymbol .. ")"
        opts.tooltip = opts.tooltip .. keyText
    end
    opts.icon = opts.icon or ""
    opts.order = opts.order or 0
    opts.limit_state = not not opts.limit_state

    SB.actionRegistry[opts.name] = opts
end

--- Deregister the action.
-- @usage
-- MyAction:Deregister()
-- -- alternatively
-- Action.Deregister("my-action")
function Action:Deregister(name)
    if type(self) == "string" then
        SB.actionRegistry[self] = nil
    else
        SB.actionRegistry[self.name] = nil
    end
    -- TODO: Remove the action from the GUI?
end

local actionsLoaded = false
local actionKeys = {}

function Action.GetActionsForKeyPress(default_state, key, mods, isRepeat, label, unicode)
    if not actionsLoaded then
        Action.PostLoadActions()
    end

    local actions = actionKeys[key]
    if not actions then
        return
    end
    for _, actionCfg in ipairs(actions) do
        if actionCfg.hotkey.ctrl  == mods.ctrl and
           actionCfg.hotkey.shift == mods.shift and
           actionCfg.hotkey.alt   == mods.alt and
        -- some actions cannot be done outside the default state
           not (actionCfg.limit_state and not default_state) then
            local action = actionCfg.action()
            if not action.canExecute or action:canExecute() then
                return action
            else
                return
            end
        end
    end
end

function Action.PostLoadActions()
    actionsLoaded = true
    for name, action in pairs(SB.actionRegistry) do
        if action.hotkey and action.hotkey.key then
            if not actionKeys[action.hotkey.key] then
                actionKeys[action.hotkey.key] = {}
            end
            action.hotkey.ctrl = not not action.hotkey.ctrl
            action.hotkey.shift = not not action.hotkey.shift
            action.hotkey.alt = not not action.hotkey.alt
            table.insert(actionKeys[action.hotkey.key], action)
        end
    end
end