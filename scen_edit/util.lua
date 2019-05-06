function MakeComponentPanel(parentPanel)
    local componentPanel = Control:New {
        parent = parentPanel,
        width = "100%",
        height = SB.conf.B_HEIGHT + 8,
        orientation = "horizontal",
        padding = {0, 0, 0, 0},
        itemMarging = {0, 0, 0, 0},
        margin = { 0, 0, 0, 0},
        resizeItems = false,
    }
    return componentPanel
end

function CallListeners(listeners, ...)
    for i = 1, #listeners do
        local listener = listeners[i]
        listener(...)
    end
end

function SB.GetPersistantModOptions()
    local modOpts = Spring.GetModOptions()
    return {
        _sl_address = modOpts._sl_address,
        _sl_port = modOpts._sl_port,
        _sl_write_path = modOpts._sl_write_path,
        _sl_launcher_version = modOpts._sl_launcher_version,
    }
end

SB.assignedCursors = {}
function SB.SetMouseCursor(name)
    SB.cursor = name
    if SB.cursor == nil then
        return
    end

    if SB.assignedCursors[name] == nil then
        Spring.AssignMouseCursor(name, name, true)
        SB.assignedCursors[name] = true
    end
    Spring.SetMouseCursor(name)
end

function SB.MakeSeparator(panel)
    local lblSeparator = Line:New {
        parent = panel,
        height = SB.conf.B_HEIGHT + 10,
        width = "100%",
    }
    return lblSeparator
end

-- Unused
function SB.PassToGadget(prefix, tag, data)
    local newTable = { tag = tag, data = data }
    local msg = prefix .. "|table" .. table.show(newTable)
    Spring.SendLuaRulesMsg(msg)
end

-- FIXME: This becomes complicated very fast
-- Maybe Field classes should be responsible for providing display instead?
SB.humanExpressionMaxLevel = 3
function SB.humanExpression(data, exprType, dataType, level)
    local success, result = pcall(function()

    if level == nil then
        level = 1
    end
    if SB.humanExpressionMaxLevel < level then
        return "..."
    end

    if exprType == "condition" and data.typeName:find("compare_") then
        local firstExpr = SB.humanExpression(data.first, "value", nil, level + 1)
        local relation
        if data.typeName == "compare_number" then
            relation = SB.humanExpression(data.relation, "numeric_comparison", nil, level + 1)
        else
            relation = SB.humanExpression(data.relation, "identity_comparison", nil, level + 1)
        end
        local secondExpr = SB.humanExpression(data.second, "value", nil, level + 1)
        local condHumanName = SB.metaModel.functionTypes[data.typeName].humanName
        return condHumanName .. " (" .. firstExpr .. " " .. relation .. " " .. secondExpr .. ")"
    elseif exprType == "action" then
        local actionDef = SB.metaModel.actionTypes[data.typeName]
        local humanName = actionDef.humanName .. " ("
        for i, input in pairs(actionDef.input) do
            humanName = humanName .. SB.humanExpression(data[input.name], "value", input.type, level + 1)
            if i ~= #actionDef.input then
                humanName = humanName .. ", "
            end
        end
        return humanName .. ")"
    elseif (exprType == "value" and data.type == "expr") or exprType == "condition" then
        local expr = data.value or data
        local exprHumanName = SB.metaModel.functionTypes[expr.typeName].humanName

        local paramsStr = ""
        local first = true
        for k, v in pairs(expr) do
            if k ~= "typeName" then
                if not first then
                    paramsStr = paramsStr .. ", "
                end
                first = false
                paramsStr = paramsStr .. SB.humanExpression(v, "value", k, level + 1)
            end
        end
        return exprHumanName .. " (" .. paramsStr .. ")"
    elseif exprType == "value" then
        if data.type == "const" then
            -- if dataType ~= nil then
            --     local fieldType = SB.__GetFieldType(dataType)
            --     Spring.Echo(dataType, not not fieldType)
            --     Spring.Echo(fieldType)
            -- end
            if dataType == "unitType" then
                local unitDef = UnitDefs[data.value]
                local dataIDStr = "(id=" .. tostring(data.value) .. ")"
                if unitDef then
                    return tostring(unitDef.name) -- .. " " .. dataIDStr
                else
                    return dataIDStr
                end
            elseif dataType == "featureType" then
                local featureDef = FeatureDefs[data.value]
                local dataIDStr = "(id=" .. tostring(data.value) .. ")"
                if featureDef then
                    return tostring(featureDef.name) -- .. " " .. dataIDStr
                else
                    return dataIDStr
                end
            elseif dataType == "unit" then
                local unitID = data.value
                local dataIDStr = "(id=" .. tostring(data.value) .. ")"
                if Spring.ValidUnitID(unitID) then
                    local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
                    if unitDef then
                        return tostring(unitDef.name) .. " " .. dataIDStr
                    else
                        return dataIDStr
                    end
                else
                    return dataIDStr
                end
            elseif dataType == "trigger" then
                local trigger = SB.model.triggerManager:getTrigger(data.value)
                return trigger.name
            elseif dataType == "position" then
                return string.format("(%.1f,%.1f,%.1f)", data.value.x, data.value.y, data.value.z)
            elseif dataType and dataType.type == "order" then
                local orderTypeName = data.value.typeName
                local orderType = SB.metaModel.orderTypes[orderTypeName]
                local humanName = orderType.humanName
                for _, input in pairs(orderType.input) do
                    humanName = humanName .. " " ..
                        SB.humanExpression(data.value[input.name], "value", input.type, level + 1)
                end
                return humanName
            -- array and custom data types
            elseif type(data.value) == "table" then
                if String.Ends(dataType, "_array") then
                    return dataType .. "{...}"
                else
                    local retStr = ""
                    for k, v in pairs(data.value) do
                        if k ~= "typeName" then
                            if retStr ~= "" then
                                retStr = retStr .. ", "
                            end
                            retStr = retStr .. tostring(v.value)
                        end
                    end
                    return retStr
                end
            else
                return tostring(data.value)
            end
        elseif data.type == "scoped" then
            return "scoped: " .. data.value
        elseif data.type == "var" then
            return SB.model.variableManager:getVariable(data.value).name
        end
        return "nothing"
    elseif exprType == "numeric_comparison" then
        return SB.metaModel.numericComparisonTypes[data.value]
    elseif exprType == "identity_comparison" then
        return SB.metaModel.identityComparisonTypes[data.value]
    end
    return data.humanName
    end)
    if success then
        return result
    else
        return "Err." .. tostring(result)
    end
end

function SB.IsButton(ctrl)
    -- FIXME: checking for control type via .classname will cause skinning issues
    return ctrl.classname == "button" or ctrl.classname == "toggle_button"
end

local function hintCtrlFunction(ctrl, startTime, timeout, color)
    local deltaTime = os.clock() - startTime
    local newColor = Table.DeepCopy(color)
    newColor[4] = 0.2 + math.abs(math.sin(deltaTime * 6) / 3.14)

    -- FIXME: checking for control type via .classname will cause skinning issues
    if ctrl.classname == "label" or ctrl.classname == "checkbox" or ctrl.classname == "editbox" then
        ctrl.font.color = newColor
    else
        ctrl.backgroundColor = newColor
    end
    ctrl:Invalidate()
    SB.delay(
        function()
            if os.clock() - startTime < timeout then
                hintCtrlFunction(ctrl, startTime, timeout, color)
            else
                -- FIXME: checking for control type via .classname will cause skinning issues
                if ctrl.classname == "label" or ctrl.classname == "checkbox" or ctrl.classname == "editbox" then
                    ctrl.font.color = ctrl._originalColor
                else
                    ctrl.backgroundColor = ctrl._originalColor
                end
                ctrl._originalColor = nil
                ctrl:Invalidate()
            end
        end
    )
end

function SB.HintEditor(editor, color, timeout)
    local ctrls = editor:GetAllControls()
    SB.HintControls(ctrls, color, timeout)
end

function SB.HintControls(ctrls, color, timeout)
    timeout = timeout or 1
    color = color or {1, 0, 0, 1}
    local startTime = os.clock()
    for _, ctrl in pairs(ctrls) do
        if ctrl._originalColor == nil then
            -- FIXME: checking for control type via .classname will cause skinning issues
            if ctrl.classname == "label" or ctrl.classname == "checkbox" or ctrl.classname == "editbox" then
                ctrl._originalColor = Table.DeepCopy(ctrl.font.color)
            else
                ctrl._originalColor = Table.DeepCopy(ctrl.backgroundColor)
            end
            hintCtrlFunction(ctrl, startTime, timeout, color)
        end
    end
end

function SB.SetClassName(class, className)
    class.className = className
    if SB.commandManager:getCommandType(className) == nil then
        SB.commandManager:addCommandType(className, class)
    end
end

local __fieldTypeMapping
function SB.__GetFieldType(name)
    if not __fieldTypeMapping then
        __fieldTypeMapping = {
            unit = UnitField,
            feature = FeatureField,
            area = AreaField,
            trigger = TriggerField,
            unitType = UnitTypeField,
            featureType = FeatureTypeField,
            team = TeamField,
            number = NumericField,
            string = StringField,
            bool = BooleanField,
            numericComparison = NumericComparisonField,
            identityComparison = IdentityComparisonField,
            position = PositionField,
        }
    end

    return __fieldTypeMapping[name]
end

function SB.createNewPanel(opts)
    local dataTypeName = opts.dataType.type

    local fieldType = SB.__GetFieldType(dataTypeName)

    if fieldType then
        opts.FieldType = fieldType
    elseif dataTypeName == "order" then
        opts.FieldType = function(tbl)
            tbl.dataType = opts.dataType
            tbl.trigger = opts.trigger
            tbl.params = opts.params
            tbl.windowType = OrderWindow
            return TriggerDataTypeField(tbl)
        end
        -- return OrderPanel(opts)
    elseif dataTypeName:find("_array") then
        -- return GenericArrayPanel(opts)
        local atomicType = dataTypeName:gsub("_array", "")
        local atomicField = __fieldTypeMapping[atomicType]
        -- override TypePanel's FieldType in order to use a custom type
        opts.FieldType = function(tbl)
            -- override ArrayField's type in order to pass trigger data for
            -- element creation
            tbl.type = function(tblEl)
                tblEl.dataType = {
                    type = atomicType,
                    sources = opts.dataType.sources,
                }
                tblEl.trigger = opts.trigger
                tblEl.params = opts.params
                return TriggerDataTypeField(tblEl)
            end
            return ArrayField(tbl)
        end
    elseif dataTypeName == "function" or dataTypeName == "action" then
        opts.FieldType = function(tbl)
            tbl.dataType = opts.dataType
            tbl.trigger = opts.trigger
            tbl.params = opts.params
            return FunctionField(tbl)
        end
    elseif dataTypeName ~= nil and SB.metaModel:GetCustomDataType(dataTypeName) then
        opts.FieldType = function(tbl)
            tbl.dataType = opts.dataType
            tbl.trigger = opts.trigger
            tbl.params = opts.params
            return TriggerDataTypeField(tbl)
        end
    else
        Log.Error("No panel for this data: " .. tostring(dataTypeName))
        return
    end
    return TypePanel(opts)
end

SB.delayed = {
--     Update      = {},
    GameFrame   = {},
    DrawWorld   = {},
    DrawScreen  = {},
    DrawScreenPost  = {},
    DrawScreenEffects = {},
    Initialize = {},
}
function SB.delayGL(func, params)
    SB.Delay("DrawWorld", func, params)
end
function SB.delay(func, params)
    SB.Delay("GameFrame", func, params)
end
function SB.OnInitialize(func, params)
    SB.Delay("Initialize", func, params)
end
function SB.Delay(name, func, params)
    local delayed = SB.delayed[name]
    table.insert(delayed, {func, params or {}})
end

function SB.executeDelayed(name)
    local delayed = SB.delayed[name]
    SB.delayed[name] = {}
    for i, call in pairs(delayed) do
        xpcall(function() call[1](unpack(call[2])) end,
              function(err) Log.Error(debug.traceback(err)) end )
    end
end

function SB.glToFontColor(color)
    return "\255" ..
        string.char(math.ceil(255 * color.r)) ..
        string.char(math.ceil(255 * color.g)) ..
        string.char(math.ceil(255 * color.b))
end

function SB.SetControlEnabled(control, enabled)
    control:SetEnabled(enabled)

    control.disableChildrenHitTest = not enabled
    -- Not a Chili flag, used internally in SB for keybinding
    control.__disabled = not enabled
    control:Invalidate()
    for _, childCtrl in pairs(control.childrenByName) do
        SB.SetControlEnabled(childCtrl, enabled)
    end
end

-- Make window modal in respect to the source control.
-- The source control will not be usable until the window is disposed.
function SB.MakeWindowModal(window, source)
    -- FIXME: This isn't an ideal way to verify is something is an instance of the Window class, improve.
    while not source.classname:find("window")  do
        -- FIXME: would like to avoid this; when debugging change the if
        -- if false then
        --     Log.Warning("SB.MakeWindowModal", "Sent source which isn't a window")
        --     Log.Warning(debug.traceback())
        -- end
        source = source.parent
    end
    SB.SetControlEnabled(source, false)

    if not window.OnDispose then
        window.OnDispose = {}
    end
    table.insert(window.OnDispose,
        function()
            SB.SetControlEnabled(source, true)
        end
    )
    if not window.OnHide then
        window.OnHide = {}
    end
    table.insert(window.OnHide,
        function()
            SB.SetControlEnabled(source, true)
        end
    )
end

-- We setup a fake Chili control that does the rendering
-- It helps us set the appropriate font and more importantly
-- it makes it easier to properly order rendering, so it stays
-- on top of other controls
local __displayControl
function SB.SetGlobalRenderingFunction(f)
    if not __displayControl then
        __displayControl = Control:New {
            parent = screen0,
            x = 0, y = 0,
            bottom = 0, right = 0,
            drawcontrolv2 = true,
        }
    end
    __displayControl.DrawControl = function(...)
        if f and f(...) then
            __displayControl:Invalidate()
            __displayControl:BringToFront()
        end
    end
    if f ~= nil then
        __displayControl:BringToFront()
    else
        __displayControl:Hide()
    end
end

function SB.DirExists(path, ...)
    return (#VFS.SubDirs(path, "*", ...) + #VFS.DirList(path, "*", ...)) ~= 0
end

function SB.RemoveDirRecursively(path)
    for _, subDir in ipairs(VFS.SubDirs(path, "*", VFS.RAW)) do
        SB.RemoveDirRecursively(subDir)
        os.remove(subDir)
    end

    for _, file in ipairs(VFS.DirList(path, "*", VFS.RAW)) do
        os.remove(file)
    end

    os.remove(path)
end

local warningsIssued = {}
function SB.MinVersion(versionNumber, feature)
    if Script.IsEngineMinVersion == nil or not Script.IsEngineMinVersion(versionNumber) then
        if warningsIssued[feature] == nil then
            Log.Warning(feature .. " requires a minimum Spring version of " .. tostring(versionNumber))
            warningsIssued[feature] = true
        end
        return false
    end
    return true
end

function SB.FunctionExists(fun, feature)
    if fun ~= nil then
        if warningsIssued[feature] == nil then
            Log.Warning(feature .. " feature missing.")
            warningsIssued[feature] = true
        end
        return false
    end
    return true
end

local __minHeight, __maxHeight = Spring.GetGroundExtremes()
function SB.TraceScreenRay(x, y, opts)
    opts = opts or {}
    local onlyCoords = opts.onlyCoords
    if onlyCoords == nil then
        onlyCoords = false
    end
    local useMinimap = opts.useMinimap
    if useMinimap == nil then
        useMinimap = false
    end
    local includeSky = opts.includeSky
    if includeSky == nil then
        includeSky = true
    end
    local ignoreWater= opts.ignoreWater
    if ignoreWater== nil then
        ignoreWater = true
    end
    local D = opts.D
    -- if D == nil then
        --D = (__maxHeight + __minHeight) / 2
    -- end
    local selType = opts.type

    local traceType, value
    if selType ~= nil and selType ~= "unit" and selType ~= "feature" then
        traceType, value = Spring.TraceScreenRay(x, y, true, useMinimap, includeSky, ignoreWater, D)
    else
        traceType, value = Spring.TraceScreenRay(x, y, onlyCoords, useMinimap, includeSky, ignoreWater, D)
    end

    if selType == "position" then
        return "position", {x=value[1], y=value[2], z=value[3]}
    end

    -- FIXME: How should SB.view.displayDevelop be used? It is currently intended primarily for areas
    if traceType == "ground" and SB.view.displayDevelop and
       not onlyCoords and selType ~= "unit" and selType ~= "feature" then
        if selType then
            local bridge = ObjectBridge.GetObjectBridge(selType)
            local _value = bridge.GetObjectAt(value[1], value[3])
            if _value then
                traceType = selType
                value = _value
            end
        else
            for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
                -- we utilize engine trace for unit and feature
                if name ~= "unit" and name ~= "feature" and
                   bridge.GetObjectAt then
                    local _value = bridge.GetObjectAt(value[1], value[3])
                    if _value then
                        traceType = name
                        value = _value
                        break
                    end
                end
            end
        end
    end

    if traceType == "ground" and selType then
        return false
    end

    return traceType, value
end

function SB.ExecuteEvent(eventName, params)
    if Script.GetSynced() then
        SB.rtModel:OnEvent(eventName, params)
    else
        local event = {
            eventName = eventName,
            params = params,
        }
        local msg = Message("event", event)
        SB.messageManager:sendMessage(msg, nil, "game")
    end
end


-- Spring Config related
function SB.IsSpringConfigValid(springConfig)
    for name, config in pairs(springConfig) do
        assert(config.type ~= nil, name)
        assert(config.value ~= nil, name)
        local GetFunction
        if config.type == 'int' then
            GetFunction = Spring.GetConfigInt
        elseif config.type == 'string' then
            GetFunction = Spring.GetConfigString
        elseif config.type == 'float' then
            GetFunction = Spring.GetConfigFloat
        end

        local value = GetFunction(name)
        if value ~= config.value then
            -- exact match or value is missing
            if value == nil or
               (config.min == nil and config.max == nil) then
                return false
            end

            if config.min ~= nil then
                assert(config.min <= config.value, name)
                if value < config.min then
                    return false
                end
            end
            if config.max ~= nil then
                assert(config.max >= config.value, name)
                if value > config.max then
                    return false
                end
            end
        end
    end
    return true
end

function SB.SetSpringConfig(springConfig)
    for name, config in pairs(springConfig) do
        local SetFunction
        if config.type == 'int' then
            SetFunction = Spring.SetConfigInt
        elseif config.type == 'string' then
            SetFunction = Spring.SetConfigString
        elseif config.type == 'float' then
            SetFunction = Spring.SetConfigFloat
        end
        SetFunction(name, config.value)
    end
end

function SB.AskToRestart()
    local window
    window = Window:New {
        x = "25%",
        y = "15%",
        width = 450,
        height = 150,
        parent = screen0,
        resizable = false,
        children = {
            TextBox:New {
                text = "Spring needs to reload for changes to take effect.",
                --text = "Spring needs to be restarted manually for changes to take effect."
                x = "1%",
                y = 10,
                width = "100%",
            },
            Button:New {
                caption = "Reload",
                -- caption = "Quit",
                x = "35%",
                width = "30%",
                height = 40,
                bottom = 0,
                OnClick = {
                    function()
                        Spring.Reload(VFS.LoadFile("_script.txt"))
                        window:Dispose()
                        -- Spring.SendCommands("quit", "quitforce")
                    end
                }
            }
        }
    }
end

function SB.GetLoadScript()
    if SB.loadScript == nil then
        local loadScriptTxt = VFS.LoadFile("_script.txt")
        SB.loadScript = StartScript.ParseStartScript(loadScriptTxt) or {}
    end
    return SB.loadScript
end