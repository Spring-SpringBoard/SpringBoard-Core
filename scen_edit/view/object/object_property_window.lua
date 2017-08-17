SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

ObjectPropertyWindow = Editor:extends{}
Editor.Register({
    name = "objectPropertyWindow",
    editor = ObjectPropertyWindow,
    tab = "Objects",
    caption = "Properties",
    tooltip = "Edit object properties",
    image = SB_IMG_DIR .. "anatomy.png",
    order = 2,
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
            value = true,
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
            name = "rotX",
            title = "X:",
            tooltip = "X angle",
            value = 0,
            step = 0.2,
            width = 100,
        }),
        NumericField({
            name = "rotY",
            title = "Y:",
            tooltip = "Y angle",
            value = 0,
            step = 0.2,
            width = 100,
        }),
        NumericField({
            name = "rotZ",
            title = "Z:",
            tooltip = "Z angle",
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
                            local x, z = self.fields["posX"].value, self.fields["posZ"].value
                            local dirX, dirY, dirZ = Spring.GetGroundNormal(x, z)
                            local frontDir = bridge.s11n:Get(objectID, "dir")
                            local upDir =    {x=dirX,  y=dirY,  z=dirZ}
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
end

function ObjectPropertyWindow:AddTeamField()
    local teamIDs = GetField(SB.model.teamManager:getAllTeams(), "id")
    for i = 1, #teamIDs do
        teamIDs[i] = tostring(teamIDs[i])
    end
    local teamCaptions = GetField(SB.model.teamManager:getAllTeams(), "name")
    self:AddField(ChoiceField({
        name = "team",
        items = teamIDs,
        captions = teamCaptions,
        title = "Team: ",
    }))
end

function ObjectPropertyWindow:AddS11NField(v)
    local name = v.name
    local s11nField = v.field
    local humanName = s11nField.humanName or name
    local dtype = s11nField.dtype

    --Spring.Echo("AddS11NField(s11nField)", name, dtype)
    if name == "pos" then
        self:AddPosField()
    elseif name == "rot" then
        self:AddAngleField()
    elseif name == "state" then
        self:AddStateField()
    elseif name == "team" then
        self:AddTeamField()
    else
        if dtype == "float" then
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
        elseif dtype == "xyz" then
            self:AddControl(name .. "-sep", {
                Label:New {
                    caption = humanName,
                },
                Line:New {
                    x = 50,
                    width = self.VALUE_POS,
                }
            })
            self:AddField(GroupField({
                NumericField({
                    name = name .. "X",
                    title = "X:",
                    tooltip = humanName .. " (x)",
                    value = 1,
                    step = 1,
                    width = 100,
                }),
                NumericField({
                    name = name .. "Y",
                    title = "Y:",
                    tooltip = humanName .. " (y)",
                    value = 0,
                    step = 1,
                    width = 100,
                }),
                NumericField({
                    name = name .. "Z",
                    title = "Z:",
                    tooltip = humanName .. " (z)",
                    value = 1,
                    step = 1,
                    width = 100,
                }),
            }))
        else
            Spring.Echo("unknown type")
            Spring.Echo(name, dtype)
        end
    end
end

function ObjectPropertyWindow:init()
    self:super("init")
    self.rules = {}

--     self:AddControl("health-sep", {
--         Label:New {
--             caption = "Health",
--         },
--         Line:New {
--             x = 50,
--             width = self.VALUE_POS,
--         }
--     })
--     self:AddField(GroupField({
--         NumericField({
--             name = "health",
--             title = "Health:",
--             tooltip = "Health",
--             minValue = 1,
--             value = 1,
--             step = 10,
--             width = 160,
--         }),
--         NumericField({
--             name = "maxHealth",
--             title = "Max:",
--             tooltip = "Max health",
--             minValue = 1,
--             value = 1,
--             step = 10,
--             width = 160,
--         })
--     }))
--     self:AddField(GroupField({
--         NumericField({
--             name = "capture",
--             title = "Capture:",
--             tooltip = "Capture",
--             minValue = 0,
--             maxValue = 1,
--             value = 1,
--             step = 0.001,
--             width = 160,
--         }),
--         NumericField({
--             name = "build",
--             title = "Build:",
--             tooltip = "Build health",
--             minValue = 0,
--             maxValue = 1,
--             value = 1,
--             step = 0.001,
--             width = 160,
--         }),
-- --         NumericField({
-- --             name = "paralyze",
-- --             title = "Paralyze:",
-- --             tooltip = "Paralyze",
-- --             minValue = 0,
-- --             value = 1,
-- --             step = 10,
-- --             width = 150,
-- --         }),
--     }))
--
--     self:AddField(BooleanField({
--         name = "autoLand",
--         title = "Auto land",
--         tooltip = "Auto land",
--         width = 100,
--     }))
--
--     self:AddTeamField()
--
--     self:AddField(StringField({
--         name = "tooltip",
--         title = "Tooltip:",
--         tooltip = "Tooltip",
--     }))
--
--     self:AddField(NumericField({
--         name = "stockpile",
--         title = "Stockpile:",
--         tooltip = "Stockpile",
--         minValue = 0,
--         value = 1,
--         step = 1,
--     }))
--
--     self:AddField(NumericField({
--         name = "experience",
--         title = "Experience:",
--         tooltip = "Experience",
--         minValue = 0,
--         value = 1,
--         step = 0.01,
--     }))
--
--     self:AddField(BooleanField({
--         name = "neutral",
--         title = "Neutral:",
--         tooltip = "Neutral",
--         value = false,
--     }))
--
--     self:AddField(NumericField({
--         name = "fuel",
--         title = "Fuel:",
--         tooltip = "Fuel",
--         minValue = 0,
--         value = 1,
--         step = 1,
--     }))
--
--     self:AddField(NumericField({
--         name = "maxRange",
--         title = "Max range:",
--         tooltip = "Max unit engagement range",
--         minValue = 0,
--         value = 1,
--         step = 1,
--     }))
--
--     self:AddControl("metal-sep", {
--         Label:New {
--             caption = "Metal",
--         },
--         Line:New {
--             x = 50,
--             width = self.VALUE_POS,
--         }
--     })
--     self:AddField(GroupField({
--         NumericField({
--             name = "metalMake",
--             title = "Make:",
--             tooltip = "Metal make",
--             value = 0,
--             step = 0.2,
--             width = 200,
--         }),
--         NumericField({
--             name = "metalUse",
--             title = "Use:",
--             tooltip = "Metal use",
--             value = 0,
--             step = 0.2,
--             width = 200,
--         }),
--     }))
--     self:AddControl("energy-sep", {
--         Label:New {
--             caption = "Energy",
--         },
--         Line:New {
--             x = 50,
--             width = self.VALUE_POS,
--         }
--     })
--     self:AddField(GroupField({
--         NumericField({
--             name = "energyMake",
--             title = "Make:",
--             tooltip = "Energy make",
--             value = 0,
--             step = 0.2,
--             width = 200,
--         }),
--         NumericField({
--             name = "energyUse",
--             title = "Use:",
--             tooltip = "Energy use",
--             value = 0,
--             step = 0.2,
--             width = 200,
--         }),
--     }))
--     self:AddControl("energy-end", {
--         Line:New {
--             x = 50,
--             width = self.VALUE_POS,
--         }
--     })
--
--     self:AddField(NumericField({
--         name = "harvestStorage",
--         title = "Harvest storage:",
--         tooltip = "Harvest storage (metal)",
--         minValue = 0,
--         value = 1,
--         step = 1,
--     }))

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

    self.objectTypeS11NFields = {}
    self.__blockedFields = {
        "dir", "defName", "collision", "blocking", "radiusHeight", "midAimPos",
        "maxHealth", "paralyze"
    }
    for objType, bridge in pairs(ObjectBridge.GetObjectBridges()) do
        local s11nFields = {}
        self.objectTypeS11NFields[objType] = s11nFields
        if bridge.s11n then
            local s11nFieldOrder = bridge.s11nFieldOrder or {}
            for _, name in pairs(s11nFieldOrder) do
                local f = bridge.s11n.funcs[name]
                if f then
                    table.insert(s11nFields, {
                        name = name,
                        field = f
                    })
                end
            end
            for name, f in pairs(bridge.s11n.funcs) do
                if not Table.Contains(self.__blockedFields, name) and
                   not Table.Contains(s11nFieldOrder, name) then
                       table.insert(s11nFields, {
                           name = name,
                           field = f
                       })
                end
            end
        end
    end

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
        self:__UpdateFields()
    end
end

function ObjectPropertyWindow:OnStartChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function ObjectPropertyWindow:OnEndChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function ObjectPropertyWindow:AddObjectRules(objectID, bridge)
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
    local selCount = SB.view.selectionManager:GetSelection()
    self.selectionChanging = true

    local objectID, bridge, s11nFields
    for selType, objectIDs in pairs(selection) do
        if #objectIDs > 0 then
            bridge = ObjectBridge.GetObjectBridge(selType)
            s11nFields = self.objectTypeS11NFields[selType]
            objectID = objectIDs[1]
            break
        end
    end

    for name, _ in pairs(self.fields) do
        self:RemoveField(name)
    end

    if not bridge then
        return
    end

    self.bridge = bridge
    self.objectID = objectID
    self.s11nFields = s11nFields
    for _, v in pairs(s11nFields) do
        self:AddS11NField(v)
    end
    -- if self.fields["rule-sep"] then
    --     self:RemoveField("rule-sep")
    -- end
    -- for _, rule in pairs(self.rules) do
    --     self:RemoveField(rule)
    -- end
    self.rules = {}
    if bridge == unitBridge then
        self:AddObjectRules(objectID, bridge)
    end

    self:__UpdateFields()
    self.stackPanel:EnableRealign()
    self:_MEGA_HACK()

    self.selectionChanging = false
end

function ObjectPropertyWindow:__UpdateFields()
    local selCount = SB.view.selectionManager:GetSelectionCount()
    if selCount == 0 then
        return
    end

    local bridge = self.bridge
    local objectID = self.objectID
    local s11nFields = self.s11nFields

    if objectID then
        for _, v in pairs(s11nFields) do
            local s11nField = v.field
            local name = v.name
            -- if key == "fuel" then -- FIXME: fuel is aircraft only
            --     local maxFuel = bridge.ObjectDefs[bridge.spGetObjectDefID(objectID)].maxFuel
            -- end
            if self.fields[name] then
                Spring.Echo(name)
                local value = bridge.s11n:Get(objectID, name)
                self:Set(name, value)
            else
                Spring.Echo("not found", name)
            end
        end
        local pos
        if self.fields["avgPos"].value then
            pos = self:_GetAveragePos()
        else
            pos = bridge.s11n:Get(objectID, "pos")
        end
        self:Set("posX", pos.x)
        self:Set("posY", pos.y)
        self:Set("posZ", pos.z)
        if pos.y ~= Spring.GetGroundHeight(pos.x, pos.z) then
            self:Set("stickToGround", false)
        end

        if self.fields.velX then
            local vel = bridge.s11n:Get(objectID, "vel")
            self:Set("velX", vel.x)
            self:Set("velY", vel.y)
            self:Set("velZ", vel.z)
        end

        if self.fields.rotX then
            local rot = bridge.s11n:Get(objectID, "rot")
            self:Set("rotX", math.deg(rot.x))
            self:Set("rotY", math.deg(rot.y))
            self:Set("rotZ", math.deg(rot.z))
        end

        -- if bridge == unitBridge then
        --     local resources = bridge.s11n:Get(objectID, "resources")
        --     local metalMake, metalUse, energyMake, energyUse =
        --         resources.metalMake, resources.metalUse,
        --         resources.energyMake, resources.energyUse
        --     self:Set("metalMake",  metalMake)
        --     self:Set("metalUse",   metalUse)
        --     self:Set("energyMake", energyMake)
        --     self:Set("energyUse",  energyUse)
        --
        --     local states = bridge.s11n:Get(objectID, "states")
        --     -- FIXME: states should always be available if we use globallos ?
        --     if states then
        --         Log.Debug("ACTIVE", states.active)
        --         self:Set("fireState",       states.fireState)
        --         self:Set("moveState",       states.moveState)
        --         self:Set("repeat",          states["repeat"])
        --         self:Set("cloak",           states.cloak)
        --         self:Set("active",          states.active)
        --         self:Set("trajectory",      states.trajectory)
        --         self:Set("autoLand",        states.autoLand)
        --         self:Set("autoRepairLevel", states.autoRepairLevel)
        --         self:Set("loopbackAttack",  states.loopbackAttack)
        --     end
        -- end
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
        self:OnSelectionChanged()
        return
    end

    if name == "stickToGround" then
        if value then
            self:OnFieldChange("movectrl", false)
            self:OnFieldChange("gravity", 1)
            -- Force refreshing the position
            self:OnFieldChange("posX", self.fields["posX"].value)
        end
        return
    end

    local commands = {}
    if name == "posX" or name == "posY" or name == "posZ" then
        local avg
        if self.fields["avgPos"].value then
            avg = self:_GetAveragePos()
        else
            avg = { x=0, y=0, z=0}
        end

        if name == "posX" then
            value = { x = self.fields["posX"].value - avg.x }
        elseif name == "posY" then
            if self.fields["stickToGround"].value then
                self:Set("stickToGround", false)
            end
            value = { y = self.fields["posY"].value - avg.y }
        elseif name == "posZ" then
            value = { z = self.fields["posZ"].value - avg.z }
        end
        name = "pos"
    end
    if name == "velX" or name == "velY" or name == "velZ" then
        value = { x = self.fields["velX"].value,
                  y = self.fields["velY"].value,
                  z = self.fields["velZ"].value }
        name = "vel"
    end
    if name == "rotX" or name == "rotY" or name == "rotZ" then
        local rotX = math.rad(self.fields["rotX"].value)
        local rotY = math.rad(self.fields["rotY"].value)
        local rotZ = math.rad(self.fields["rotZ"].value)
        value = { x = rotX,
                  y = rotY,
                  z = rotZ }
        name = "rot"
    end
    if name:sub(1, #"rule_") == "rule_" then
        local rule = name:sub(#"rule_"+1)
        name = "rules"
        value = {
            [rule] = value
        }
    end
    if name == "metalMake" or name == "metalUse" or name == "energyMake" or name == "energyUse" then
        name = "resources"
        value = { metalMake  = self.fields["metalMake"].value,
                  metalUse   = self.fields["metalUse"].value,
                  energyMake = self.fields["energyMake"].value,
                  energyUse  = self.fields["energyUse"].value }
    end
    if name == "fireState" or name == "moveState" or name == "repeat" or name == "cloak" or name == "active" or name == "trajectory" or name == "autoLand" or name == "autoRepairLevel" or name == "loopbackAttack" then
        name = "states"
        value = { fireState         = self.fields["fireState"].value,
                  moveState         = self.fields["moveState"].value,
                  ["repeat"]        = self.fields["repeat"].value,
                  cloak             = self.fields["cloak"].value,
                  active            = self.fields["active"].value,
                  trajectory        = self.fields["trajectory"].value,
                  autoLand          = self.fields["autoLand"].value,
                  autoRepairLevel   = self.fields["autoRepairLevel"].value,
                  loopbackAttack    = self.fields["loopbackAttack"].value,
        }
    end
    for selType, objectIDs in pairs(selection) do
        if #objectIDs > 0 then
            local keys = GetField(self.objectTypeS11NFields[selType], "name")
            bridge = ObjectBridge.GetObjectBridge(selType)
            if Table.Contains(keys, name) then
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
            table.insert(commands, bridge.SetObjectParamCommand(modelID, name, value))
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
            table.insert(commands, bridge.SetObjectParamCommand(modelID, name, pos))
            if bridge == unitBridge then
                table.insert(commands, bridge.SetObjectParamCommand(modelID, "movectrl", true))
                table.insert(commands, bridge.SetObjectParamCommand(modelID, "gravity", 0))
            elseif bridge == featureBridge then
                --table.insert(commands, bridge.SetObjectParamCommand(modelID, "lockPos", false))
            end
        end
    end
    return commands
end
