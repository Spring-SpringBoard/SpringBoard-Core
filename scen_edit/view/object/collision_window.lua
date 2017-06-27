SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

CollisionView = Editor:extends{}

function CollisionView:init()
    self:super("init")

    local children = {}

    self:AddControl("btn-show-vol", {
        Button:New {
            caption = "Show volume",
            width = 200,
            height = 40,
            OnClick = {
                function()
                    Spring.SendCommands('debugcolvol')
                end
            }
        },
    })
--     self:AddField(BooleanField({
--         name = "enabled",
--         value = true,
--         title = "Enabled:",
--         tooltip = "Collision enabled",
--     }))
    self:AddField(ChoiceField({
        name = "vType",
        items = {
            "Cylinder",
            "Box",
            "Sphere",
        },
        title = "Type:"
    }))
    self:AddField(ChoiceField({
        name = "axis",
        items = {
            "X",
            "Y",
            "Z",
        },
        title = "Axis:"
    }))
    self:AddControl("scale-sep", {
        Label:New {
            caption = "Scale",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "scaleX",
            title = "X:",
            tooltip = "Scale (x)",
            minValue = 0,
            value = 1,
            step = 1,
            width = 150,
        }),
        NumericField({
            name = "scaleY",
            title = "Y:",
            tooltip = "Scale (y)",
            minValue = 0,
            value = 1,
            step = 1,
            width = 150,
        }),
        NumericField({
            name = "scaleZ",
            title = "Z:",
            tooltip = "Scale (z)",
            minValue = 0,
            value = 1,
            step = 1,
            width = 150,
        })
    }))

    self:AddControl("offset-sep", {
        Label:New {
            caption = "Offset",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "offsetX",
            title = "X:",
            tooltip = "Offset (x)",
            value = 0,
            step = 1,
            width = 150,
        }),
        NumericField({
            name = "offsetY",
            title = "Y:",
            tooltip = "Offset (y)",
            value = 0,
            step = 1,
            width = 150,
        }),
        NumericField({
            name = "offsetZ",
            title = "Z:",
            tooltip = "Offset (z)",
            value = 0,
            step = 1,
            width = 150,
        }),
    }))
    self:AddControl("rad-height-sep", {
        Label:New {
            caption = "Radius",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "radius",
            title = "Radius:",
            tooltip = "Radius",
            value = 0,
            minValue = 0,
            step = 1,
            width = 225,
        }),
        NumericField({
            name = "height",
            title = "Height:",
            tooltip = "Height",
            value = 0,
            minValue = 0,
            maxValue = 256,
            step = 1,
            width = 225,
        })
    }))
    self:AddControl("center-height-sep", {
        Label:New {
            caption = "Center",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "mpx",
            title = "X:",
            tooltip = "Model position (x)",
            value = 1,
            step = 1,
            width = 150,
        }),
        NumericField({
            name = "mpy",
            title = "Y:",
            tooltip = "Model position (y)",
            value = 1,
            step = 1,
            width = 150,
        }),
        NumericField({
            name = "mpz",
            title = "Z:",
            tooltip = "Model position (z)",
            value = 1,
            step = 1,
            width = 150,
        })
    }))
    self:AddControl("ap-height-sep", {
        Label:New {
            caption = "Aim",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        NumericField({
            name = "apx",
            title = "X:",
            tooltip = "Aim position (x)",
            value = 1,
            step = 1,
            width = 150,
        }),
        NumericField({
            name = "apy",
            title = "Y:",
            tooltip = "Aim position (y)",
            value = 1,
            step = 1,
            width = 150,
        }),
        NumericField({
            name = "apz",
            title = "Z:",
            tooltip = "Aim position (z)",
            value = 1,
            step = 1,
            width = 150,
        })
    }))
    self:AddControl("blocking-height-sep", {
        Label:New {
            caption = "Blocking",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddField(BooleanField({
        name = "isBlocking",
        value = true,
        title = "Blocking:",
        tooltip = "Is blocking",
    }))
    self:AddField(BooleanField({
        name = "isSolidObjectCollidable",
        value = true,
        title = "Solid object collidable:",
        tooltip = "Is solid object collidable",
    }))
    self:AddField(BooleanField({
        name = "isProjectileCollidable",
        value = true,
        title = "Projectile collidable:",
        tooltip = "Is projectile collidable",
    }))
    self:AddField(BooleanField({
        name = "isRaySegmentCollidable",
        value = true,
        title = "Ray segment collidable:",
        tooltip = "Is ray segment collidable",
    }))
    self:AddField(BooleanField({
        name = "crushable",
        value = true,
        title = "Crushable:",
        tooltip = "Is crushable",
    }))
    self:AddField(BooleanField({
        name = "blockEnemyPushing",
        value = true,
        title = "Block enemy pushing:",
        tooltip = "Blocks enemy pushing",
    }))
    self:AddField(BooleanField({
        name = "blockHeightChanges",
        value = true,
        title = "Block height changes",
        tooltip = "Blocks height changes",
    }))

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
    self:OnSelectionChanged(SB.view.selectionManager:GetSelection())
    SB.commandManager:addListener(self)
end

function CollisionView:OnSelectionChanged(selection)
    self.selectionChanging = true
    local objectID, bridge
    if #selection.units > 0 then
        objectID = selection.units[1]
        bridge = unitBridge
    elseif #selection.features > 0 then
        objectID = selection.features[1]
        bridge = featureBridge
    end
    if objectID then
        local collision = bridge.s11n:Get(objectID, "collision")
        self:Set("scaleX",  collision.scaleX)
        self:Set("scaleY",  collision.scaleY)
        self:Set("scaleZ",  collision.scaleZ)
        self:Set("offsetX", collision.offsetX)
        self:Set("offsetY", collision.offsetY)
        self:Set("offsetZ", collision.offsetZ)
--         self:Set("enabled", not collision.disabled)
        local name = self.fields["vType"].comboBox.items[collision.vType]
        self:Set("vType", name)

        local radiusHeight = bridge.s11n:Get(objectID, "radiusHeight")
        self:Set("radius", radiusHeight.radius)
        self:Set("height", radiusHeight.height)

        local midAimPos = bridge.s11n:Get(objectID, "midAimPos")
        self:Set("mpx", midAimPos.mid.x)
        self:Set("mpy", midAimPos.mid.y)
        self:Set("mpz", midAimPos.mid.z)
        self:Set("apx", midAimPos.aim.x)
        self:Set("apy", midAimPos.aim.y)
        self:Set("apz", midAimPos.aim.z)

        local blocking = bridge.s11n:Get(objectID, "blocking")
        self:Set("isBlocking",                    blocking.isBlocking)
        self:Set("isSolidObjectCollidable",       blocking.isSolidObjectCollidable)
        self:Set("isProjectileCollidable",        blocking.isProjectileCollidable)
        self:Set("isRaySegmentCollidable",        blocking.isRaySegmentCollidable)
        self:Set("crushable",                     blocking.crushable)
        self:Set("blockEnemyPushing",             blocking.blockEnemyPushing)
        self:Set("blockHeightChanges",            blocking.blockHeightChanges)
    end
    self.selectionChanging = false
end

function CollisionView:OnCommandExecuted()
    if not self._startedChanging then
        self:OnSelectionChanged(SB.view.selectionManager:GetSelection())
    end
end

function CollisionView:OnStartChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function CollisionView:OnEndChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function CollisionView:OnFieldChange(name, value)
    local vType = self.fields["vType"].value
    local axis  = self.fields["axis"].value
    if name == "vType" then
        if vType == "Sphere" then
            self:SetInvisibleFields("scaleY", "scaleZ", "axis")
        elseif vType == "Cylinder" then
            self:SetInvisibleFields()
--             self:SetInvisibleFields("scaleZ")
        else
            self:SetInvisibleFields("axis")
        end
    end

    if self.selectionChanging then
        return
    end

    local selection = SB.view.selectionManager:GetSelection()
    if #selection.units == 0 and #selection.features == 0 then
        return
    end

    if vType == "Sphere" and (name == "scaleX" or name == "scaleY" or name == "scaleZ") then
        if name ~= "scaleX" then
            self:Set("scaleX", value)
        end
        if name ~= "scaleY" then
            self:Set("scaleY", value)
        end
        if name ~= "scaleZ" then
            self:Set("scaleZ", value)
        end
    end
    if vType == "Cylinder" and (name == "scaleX" or name == "scaleY" or name == "scaleZ") then
        if axis == "X" then
            if name == "scaleX" then
                self:Set("scaleZ", value)
            end
            if name == "scaleZ" then
                self:Set("scaleX", value)
            end
        elseif axis == "Y" then
            if name == "scaleX" then
                self:Set("scaleY", value)
            end
            if name == "scaleY" then
                self:Set("scaleX", value)
            end
        elseif axis == "Z" then
            if name == "scaleY" then
                self:Set("scaleZ", value)
            end
            if name == "scaleZ" then
                self:Set("scaleY", value)
            end
        end
    end

    if name == "mpx" or name == "mpy" or name == "mpz" or
            name == "apx" or name == "apy" or name == "apz" then
        value = { mid = {
                    x = self.fields["mpx"].value,
                    y = self.fields["mpy"].value,
                    z = self.fields["mpz"].value },
                  aim = {
                    x = self.fields["apx"].value,
                    y = self.fields["apy"].value,
                    z = self.fields["apz"].value },
                  }
        name = "midAimPos"
    elseif name == "isBlocking" or name == "isSolidObjectCollidable" or
            name == "isProjectileCollidable" or name == "isRaySegmentCollidable" or
            name == "crushable" or name == "blockEnemyPushing" or
            name == "blockHeightChanges" then
        value = {
            isBlocking                  = self.fields["isBlocking"].value,
            isSolidObjectCollidable     = self.fields["isSolidObjectCollidable"].value,
            isProjectileCollidable      = self.fields["isProjectileCollidable"].value,
            isRaySegmentCollidable      = self.fields["isRaySegmentCollidable"].value,
            crushable                   = self.fields["crushable"].value,
            blockEnemyPushing           = self.fields["blockEnemyPushing"].value,
            blockHeightChanges          = self.fields["blockHeightChanges"].value
        }
        name = "blocking"
    elseif name == "radius" or name == "height" then
        value = {
            radius = self.fields["radius"].value,
            height = self.fields["height"].value
        }
        name = "radiusHeight"
    elseif name == "scaleX" or name == "scaleY" or name == "scaleZ" or
           name == "offsetX" or name == "offsetY" or name == "offsetZ" or
           name == "vType" or name == "testType" or name == "axis" or
           name == "disabled" then
        local vType, axis
        for i, value in pairs(self.fields["vType"].comboBox.ids) do
            if value == self.fields["vType"].value then
                vType = i
            end
        end
        for i, value in pairs(self.fields["axis"].comboBox.ids) do
            if value == self.fields["axis"].value then
                axis = i
            end
        end
        value = {
            scaleX                    = self.fields["scaleX"].value,
            scaleY                    = self.fields["scaleY"].value,
            scaleZ                    = self.fields["scaleZ"].value,
            offsetX                   = self.fields["offsetX"].value,
            offsetY                   = self.fields["offsetY"].value,
            offsetZ                   = self.fields["offsetZ"].value,
            vType                     = vType,
            axis                      = axis,
        }
        name = "collision"
    end
    local commands = {}
    for _, objectID in pairs(selection.units) do
        local modelID = SB.model.unitManager:getModelUnitID(objectID)
        table.insert(commands, SetUnitParamCommand(modelID, name, value))
    end
    for _, objectID in pairs(selection.features) do
        local modelID = SB.model.featureManager:getModelFeatureID(objectID)
        table.insert(commands, SetFeatureParamCommand(modelID, name, value))
    end

    local compoundCommand = CompoundCommand(commands)
    SB.commandManager:execute(compoundCommand)
end
