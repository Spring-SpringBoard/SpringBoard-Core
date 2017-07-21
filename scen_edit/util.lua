SB.classes = {}
-- include this dir
SB.classes[SB_DIR .. "util.lua"] = true

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

--non recursive file include
function SB.IncludeDir(dirPath)
    local files = VFS.DirList(dirPath)
    local context = Script.GetName()
    for i = 1, #files do
        local file = files[i]
        -- don't load files ending in _gadget.lua in LuaUI nor _widget.lua in LuaRules
        if file:sub(-string.len(".lua")) == ".lua" and
            (context ~= "LuaRules" or file:sub(-string.len("_widget.lua")) ~= "_widget.lua") and
            (context ~= "LuaUI" or file:sub(-string.len("_gadget.lua")) ~= "_gadget.lua") then

            SB.Include(file)
        end
    end
end

function SB.Include(path)
    if not SB.classes[path] then
        -- mark it included before it's actually included to prevent circular inclusions
        SB.classes[path] = true
        VFS.Include(path)
    end
end

function SB.ZlibCompress(str)
    return tostring(#str) .. "|" .. VFS.ZlibCompress(str)
end

function SB.ZlibDecompress(str)
    local compressedSize = 0
    local strStart = 0
    for i = 1, #str do
        local substr = str:sub(1, i)
        if str:sub(i,i) == '|' then
            compressedSize = tonumber(str:sub(1, i - 1))
            strStart = i + 1
            break
        end
    end
    if compressedSize == 0 then
        error("string is not of valid format")
    end
    return VFS.ZlibDecompress(str:sub(strStart, #str), compressedSize)
end

function CallListeners(listeners, ...)
    for i = 1, #listeners do
        local listener = listeners[i]
        listener(...)
    end
end

function SB.checkAreaIntersections(x, z)
    local areas = SB.model.areaManager:getAllAreas()
    local selected, dragDiffX, dragDiffZ
    for _, areaID in pairs(areas) do
        local area = SB.model.areaManager:getArea(areaID)
        local objectX, _, objectZ = areaBridge.spGetObjectPosition(areaID)
        if x >= area[1] and x < area[3] and z >= area[2] and z < area[4] then
            selected = areaID
            dragDiffX = objectX - x
            dragDiffZ = objectZ - z
        end
    end
    return selected, dragDiffX, dragDiffZ
end

SB.assignedCursors = {}
function SB.SetMouseCursor(name)
    SB.cursor = name
    if SB.cursor ~= nil then
        if SB.assignedCursors[name] == nil then
            Spring.AssignMouseCursor(name, name, false)
            SB.assignedCursors[name] = true
        end
        Spring.SetMouseCursor(SB.cursor)
    end
end

function SB.MakeSeparator(panel)
    local lblSeparator = Line:New {
        parent = panel,
        height = SB.conf.B_HEIGHT + 10,
        width = "100%",
    }
    return lblSeparator
end

function PassToGadget(prefix, tag, data)
    newTable = { tag = tag, data = data }
    local msg = prefix .. "|table" .. table.show(newTable)
    Spring.SendLuaRulesMsg(msg)
end

-- FIXME: This becomes complicated very fast
-- Maybe Field classes should be responsible for providing display instead?
SB.humanExpressionMaxLevel = 3
function SB.humanExpression(data, exprType, dataType, level)
    local success, data = pcall(function()

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
        local action = SB.metaModel.actionTypes[data.typeName]
        local humanName = action.humanName .. " ("
        for i, input in pairs(action.input) do
            humanName = humanName .. SB.humanExpression(data[input.name], "value", nil, level + 1)
            if i ~= #action.input then
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
            Spring.Echo(dataType)
            if dataType == "unitType" then
                local unitDef = UnitDefs[data.value]
                local dataIDStr = "(id=" .. tostring(data.value) .. ")"
                if unitDef then
                    return tostring(unitDef.name) .. " " .. dataIDStr
                else
                    return dataIDStr
                end
            elseif dataType == "featureType" then
                local featureDef = FeatureDefs[data.value]
                local dataIDStr = "(id=" .. tostring(data.value) .. ")"
                if featureDef then
                    return tostring(featureDef.name) .. " " .. dataIDStr
                else
                    return dataIDStr
                end
            elseif dataType == "unit" then
                local unitID = SB.model.unitManager:getSpringUnitID(data.value)
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
                return data.name
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
            else
                return tostring(data.value)
            end
        elseif data.type == "scoped" then
            return data.value
        elseif data.type == "var" then
            return SB.model.variableManager:getVariable(data.value).name
        elseif dataType.typeName then
            Spring.Echo("dataType.typeName", dataType.typeName)
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
        return data
    else
        return "Err." .. tostring(data)
    end
end

function SB.GenerateTeamColor()
    return 1, 1, 1, 1 --yeah, ain't it great
end

function SB.GetTeams(widget)
    local teams = {}

    local gaiaTeamID = Spring.GetGaiaTeamID()
    for _, teamID in pairs(Spring.GetTeamList()) do
        local team = { id = teamID }
        table.insert(teams, team)

        team.name = tostring(team.id)

        local aiID, _, _, name = Spring.GetAIInfo(team.id)
        if aiID ~= nil then
            team.name = team.name .. ": " .. name
            team.ai = true -- TODO: maybe get the exact AI as well?
        end

        local r, g, b, a = SB.GenerateTeamColor()--Spring.GetTeamColor(teamID)
        if widget then
            r, g, b, a = Spring.GetTeamColor(team.id)
            team.color = { r = r, g = g, b = b, a = a }
        end

        local _, _, _, _, side, allyTeam = Spring.GetTeamInfo(team.id)
        team.allyTeam = allyTeam
        team.side = side

        team.gaia = gaiaTeamID == team.id
        if team.gaia then
            team.ai = true
        end

		if not widget then
			local metal, metalMax = Spring.GetTeamResources(team.id, "metal")
			team.metal = metal
			team.metalMax = metalMax

			local energy, energyMax = Spring.GetTeamResources(team.id, "energy")
			team.energy = energy
			team.energyMax = energyMax
		end
    end
    return teams
end

function SB.IsButton(ctrl)
    -- FIXME: checking for control type via .classname will cause skinning issues
    return ctrl.classname == "button" or ctrl.classname == "toggle_button"
end

local function hintCtrlFunction(ctrl, startTime, timeout, color)
    local deltaTime = os.clock() - startTime
    local newColor = SB.deepcopy(color)
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
    timeout = timeout or 1
    color = color or {1, 0, 0, 1}
    local ctrls = editor:GetAllControls()
    local startTime = os.clock()
    for _, ctrl in pairs(ctrls) do
        if ctrl._originalColor == nil then
            -- FIXME: checking for control type via .classname will cause skinning issues
            if ctrl.classname == "label" or ctrl.classname == "checkbox" or ctrl.classname == "editbox" then
                ctrl._originalColor = SB.deepcopy(ctrl.font.color)
            else
                ctrl._originalColor = SB.deepcopy(ctrl.backgroundColor)
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

function SB.deepcopy(t)
    if type(t) ~= 'table' then return t end
    local mt = getmetatable(t)
    local res = {}
    for k,v in pairs(t) do
        if type(v) == 'table' then
            v = SB.deepcopy(v)
        end
        res[k] = v
    end
    setmetatable(res,mt)
    return res
end

function SB.GiveOrderToUnit(unitID, orderType, params)
    Spring.GiveOrderToUnit(unit, CMD.INSERT,
        { -1, orderType, CMD.OPT_SHIFT, unpack(params) }, { "alt" })
end

function SB.createNewPanel(opts)
    local dataTypeName = opts.dataType.type

    local fieldTypeMapping = {
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

    local fieldType = fieldTypeMapping[dataTypeName]

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
        local atomicField = fieldTypeMapping[atomicType]
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
    control.disableChildrenHitTest = not enabled
    control:Invalidate()
    for _, childCtrl in pairs(control.childrenByName) do
        SB.SetControlEnabled(childCtrl, enabled)
    end
end

-- Make window modal in respect to the source control.
-- The source control will not be usable until the window is disposed.
function SB.MakeWindowModal(window, source)
    -- FIXME: Needed?
    while source.classname ~= "window" do
        Log.Warning("SB.MakeWindowModal", "Sent source which isn't a window")
        Log.Warning(debug.traceback())
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
            Log.Warning(feature .. " requires a minimum Spring version of " .. tostring(versionNumber))
            warningsIssued[feature] = true
        end
        return false
    end
    return true
end

function boolToNumber(bool)
    if bool then
        return 1
    else
        return 0
    end
end

function explode(div, str)
  if (div=='') then return false end
  local pos,arr = 0,{}
  -- for each divider found
  for st,sp in function() return string.find(str,div,pos,true) end do
    table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
    pos = sp + 1 -- Jump past current divider
  end
  table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
  return arr
end

-- Checks whether directory is a SpringBoard project
function SB.DirIsProject(path)
    if not (VFS.FileExists(path, VFS.RAW_ONLY) or
            SB.DirExists(path, VFS.RAW_ONLY)) then
        return false
    end

    local modelExists = VFS.FileExists(Path.Join(path, "model.lua"),
        VFS.RAW)
    local heightMapExists = VFS.FileExists(Path.Join(path, "heightmap.data"),
        VFS.RAW)

    return modelExists and heightMapExists
end
