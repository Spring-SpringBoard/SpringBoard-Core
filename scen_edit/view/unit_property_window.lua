SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "editor_view.lua")

UnitPropertyWindow = EditorView:extends{}

gravity = 1
function UnitPropertyWindow:init()
    self:super("init")
    self.objectKeys = { "health" }
    self.unitKeys = {"tooltip", "maxHealth", "stockpile", "experience", "fuel"}

    self:AddControl("pos-sep", {
        Label:New {
            caption = "Position",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "posX",
            title = "X:",
            tooltip = "Position (x)",
            value = 1,
            minValue = 0,
            maxValue = Game.mapSizeX,
            step = 1,
            width = 150,
        }),
        NumericField({
            name = "posY",
            title = "Y:",
            tooltip = "Position (y)",
            value = 0,
            step = 1,
            width = 150,
        }),
        NumericField({
            name = "posZ",
            title = "Z:",
            tooltip = "Position (z)",
            value = 1,
            minValue = 0,
            maxValue = Game.mapSizeZ,
            step = 1,
            width = 150,
        })
    }))
    self:AddControl("btn-stick-ground", {
        Button:New {
            caption = "Stick to ground",
            width = 200,
            height = 30,
            OnClick = {
                function()
                    gravity = 1 - gravity
                    if gravity == 0 then
                        self:OnFieldChange("movectrl", true)
                    else
                        self:OnFieldChange("movectrl", false)
                    end
                    self:OnFieldChange("gravity", gravity)
                end
            }
        },
    })

    self:AddControl("angle-sep", {
        Label:New {
            caption = "Angle",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "angleX",
            title = "X:",
            tooltip = "X angle",
            value = 1,
            minValue = -180,
            maxValue = 180,
            step = 1,
            width = 225,
        }),
        NumericField({
            name = "angleY",
            title = "Y:",
            tooltip = "Y angle",
            value = 0,
            minValue = -180,
            maxValue = 180,
            step = 1,
            width = 225,
        }),
    }))
--     self:AddNumericProperty({
--         name = "angleZ",
--         title = "Z:",
--         tooltip = "Z angle",
--         value = 0,
--         minValue = -180,
--         maxValue = 180,
--         step = 1,
--     })
    self:AddField(GroupField({
        NumericField({
            name = "health",
            title = "Health:",
            tooltip = "Health",
            minValue = 1,
            value = 1,
            step = 10,
            width = 225,
        }),
        NumericField({
            name = "maxHealth",
            title = "Max health:",
            tooltip = "Max health",
            minValue = 1,
            value = 1,
            step = 10,
            width = 225,
        })
    }))

    self:AddField(StringField({
        name = "tooltip",
        title = "Tooltip:",
        tooltip = "Tooltip",
        value = "",
    }))

    self:AddField(NumericField({
        name = "stockpile",
        title = "Stockpile:",
        tooltip = "Stockpile",
        minValue = 0,
        value = 1,
        step = 1,
    }))

    self:AddField(NumericField({
        name = "experience",
        title = "Experience:",
        tooltip = "Experience",
        minValue = 0,
        value = 1,
        step = 0.01,
    }))

    self:AddField(NumericField({
        name = "fuel",
        title = "Fuel:",
        tooltip = "Fuel",
        minValue = 0,
        value = 1,
        step = 1,
    }))

    self.rules = {}
    self.ruleEditBoxes = {}
--     for _, foo in pairs(Spring.GetUnitRulesParams(self.unitId)) do
--         if type(foo) == "table" then
--             for rule, value in pairs(foo) do
--                 self.rules[rule] = value
--                 local stackPanel = MakeComponentPanel(mainPanel)
--                 local lblRule = Label:New {
--                     caption = rule .. ":",
--                     width = 100,
--                     x = 1,
--                     parent = stackPanel,
--                 }
--                 self.ruleEditBoxes[rule] = EditBox:New {
--                     text = tostring(value),
--                     x = 110,
--                     width = 100,
--                     height = SCEN_EDIT.conf.B_HEIGHT,
--                     parent = stackPanel,
--                 }
--             end
--         end
--     end


--     SCEN_EDIT.MakeConfirmButton(self.window, btnOk)
--     table.insert(self.window.OnConfirm, function()
-- 
--         for rule, value in pairs(self.rules) do
--             local v = self.ruleEditBoxes[rule].text
--             if type(value) == "number" then
--                 v = tonumber(v)
--             end
--             table.insert(cmds, SetUnitPropertyCommand(self.modelUnitId, "rule", {rule, v}))
--         end
-- 
--         local compoundCommand = CompoundCommand(cmds)
--         SCEN_EDIT.commandManager:execute(compoundCommand)
--     end)

    local children = {
        btnClose,
    }

    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = "0%",
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )

    self:Finalize(children)
    SCEN_EDIT.view.selectionManager:addListener(self)
    self:OnSelectionChanged(SCEN_EDIT.view.selectionManager:GetSelection())
end

function UnitPropertyWindow:CommandExecuted()
    if not self._startedChanging then
        self:OnSelectionChanged(SCEN_EDIT.view.selectionManager:GetSelection())
    end
end

function UnitPropertyWindow:OnStartChange(name)
    SCEN_EDIT.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function UnitPropertyWindow:OnEndChange(name)
    SCEN_EDIT.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function UnitPropertyWindow:IsObjectKey(name)
    for _, key in pairs(self.objectKeys) do
        if key == name then
            return true
        end
    end
    if name == "pos" or name == "dir" then
        return true
    end
    return false
end

function UnitPropertyWindow:IsFeatureKey(name)
    if self:IsObjectKey(name) then
        return true
    end
    return false
end

function UnitPropertyWindow:IsUnitKey(name)
    if self:IsObjectKey(name) then
        return true
    end
    for _, key in pairs(self.unitKeys) do
        if key == name then
            return true
        end
    end
    return false
end

function UnitPropertyWindow:OnSelectionChanged(selection)
    self.selectionChanging = true
    local objectID, bridge
    local keys
    if #selection.units > 0 then
        objectID = selection.units[1]
        bridge = unitBridge
        keys = SCEN_EDIT.deepcopy(self.unitKeys)
        for _, value in pairs(self.objectKeys) do
            table.insert(keys, value)
        end
        self:SetInvisibleFields()
    elseif #selection.features > 0 then
        objectID = selection.features[1]
        bridge = featureBridge
        keys = self.objectKeys
        self:SetInvisibleFields(unpack(self.unitKeys))
    end
    if objectID then
        for _, key in pairs(keys) do
            local value = bridge.s11n:Get(objectID, key)
            self:Set(key, value)
        end
        local pos = bridge.s11n:Get(objectID, "pos")
        self:Set("posX", pos.x)
        self:Set("posY", pos.y)
        self:Set("posZ", pos.z)
        local dir = bridge.s11n:Get(objectID, "dir")
        local dirX, dirY, dirZ = bridge.spGetObjectDirection(objectID)

        local angleY = math.asin(dirZ)
        local angleX = math.acos(dirX / math.cos(angleY))
        self:Set("angleX", math.deg(angleX))
        self:Set("angleY", math.deg(angleY))
    end
    self.selectionChanging = false
end

function UnitPropertyWindow:OnFieldChange(name, value)
    if not self.selectionChanging then
        local selection = SCEN_EDIT.view.selectionManager:GetSelection()
        local commands = {}
        if name == "posX" or name == "posY" or name == "posZ" then
            value = { x = self.fields["posX"].value,
                      y = self.fields["posY"].value,
                      z = self.fields["posZ"].value }
            name = "pos"
        end
        if name == "angleX" or name == "angleY" then
            local angleX = math.rad(self.fields["angleX"].value)
            local angleY = math.rad(self.fields["angleY"].value)
            value = { x = math.cos(angleX)*math.cos(angleY),
                      y = math.sin(angleX)*math.cos(angleY),
                      z = math.sin(angleY) }
            name = "dir"
        end
        if self:IsUnitKey(name) or name == "gravity" or name == "movectrl" then
            for _, objectID in pairs(selection.units) do
                local modelID = SCEN_EDIT.model.unitManager:getModelUnitId(objectID)
                table.insert(commands, SetUnitParamCommand(modelID, name, value))
            end
        end
        if self:IsFeatureKey(name) then
            for _, objectID in pairs(selection.features) do
                local modelID = SCEN_EDIT.model.featureManager:getModelFeatureId(objectID)
                table.insert(commands, SetFeatureParamCommand(modelID, name, value))
            end
        end
        local compoundCommand = CompoundCommand(commands)
        SCEN_EDIT.commandManager:execute(compoundCommand)
    end
end