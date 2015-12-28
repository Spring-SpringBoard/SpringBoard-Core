SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "map_editor_view.lua")

CollisionView = MapEditorView:extends{}

function CollisionView:init()
    self:super("init")

    local children = {
        btnClose,
    }

    self:AddBooleanProperty({
        name = "enabled", 
        value = true,
        title = "Enabled:",
        tooltip = "Collision enabled",
    })
    self:AddChoiceProperty({
        name = "vType",
        items = {
            "Cylinder",
            "Box",
            "Sphere",
        },
        title = "Type:"
    })
    self:AddChoiceProperty({
        name = "axis",
        items = {
            "X",
            "Y",
            "Z",
        },
        title = "Axis:"
    })
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
    self:AddControl("scale-sep", {
        Label:New {
            caption = "Scale",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddNumericProperty({
        name = "scaleX", 
        title = "X:",
        tooltip = "Scale (x)",
        value = 1,
        minValue = 0,
        maxValue = 256,
        step = 1,
    })
    self:AddNumericProperty({
        name = "scaleY", 
        title = "Y:",
        tooltip = "Scale (y)",
        value = 1,
        minValue = 0,
        maxValue = 256,
        step = 1,
    })
    self:AddNumericProperty({
        name = "scaleZ", 
        title = "Z:",
        tooltip = "Scale (z)",
        value = 1,
        minValue = 0,
        maxValue = 256,
        step = 1,
    })

    self:AddControl("offset-sep", {
        Label:New {
            caption = "Offset",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddNumericProperty({
        name = "offsetX", 
        title = "X:",
        tooltip = "Offset (x)",
        value = 0,
        minValue = -256,
        maxValue = 256,
        step = 1,
    })
    self:AddNumericProperty({
        name = "offsetY", 
        title = "Y:",
        tooltip = "Offset (y)",
        value = 0,
        minValue = -256,
        maxValue = 256,
        step = 1,
    })
    self:AddNumericProperty({
        name = "offsetZ", 
        title = "Z:",
        tooltip = "Offset (z)",
        value = 0,
        minValue = -256,
        maxValue = 256,
        step = 1,
    })
    self:AddControl("rad-height-sep", {
        Label:New {
            caption = "Radius",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddNumericProperty({
        name = "radius", 
        title = "Radius:",
        tooltip = "Radius",
        value = 0,
        minValue = 0,
        maxValue = 256,
        step = 1,
    })
    self:AddNumericProperty({
        name = "height", 
        title = "Height:",
        tooltip = "Height",
        value = 0,
        minValue = 0,
        maxValue = 256,
        step = 1,
    })
    self:AddControl("center-height-sep", {
        Label:New {
            caption = "Center",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddNumericProperty({
        name = "mpx",
        title = "X:",
        tooltip = "Model position (x)",
        value = 1,
        minValue = -128,
        maxValue = 128,
        step = 1,
    })
    self:AddNumericProperty({
        name = "mpy",
        title = "Y:",
        tooltip = "Model position (y)",
        value = 1,
        minValue = -128,
        maxValue = 128,
        step = 1,
    })
    self:AddNumericProperty({
        name = "mpz",
        title = "Z:",
        tooltip = "Model position (z)",
        value = 1,
        minValue = -128,
        maxValue = 128,
        step = 1,
    })
    self:AddControl("ap-height-sep", {
        Label:New {
            caption = "Aim",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddNumericProperty({
        name = "apx",
        title = "X:",
        tooltip = "Aim position (x)",
        value = 1,
        minValue = -128,
        maxValue = 128,
        step = 1,
    })
    self:AddNumericProperty({
        name = "apy",
        title = "Y:",
        tooltip = "Aim position (y)",
        value = 1,
        minValue = -128,
        maxValue = 128,
        step = 1,
    })
    self:AddNumericProperty({
        name = "apz",
        title = "Z:",
        tooltip = "Aim position (z)",
        value = 1,
        minValue = -128,
        maxValue = 128,
        step = 1,
    })
    self:AddControl("blocking-height-sep", {
        Label:New {
            caption = "Blocking",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddBooleanProperty({
        name = "isBlocking", 
        value = true,
        title = "Blocking:",
        tooltip = "Is blocking",
    })
    self:AddBooleanProperty({
        name = "isSolidObjectCollidable", 
        value = true,
        title = "Solid object collidable:",
        tooltip = "Is solid object collidable",
    })
    self:AddBooleanProperty({
        name = "isProjectileCollidable", 
        value = true,
        title = "Projectile collidable:",
        tooltip = "Is projectile collidable",
    })
    self:AddBooleanProperty({
        name = "isRaySegmentCollidable", 
        value = true,
        title = "Ray segment collidable:",
        tooltip = "Is ray segment collidable",
    })
    self:AddBooleanProperty({
        name = "crushable", 
        value = true,
        title = "Crushable:",
        tooltip = "Is crushable",
    })
    self:AddBooleanProperty({
        name = "blockEnemyPushing", 
        value = true,
        title = "Block enemy pushing:",
        tooltip = "Blocks enemy pushing",
    })
    self:AddBooleanProperty({
        name = "blockHeightChanges", 
        value = true,
        title = "Block height changes",
        tooltip = "Blocks height changes",
    })

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
        self.fields["scaleX"].Set(collision.scaleX)
        self.fields["scaleY"].Set(collision.scaleY)
        self.fields["scaleZ"].Set(collision.scaleZ)
        self.fields["offsetX"].Set(collision.offsetX)
        self.fields["offsetY"].Set(collision.offsetY)
        self.fields["offsetZ"].Set(collision.offsetZ)
        self.fields["enabled"].Set(not collision.disabled)
        local name = self.fields["vType"].comboBox.items[collision.vType]
        self.fields["vType"].Set(name)

        local radiusHeight = bridge.s11n:Get(objectID, "radiusHeight")
        self.fields["radius"].Set(radiusHeight.radius)
        self.fields["height"].Set(radiusHeight.height)

        local midAimPos = bridge.s11n:Get(objectID, "midAimPos")
        self.fields["mpx"].Set(midAimPos.mid.x)
        self.fields["mpy"].Set(midAimPos.mid.y)
        self.fields["mpz"].Set(midAimPos.mid.z)
        self.fields["apx"].Set(midAimPos.aim.x)
        self.fields["apy"].Set(midAimPos.aim.y)
        self.fields["apz"].Set(midAimPos.aim.z)

        local blocking = bridge.s11n:Get(objectID, "blocking")
        self.fields["isBlocking"].Set(                   blocking.isBlocking)
        self.fields["isSolidObjectCollidable"].Set(      blocking.isSolidObjectCollidable)
        self.fields["isProjectileCollidable"].Set(       blocking.isProjectileCollidable)
        self.fields["isRaySegmentCollidable"].Set(       blocking.isRaySegmentCollidable)
        self.fields["crushable"].Set(                    blocking.crushable)
        self.fields["blockEnemyPushing"].Set(            blocking.blockEnemyPushing)
        self.fields["blockHeightChanges"].Set(           blocking.blockHeightChanges)
    end
    self.selectionChanging = false
end

function CollisionView:OnFieldChange(name, value)
    local vType = self.fields["vType"].value
    if name == "vType" then
        if vType == "Sphere" then
            self:SetInvisibleFields("scaleY", "scaleZ", "axis")
        elseif vType == "Cylinder" then
            self:SetInvisibleFields("scaleZ")
        else
            self:SetInvisibleFields("axis")
        end
    end
    if not self.selectionChanging then
        if self.fields["vType"].value == "Sphere" and (name == "scaleX" or name == "scaleY" or name == "scaleZ") then
            if name ~= "scaleX" then
                self:SetNumericField("scaleX", value)
            end
            if name ~= "scaleY" then
                self:SetNumericField("scaleY", value)
            end
            if name ~= "scaleZ" then
                self:SetNumericField("scaleZ", value)
            end
        end
        if self.fields["vType"].value == "Cylinder" and (name == "scaleY" or name == "scaleZ") then
            if name ~= "scaleY" then
                self:SetNumericField("scaleY", value)
            end
            if name ~= "scaleZ" then
                self:SetNumericField("scaleZ", value)
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
        local selection = SCEN_EDIT.view.selectionManager:GetSelection()
        for _, objectID in pairs(selection.units) do
            local modelID = SCEN_EDIT.model.unitManager:getModelUnitId(objectID)
            table.insert(commands, SetUnitParamCommand(modelID, name, value))
        end
        for _, objectID in pairs(selection.features) do
            local modelID = SCEN_EDIT.model.featureManager:getModelFeatureId(objectID)
            table.insert(commands, SetFeatureParamCommand(modelID, name, value))
        end

        local compoundCommand = CompoundCommand(commands)
        SCEN_EDIT.commandManager:execute(compoundCommand)
    end
end
