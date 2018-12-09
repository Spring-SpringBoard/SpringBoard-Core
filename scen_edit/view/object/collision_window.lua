SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

CollisionView = Editor:extends{}
CollisionView:Register({
    name = "collisionView",
    tab = "Objects",
    caption = "Collision",
    tooltip = "Edit collision volumes",
    image = SB_IMG_DIR .. "boulder-dash.png",
    no_serialize = true,
})

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
        items = {1, 2, 3},
        captions = {"Cylinder","Box","Sphere"},
        title = "Type:"
    }))
    self:AddField(ChoiceField({
        name = "axis",
        items = {1, 2, 3},
        captions = {"X","Y","Z"},
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
    self:OnSelectionChanged()
    SB.commandManager:addListener(self)
end

function CollisionView:OnSelectionChanged()
    self.selectionChanging = true
    local selection = SB.view.selectionManager:GetSelection()
    local objectID, bridge
    if #selection.unit > 0 then
        objectID = selection.unit[1]
        bridge = unitBridge
    elseif #selection.feature > 0 then
        objectID = selection.feature[1]
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
        self:Set("vType", collision.vType)

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
        self:OnSelectionChanged()
    end
end

function CollisionView:OnStartChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(true))
end

function CollisionView:OnEndChange(name)
    SB.commandManager:execute(SetMultipleCommandModeCommand(false))
end

function CollisionView:OnFieldChange(name, value)
    local vTypeCaption = self.fields["vType"]:GetCaption()
    local axisCaption  = self.fields["axis"]:GetCaption()
    if name == "vType" then
        if vTypeCaption == "Sphere" then
            self:SetInvisibleFields("scaleY", "scaleZ", "axis")
        elseif vTypeCaption == "Cylinder" then
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
    if #selection.unit == 0 and #selection.feature == 0 then
        return
    end

    if vTypeCaption == "Sphere" and (name == "scaleX" or name == "scaleY" or name == "scaleZ") then
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
    if vTypeCaption == "Cylinder" and (name == "scaleX" or name == "scaleY" or name == "scaleZ") then
        if axisCaption == "X" then
            if name == "scaleX" then
                self:Set("scaleZ", value)
            end
            if name == "scaleZ" then
                self:Set("scaleX", value)
            end
        elseif axisCaption == "Y" then
            if name == "scaleX" then
                self:Set("scaleY", value)
            end
            if name == "scaleY" then
                self:Set("scaleX", value)
            end
        elseif axisCaption == "Z" then
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
        value = {
            scaleX                    = self.fields["scaleX"].value,
            scaleY                    = self.fields["scaleY"].value,
            scaleZ                    = self.fields["scaleZ"].value,
            offsetX                   = self.fields["offsetX"].value,
            offsetY                   = self.fields["offsetY"].value,
            offsetZ                   = self.fields["offsetZ"].value,
            vType                     = self.fields["vType"].value,
            axis                      = self.fields["axis"].value,
        }
        name = "collision"
    end

    local commands = {}
    for selType, objectIDs in pairs(selection) do
        if #objectIDs > 0 then
            local bridge = ObjectBridge.GetObjectBridge(selType)
            if bridge.s11n.setFuncs[name] then
                for _, objectID in pairs(objectIDs) do
                    local modelID = bridge.getObjectModelID(objectID)
                    table.insert(commands, SetObjectParamCommand(bridge.name, modelID, name, value))
                end
            end
        end
    end
    local compoundCommand = CompoundCommand(commands)
    SB.commandManager:execute(compoundCommand)
end
