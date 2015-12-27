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
        name = "type",
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
    self:AddControl("aim-height-sep", {
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
        local scaleX, scaleY, scaleZ,
              offsetX, offsetY, offsetZ,
              volumeType, testType, primaryAxis, disabled = bridge.spGetObjectCollisionVolumeData(objectID)
        self:SetNumericField("scaleX", scaleX)
        self:SetNumericField("scaleY", scaleY)
        self:SetNumericField("scaleZ", scaleZ)
        self:SetNumericField("offsetX", offsetX)
        self:SetNumericField("offsetY", offsetY)
        self:SetNumericField("offsetZ", offsetZ)
        self:SetBooleanField("enabled", not disabled)
        local name = self.fields["type"].comboBox.items[volumeType]
        self:SetChoiceField("type", name)

        local radius = bridge.spGetObjectRadius(objectID)
        local height = bridge.spGetObjectHeight(objectID)
        self:SetNumericField("radius", radius)
        self:SetNumericField("height", height)

        local _, _, _, mpx, mpy, mpz, apx, apy, apz = bridge.spGetObjectPosition(objectID)
        self:SetNumericField("mpx", mpx)
        self:SetNumericField("mpy", mpy)
        self:SetNumericField("mpz", mpz)
        self:SetNumericField("apx", apx)
        self:SetNumericField("apy", apy)
        self:SetNumericField("apz", apz)

        local isBlocking, isSolidObjectCollidable, isProjectileCollidable,
              isRaySegmentCollidable, crushable, blockEnemyPushing, blockHeightChanges = bridge.spGetObjectBlocking(objectID)
        self:SetBooleanField("isBlocking",              isBlocking)
        self:SetBooleanField("isSolidObjectCollidable", isSolidObjectCollidable)
        self:SetBooleanField("isProjectileCollidable",  isProjectileCollidable)
        self:SetBooleanField("isRaySegmentCollidable",  isRaySegmentCollidable)
        self:SetBooleanField("crushable",               crushable)
        self:SetBooleanField("blockEnemyPushing",       blockEnemyPushing)
        self:SetBooleanField("blockHeightChanges",      blockHeightChanges)
    end
    self.selectionChanging = false
end

function CollisionView:OnFieldChange(name, value)
    local vType = self.fields["type"].value
    if name == "type" then
        if vType == "Sphere" then
            self:SetInvisibleFields("scaleY", "scaleZ", "axis")
        elseif vType == "Cylinder" then
            self:SetInvisibleFields("scaleZ")
        else
            self:SetInvisibleFields("axis")
        end
    end
    if not self.selectionChanging then
        if self.fields["type"].value == "Sphere" and (name == "scaleX" or name == "scaleY" or name == "scaleZ") then
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
        if self.fields["type"].value == "Cylinder" and (name == "scaleY" or name == "scaleZ") then
            if name ~= "scaleY" then
                self:SetNumericField("scaleY", value)
            end
            if name ~= "scaleZ" then
                self:SetNumericField("scaleZ", value)
            end
        end

        local selection = SCEN_EDIT.view.selectionManager:GetSelection()
        local params = {}
        for _, field in pairs(self.fields) do
            if field.name == "type" then
                for i, value in pairs(self.fields["type"].comboBox.ids) do
                    if value == field.value then
                        params["vType"] = i
                    end
                end
            else
                params[field.name] = field.value
            end
        end
        if not params["enabled"] then
            params["vType"] = -1
        end
        for i, value in pairs(self.fields["axis"].comboBox.ids) do
            if value == self.fields["axis"].value then
                params["axis"] = i
            end
        end
        local midAimParams = {
            mpx = self.fields["mpx"].value,
            mpy = self.fields["mpy"].value,
            mpz = self.fields["mpz"].value,
            apx = self.fields["apx"].value,
            apy = self.fields["apy"].value,
            apz = self.fields["apz"].value,
        }
        local blockingParams = {
            isBlocking                  = self.fields["isBlocking"].value,
            isSolidObjectCollidable     = self.fields["isSolidObjectCollidable"].value,
            isProjectileCollidable      = self.fields["isProjectileCollidable"].value,
            isRaySegmentCollidable      = self.fields["isRaySegmentCollidable"].value,
            crushable                   = self.fields["crushable"].value,
            blockEnemyPushing           = self.fields["blockEnemyPushing"].value,
            blockHeightChanges          = self.fields["blockHeightChanges"].value
        }
        local commands = {}
        for _, objectID in pairs(selection.units) do
            local modelID = SCEN_EDIT.model.unitManager:getModelUnitId(objectID)
            table.insert(commands, SetUnitCollisionVolumeDataCommand(modelID, params))
            table.insert(commands, SetUnitModelRadiusCommand(modelID, self.fields["radius"].value, self.fields["height"].value))
            table.insert(commands, SetUnitMidAimPosCommand(modelID, midAimParams))
            table.insert(commands, SetUnitBlockingCommand(modelID, blockingParams))
        end
        for _, objectID in pairs(selection.features) do
            local modelID = SCEN_EDIT.model.featureManager:getModelFeatureId(objectID)
            table.insert(commands, SetFeatureCollisionVolumeDataCommand(modelID, params))
            table.insert(commands, SetFeatureModelRadiusCommand(modelID, self.fields["radius"].value, self.fields["height"].value))
            table.insert(commands, SetFeatureMidAimPosCommand(modelID, midAimParams))
            table.insert(commands, SetFeatureBlockingCommand(modelID, blockingParams))
        end
        local compoundCommand = CompoundCommand(commands)
        SCEN_EDIT.commandManager:execute(compoundCommand)
    end
end
