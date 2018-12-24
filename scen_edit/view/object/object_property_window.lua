SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

ObjectPropertyWindow = Editor:extends{}
ObjectPropertyWindow:Register({
    name = "objectPropertyWindow",
    tab = "Objects",
    caption = "Properties",
    tooltip = "Edit object properties",
    image = SB_IMG_DIR .. "anatomy.png",
    order = 2,
    no_serialize = true,
})

function ObjectPropertyWindow:_GetValue(name)
    return self.bridge.s11n:Get(self.objectID, name)
end

function ObjectPropertyWindow:AddPosField()
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
            name = "posx",
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
            name = "posy",
            title = "Y:",
            tooltip = "Position (y)",
            value = 0,
            step = 1,
            width = 100,
            decimals = 0,
        }),
        NumericField({
            name = "posz",
            title = "Z:",
            tooltip = "Position (z)",
            value = 1,
            minValue = 0,
            maxValue = Game.mapSizeZ,
            step = 1,
            width = 100,
            decimals = 0,
        }),
        BooleanField({
            name = "stickToGround",
            title = "S",
            tooltip = "Stick to ground",
            width = 50,
            value = true,
        }),
        BooleanField({
            name = "avgPos",
            title = "G",
            tooltip = "Alter the position of the object selection as a group.",
            width = 50,
            value = self.__avgPosValue,
        }),
    }))
end

function ObjectPropertyWindow:AddAngleField()
    self:AddControl("rot-sep", {
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
            name = "rotx",
            title = "X:",
            tooltip = "Angle (x)",
            value = 0,
            step = 0.2,
            width = 100,
        }),
        NumericField({
            name = "roty",
            title = "Y:",
            tooltip = "Angle (y)",
            value = 0,
            step = 0.2,
            width = 100,
        }),
        NumericField({
            name = "rotz",
            title = "Z:",
            tooltip = "Angle (z)",
            value = 0,
            step = 0.2,
            width = 100,
        }),
        Field({
            name = "btn-align-ground",
            width = 150,
            components = {
                Button:New {
                    caption = "Align",
                    x = 0,
                    width = 135,
                    height = 30,
                    tooltip = "Align to heightmap",
                    OnClick = {
                        function()
                            local selection = SB.view.selectionManager:GetSelection()
                            local objectID, bridge
                            if #selection.unit > 0 then
                                objectID = selection.unit[1]
                                bridge = unitBridge
                            elseif #selection.feature > 0 then
                                objectID = selection.feature[1]
                                bridge = featureBridge
                            end
                            local x, z = self.fields["posx"].value, self.fields["posz"].value
                            local dirX, dirY, dirZ = Spring.GetGroundNormal(x, z)
                            local frontDir = bridge.s11n:Get(objectID, "dir")
                            local upDir = {x=dirX,  y=dirY,  z=dirZ}
                            local rightDir = CrossProduct(frontDir, upDir)
                            frontDir = CrossProduct(upDir, rightDir)
                            self:OnFieldChange("dir", frontDir)
                            --self:OnFieldChange("dir", {x=1, y=0, z=0})
                        end
                    }
                },
            }
        })
    }))
end

function ObjectPropertyWindow:AddStateField()
    self:AddControl("state-sep", {
        Label:New {
            caption = "State",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        ChoiceField({
            name = "fireState",
            tooltip = "Fire state",
            items = {0, 1, 2},
            captions = {"Hold fire", "Return fire", "Fire at will"},
            width = 100,
        }),
        ChoiceField({
            name = "moveState",
            tooltip = "Move state",
            items = {0, 1, 2},
            captions = {"Hold pos", "Maneuver", "Roam"},
            width = 100,
        }),
        BooleanField({
            name = "active",
            title = "Active",
            tooltip = "Active/passive unit",
            width = 100,
        }),
        BooleanField({
            name = "repeat",
            title = "Repeat",
            tooltip = "Should the unit repeat orders",
            width = 100,
        }),
    }))
    self:AddField(GroupField({
        BooleanField({
            name = "cloak",
            title = "Cloak",
            tooltip = "Cloak state",
            width = 100,
        }),
        BooleanField({
            name = "trajectory",
            title = "Trajectory",
            tooltip = "Shoot using a trajectory",
            width = 100,
        }),
        BooleanField({
            name = "autoRepairLevel",
            title = "Auto repair",
            tooltip = "Auto repair level",
            width = 100,
        }),
        BooleanField({
            name = "loopbackAttack",
            title = "Loopback",
            tooltip = "Loopback attack",
            width = 100,
        }),
    }))

    self:AddField(BooleanField({
        name = "autoLand",
        title = "Auto land",
        tooltip = "Auto land",
        width = 100,
    }))
end

function ObjectPropertyWindow:AddTeamField()
    local teamIDs = Table.GetField(SB.model.teamManager:getAllTeams(), "id")
    for i = 1, #teamIDs do
        teamIDs[i] = tostring(teamIDs[i])
    end
    local teamCaptions = Table.GetField(SB.model.teamManager:getAllTeams(), "name")
    self:AddField(ChoiceField({
        name = "team",
        items = teamIDs,
        captions = teamCaptions,
        title = "Team: ",
    }))
end

function ObjectPropertyWindow:AddS11NField(name, value, s11nField)
    local humanName = s11nField.humanName
    if not humanName then
        humanName = String.Capitalize(name)
    end
    local dtype = type(value)

    if name == "pos" then
        self:AddPosField()
    elseif name == "rot" then
        self:AddAngleField()
    elseif name == "states" then
        self:AddStateField()
    elseif name == "team" then
        self:AddTeamField()
    else
        if dtype == "number" then
            self:AddField(NumericField({
                name = name,
                title = String.Capitalize(name) .. ":",
                minValue = s11nField.minValue,
                maxValue = s11nField.maxValue,
                value = self:_GetValue(name),
                -- step = 1,
            }))
        elseif dtype == "string" then
            self:AddField(StringField({
                name = name,
                title = String.Capitalize(name) .. ":",
                value = self:_GetValue(name),
            }))
        elseif dtype == "boolean" then
            self:AddField(BooleanField({
                name = name,
                title = String.Capitalize(name) .. ":",
                value = self:_GetValue(name),
            }))
        elseif dtype == "table" then
            self:AddControl(name .. "-sep", {
                Label:New {
                    caption = humanName,
                },
                Line:New {
                    x = 50,
                    width = self.VALUE_POS,
                }
            })
            local tkeys = Table.GetKeys(value)
            table.sort(tkeys)
            local fields = {}
            local count = 0
            for _, tkey in pairs(tkeys) do
                tkey = tostring(tkey)
                local opts = {
                    name = name .. tkey,
                    title = String.Capitalize(tkey) .. ":",
                    tooltip = humanName .. " (" .. tkey .. ")",
                    value = value[tkey],
                    width = 140,
                }
                local elType = type(opts.value)
                local field
                if elType == "number" then
                    field = NumericField(opts)
                elseif elType == "string" then
                    field = StringField(opts)
                elseif elType == "boolean" then
                    field = BooleanField(opts)
                end
                self.__keys[name .. tkey] = name
                table.insert(fields, field)
                count = count + 1
                if count == 3 then
                    count = 0
                    self:AddField(GroupField(fields))
                    fields = {}
                end
            end
            if count > 0 then
                self:AddField(GroupField(fields))
            end
        else
            Spring.Echo("unknown type")
            Spring.Echo(name, dtype)
        end
    end
end

function ObjectPropertyWindow:AddObjectFields(bridge, objectID)
    self.__keys = {}
    local objectValues = bridge.s11n:Get(objectID)
    for _, k in pairs(bridge.s11nFieldOrder) do
        local v = objectValues[k]
        if not Table.Contains(bridge.blockedFields, k) and v then
            local s11nField = bridge.s11n.funcs[k]
            self:AddS11NField(k, v, s11nField)
        end
    end
    for k, v in pairs(objectValues) do
        if not Table.Contains(bridge.blockedFields, k) and
           not Table.Contains(bridge.s11nFieldOrder or {}, k) then
            local s11nField = bridge.s11n.funcs[k]
            self:AddS11NField(k, v, s11nField)
        end
    end
    self.rules = {}
    if bridge == unitBridge or bridge == featureBridge then
        self:AddObjectRules(objectID, bridge)
    end
end

function ObjectPropertyWindow:init()
    self:super("init")
    self.__avgPosValue = true

    local children = {}

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
    SB.view.selectionManager:addListener(self)
    self:OnSelectionChanged()
    SB.commandManager:addListener(self)
end

function CrossProduct(u, v)
    return {x = u.y * v.z - u.z * v.x,
            y = u.z * v.x - u.x * v.z,
            z = u.x * v.y - u.y * v.x}
end

function ObjectPropertyWindow:OnCommandExecuted()
    if not self._startedChanging then
        self.selectionChanging = true
        if self.__fullRefresh then
            self:OnSelectionChanged()
            self.__fullRefresh = true
        end
        self:__UpdateFields()
        self.selectionChanging = false
    end
end

function ObjectPropertyWindow:OnStartChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function ObjectPropertyWindow:OnEndChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

NewRuleDialog = Editor:extends{}

function NewRuleDialog:init(objectPropertyWindow)
    self:super("init")

    self.objectPropertyWindow = objectPropertyWindow

    self:AddField(GroupField({
        StringField({
            name = "ruleName",
            title = "Name:",
            width = 140,
        }),
        ChoiceField({
            name = "ruleType",
            title = "Type:",
            width = 200,
            items = {"String", "Number"}
        })
    }))

    local children = {
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
    }

    self:Finalize(children, {
        notMainWindow = true,
        buttons = { "ok", "cancel" },
        width = 400,
        height = 120,
    })
end

function NewRuleDialog:ConfirmDialog()
    local ruleName = self.fields["ruleName"].value
    local ruleType = self.fields["ruleType"].value
    if String.Trim(ruleName) == "" then
        return false
    end
    local value = 0
    if ruleType == "String" then
        value = "empty"
    end
    self.objectPropertyWindow:OnFieldChange("rule_" .. ruleName, value)
    self.objectPropertyWindow.__fullRefresh = true
    return true
end


function ObjectPropertyWindow:AddObjectRules(objectID, bridge)
    self:AddControl("rule-sep", {
        Label:New {
            caption = "Rules",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    for rule, value in pairs(bridge.s11n:Get(objectID, "rules")) do
        local ruleName = "rule_" .. rule
        local fields = {}

        if type(value) == "string" then
            table.insert(fields, StringField({
                name = ruleName,
                title = rule .. ":",
                tooltip = "Rule (" .. rule .. ")",
                value = tostring(value),
            }))
        else
            table.insert(fields, NumericField({
                name = ruleName,
                title = rule .. ":",
                tooltip = "Rule (" .. rule .. ")",
                value = value,
            }))
        end
        table.insert(fields, Field({
            name = "rem_" .. ruleName,
            width = SB.conf.B_HEIGHT,
            components = {
                Button:New {
                    caption = "",
                    width = SB.conf.B_HEIGHT,
                    height = SB.conf.B_HEIGHT,
                    padding = {2, 2, 2, 2},
                    tooltip = "Remove rule",
                    classname = "negative_button",
                    children = {
                        Image:New {
                            file = SB_IMG_DIR .. "cancel.png",
                            height = "100%",
                            width = "100%",
                        },
                    },
                    OnClick = {
                        function()
                            self:OnFieldChange(ruleName, false)
                            self.__fullRefresh = true
                        end
                    }
                },
            }
        }))
        self:AddField(GroupField(fields))
        table.insert(self.rules, ruleName)
    end
    self:AddField(Field({
        name = "btn-add-rule",
        width = 150,
        components = {
            Button:New {
                caption = "Add rule",
                x = 0,
                width = 135,
                height = 30,
                tooltip = "Add unit rule",
                OnClick = {
                    function()
                        NewRuleDialog(self)
                    end
                }
            },
        }
    }))
end

function ObjectPropertyWindow:_GetAveragePos()
    local selection = SB.view.selectionManager:GetSelection()
    local selCount  = SB.view.selectionManager:GetSelectionCount()
    local avg = {x=0, y=0, z=0}
    for selType, selected in pairs(selection) do
        local bridge = ObjectBridge.GetObjectBridge(selType)
        for _, objectID in pairs(selected) do
            local pos = bridge.s11n:Get(objectID, "pos")
            avg.x = avg.x + pos.x
            avg.y = avg.y + pos.y
            avg.z = avg.z + pos.z
        end
    end

    avg.x = avg.x / selCount
    avg.y = avg.y / selCount
    avg.z = avg.z / selCount
    return avg
end

function ObjectPropertyWindow:OnSelectionChanged()
    local selection = SB.view.selectionManager:GetSelection()
    self.selectionChanging = true

    local objectID, bridge
    for selType, objectIDs in pairs(selection) do
        if #objectIDs > 0 then
            bridge = ObjectBridge.GetObjectBridge(selType)
            objectID = objectIDs[1]
            break
        end
    end

    for name, _ in pairs(self.fields) do
        self:RemoveField(name)
    end

    if not bridge then
        self.stackPanel:EnableRealign()
        self.stackPanel:Invalidate()
        return
    end

    self.bridge = bridge
    self.objectID = objectID
    self:AddObjectFields(bridge, objectID)

    self:__UpdateFields()
    self.stackPanel:EnableRealign()
    self.stackPanel:Invalidate()

    self.selectionChanging = false
end

function ObjectPropertyWindow:__UpdateFields()
    local selCount = SB.view.selectionManager:GetSelectionCount()
    if selCount == 0 then
        return
    end

    local bridge = self.bridge
    local objectID = self.objectID

    if not objectID then
        return
    end

    local value = bridge.s11n:Get(objectID)
    for k, v in pairs(value) do
        -- if key == "fuel" then -- FIXME: fuel is aircraft only
        --     local maxFuel = bridge.ObjectDefs[bridge.GetObjectDefID(objectID)].maxFuel
        -- end

        if not Table.Contains(bridge.blockedFields, k) and k ~= "pos" and k ~= "rot" then
            local dtype = type(v)
            if dtype == "table" then
                for _, tkey in pairs(Table.GetKeys(v)) do
                    tkey = tostring(tkey)
                    local name = k .. tkey
                    if self.fields[name] then
                        self:Set(name, v[name])
                    end
                end
            elseif self.fields[k] then
                self:Set(k, v)
            end
        end
    end

    local pos
    if self.fields["avgPos"].value then
        pos = self:_GetAveragePos()
    else
        pos = bridge.s11n:Get(objectID, "pos")
    end
    self:Set("posx", pos.x)
    self:Set("posy", pos.y)
    self:Set("posz", pos.z)
    if pos.y ~= Spring.GetGroundHeight(pos.x, pos.z) then
        self:Set("stickToGround", false)
    end

    if self.fields.rotx then
        local rot = bridge.s11n:Get(objectID, "rot")
        self:Set("rotx", math.deg(rot.x))
        self:Set("roty", math.deg(rot.y))
        self:Set("rotz", math.deg(rot.z))
    end

    if bridge == unitBridge then
        local states = bridge.s11n:Get(objectID, "states")
        -- FIXME: states should always be available if we use globallos ?
        if states then
            Log.Debug("ACTIVE", states.active)
            self:Set("fireState",       states.fireState)
            self:Set("moveState",       states.moveState)
            self:Set("repeat",          states["repeat"])
            self:Set("cloak",           states.cloak)
            self:Set("active",          states.active)
            self:Set("trajectory",      states.trajectory)
            self:Set("autoLand",        states.autoLand)
            self:Set("autoRepairLevel", states.autoRepairLevel)
            self:Set("loopbackAttack",  states.loopbackAttack)
        end
    end
end

function ObjectPropertyWindow:OnFieldChange(name, value)
    if self.selectionChanging then
        return
    end

    local selection = SB.view.selectionManager:GetSelection()
    local selCount = SB.view.selectionManager:GetSelectionCount()
    if selCount == 0 then
        return
    end

    if name == "avgPos" then
        self.__avgPosValue = value
        self:OnSelectionChanged()
        return
    end

    if name == "stickToGround" then
        if value then
            self:OnFieldChange("movectrl", false)
            self:OnFieldChange("gravity", 1)
            -- Force refreshing the position
            self:OnFieldChange("posx", self.fields["posx"].value)
        end
        return
    end

    local commands = {}
    if name == "posx" or name == "posy" or name == "posz" then
        local avg
        if self.fields["avgPos"].value then
            avg = self:_GetAveragePos()
        else
            avg = { x=0, y=0, z=0}
        end

        if name == "posx" then
            value = { x = self.fields["posx"].value - avg.x }
        elseif name == "posy" then
            if self.fields["stickToGround"].value then
                self:Set("stickToGround", false)
            end
            value = { y = self.fields["posy"].value - avg.y }
        elseif name == "posz" then
            value = { z = self.fields["posz"].value - avg.z }
        end
        name = "pos"
    elseif self.__keys[name] then
        name = self.__keys[name]
        local values = self.bridge.s11n:Get(self.objectID, name)
        value = {}
        for tkey, _ in pairs(values) do
            value[tkey] = self.fields[name .. tostring(tkey)].value
        end
    elseif name == "rotx" or name == "roty" or name == "rotz" then
        local rotx = math.rad(self.fields["rotx"].value)
        local roty = math.rad(self.fields["roty"].value)
        local rotz = math.rad(self.fields["rotz"].value)
        value = { x = rotx,
                  y = roty,
                  z = rotz }
        name = "rot"
    elseif name == "fireState" or name == "moveState" or name == "repeat" or name == "cloak" or name == "active" or name == "trajectory" or name == "autoLand" or name == "autoRepairLevel" or name == "loopbackAttack" then
        value = { [name] = self.fields[name].value }
        name = "states"
    elseif name:sub(1, #"rule_") == "rule_" then
        local rule = name:sub(#"rule_"+1)
        name = "rules"
        value = {
            [rule] = value
        }
    end
    for selType, objectIDs in pairs(selection) do
        if #objectIDs > 0 then
            local bridge = ObjectBridge.GetObjectBridge(selType)
            if bridge.s11n.setFuncs[name] then
                local cmds = self:GetCommands(objectIDs, name, value, bridge)
                for _, command in pairs(cmds) do
                    table.insert(commands, command)
                end
            end
        end
    end
    if #commands > 0 then
        local compoundCommand = CompoundCommand(commands)
        SB.commandManager:execute(compoundCommand)
    end
end

function ObjectPropertyWindow:GetCommands(objectIDs, name, value, bridge)
    local commands = {}
    for _, objectID in pairs(objectIDs) do
        local modelID = bridge.getObjectModelID(objectID)
        if name ~= "pos" then
            table.insert(commands, SetObjectParamCommand(bridge.name, modelID, name, value))
        else
            local pos = bridge.s11n:Get(objectID, "pos")
            for coordName, coordValue in pairs(value) do
                if self.fields["avgPos"].value then
                    pos[coordName] = pos[coordName] + coordValue
                else
                    pos[coordName] = coordValue
                end
            end
            if self.fields["stickToGround"].value then
                pos.y = Spring.GetGroundHeight(pos.x, pos.z)
            end
            table.insert(commands, SetObjectParamCommand(bridge.name, modelID, name, pos))
            if bridge == unitBridge then
                table.insert(commands, SetObjectParamCommand(bridge.name, modelID, "movectrl", true))
                table.insert(commands, SetObjectParamCommand(bridge.name, modelID, "gravity", 0))
            -- elseif bridge == featureBridge then
                --table.insert(commands, SetObjectParamCommand(bridge.name, modelID, "lockPos", false))
            end
        end
    end
    return commands
end
