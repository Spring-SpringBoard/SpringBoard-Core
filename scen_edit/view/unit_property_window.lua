SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "editor_view.lua")

UnitPropertyWindow = EditorView:extends{}

function UnitPropertyWindow:init()
    self:super("init")
    self.rules = {}
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
            width = 100,
            decimals = 0,
        }),
        NumericField({
            name = "posY",
            title = "Y:",
            tooltip = "Position (y)",
            value = 0,
            step = 1,
            width = 100,
            decimals = 0,
        }),
        NumericField({
            name = "posZ",
            title = "Z:",
            tooltip = "Position (z)",
            value = 1,
            minValue = 0,
            maxValue = Game.mapSizeZ,
            step = 1,
            width = 100,
            decimals = 0,
        }),
        Field({
            name = "btn-stick-ground",
            width = 150,
            components = {
                Button:New {
                    caption = "Stick to ground",
                    x = 0,
                    width = 135,
                    height = 30,
                    OnClick = {
                        function()
                            self:OnFieldChange("movectrl", false)
                            self:OnFieldChange("gravity", 1)
                            local x, z = self.fields["posX"].value, self.fields["posZ"].value
                            self:Set("posY", Spring.GetGroundHeight(x, z))
                        end
                    }
                },
            }
        })
    }))

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
            value = 0,
            step = 0.2,
            width = 100,
        }),
        NumericField({
            name = "angleY",
            title = "Y:",
            tooltip = "Y angle",
            value = 0,
            step = 0.2,
            width = 100,
        }),
        NumericField({
            name = "angleZ",
            title = "Z:",
            tooltip = "Z angle",
            value = 0,
            step = 0.2,
            width = 100,
        }),
    }))
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
    if name == "pos" or name == "dir" or name == "rot" then
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

function UnitPropertyWindow:AddObjectRules(objectID, bridge)
    if #self.rules > 0 then
        self:Remove("rule-sep")
    end
    for _, rule in pairs(self.rules) do
        self:Remove(rule)
    end
    self.rules = {}
    local addedRule = false
    for rule, value in pairs(bridge.s11n:Get(objectID, "rules")) do
        if not addedRule then
            addedRule = true
            self:AddControl("rule-sep", {
                Label:New {
                    caption = "Rules",
                },
                Line:New {
                    x = 50,
                    width = self.VALUE_POS,
                }
            })
        end
        local ruleName = "rule_" .. rule
        if type(value) == "string" then
            self:AddField(StringField({
                name = ruleName,
                title = rule .. ":",
                tooltip = "Rule (" .. rule .. ")",
                value = tostring(value),
            }))
        else
            self:AddField(NumericField({
                name = ruleName,
                title = rule .. ":",
                tooltip = "Rule (" .. rule .. ")",
                value = value,
            }))
        end
        table.insert(self.rules, ruleName)
    end
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
        if bridge == unitBridge then
            self:AddObjectRules(objectID, bridge)
        end
        for _, key in pairs(keys) do
            local value = bridge.s11n:Get(objectID, key)
            self:Set(key, value)
        end
        local pos = bridge.s11n:Get(objectID, "pos")
        self:Set("posX", pos.x)
        self:Set("posY", pos.y)
        self:Set("posZ", pos.z)

        local rot = bridge.s11n:Get(objectID, "rot")
        local dir = bridge.s11n:Get(objectID, "dir")
        self:Set("angleX", math.deg(rot.x))
        self:Set("angleY", math.deg(rot.y))
        self:Set("angleZ", math.deg(rot.z))
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
        if name == "angleX" or name == "angleY" or name == "angleZ" then
            local angleX = math.rad(self.fields["angleX"].value)
            local angleY = math.rad(self.fields["angleY"].value)
            local angleZ = math.rad(self.fields["angleZ"].value)
            value = { x = angleX,
                      y = angleY,
                      z = angleZ }
            name = "rot"
        end
        if name:sub(1, #"rule_") == "rule_" then
            local rule = name:sub(#"rule_"+1)
            name = "rules"
            value = {
                [rule] = value
            }
        end
        -- HACK: needs cleanup
        if self:IsUnitKey(name) or name == "gravity" or name == "movectrl" or name == "rules" then
            for _, command in pairs(self:GetCommands(selection.units, name, value, unitBridge)) do
                table.insert(commands, command)
            end
        end
        if self:IsFeatureKey(name) then
            for _, command in pairs(self:GetCommands(selection.features, name, value, featureBridge)) do
                table.insert(commands, command)
            end
        end
        local compoundCommand = CompoundCommand(commands)
        SCEN_EDIT.commandManager:execute(compoundCommand)
    end
end

function UnitPropertyWindow:GetCommands(objectIDs, name, value, bridge)
    local commands = {}
    for _, objectID in pairs(objectIDs) do
        local modelID = bridge.getObjectModelID(objectID)
        table.insert(commands, bridge.SetObjectParamCommand(modelID, name, value))
        if name == "pos" and bridge == unitBridge then
            table.insert(commands, bridge.SetObjectParamCommand(modelID, "movectrl", true))
            table.insert(commands, bridge.SetObjectParamCommand(modelID, "gravity", 0))
        end
    end
    return commands
end