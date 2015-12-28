SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "map_editor_view.lua")

UnitPropertyWindow = MapEditorView:extends{}

function UnitPropertyWindow:init()
    self:super("init")

    self:AddControl("pos-sep", {
        Label:New {
            caption = "Position",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self:AddNumericProperty({
        name = "posX", 
        title = "X:",
        tooltip = "Position (x)",
        value = 1,
        minValue = 0,
        maxValue = Game.mapSizeX,
        step = 1,
    })
    self:AddNumericProperty({
        name = "posY", 
        title = "Y:",
        tooltip = "Position (y)",
        value = 0,
        minValue = -1000,
        maxValue = 1000,
        step = 1,
    })
    self:AddNumericProperty({
        name = "posZ", 
        title = "Z:",
        tooltip = "Position (z)",
        value = 1,
        minValue = 0,
        maxValue = Game.mapSizeZ,
        step = 1,
    })
    self:AddNumericProperty({
        name = "health", 
        title = "Health:",
        tooltip = "Health",
        value = 1,
        minValue = 1,
        maxValue = 10000,
        step = 1,
    })

    self:AddNumericProperty({
        name = "maxHealth", 
        title = "Max health:",
        tooltip = "Max health",
        value = 1,
        minValue = 1,
        maxValue = 10000,
        step = 1,
    })

    self:AddStringProperty({
        name = "tooltip", 
        title = "Tooltip:",
        tooltip = "Tooltip",
        value = "",
    })


    local stockpile --[[= Spring.GetUnitStockpile(self.unitId)]]
    if stockpile ~= nil then
        local stackPanel = MakeComponentPanel(mainPanel)
        local lblStockpile = Label:New {
            caption = "Stockpile:",
            width = 100,
            x = 1,
            parent = stackPanel,
        }  
        self.edStockpile = EditBox:New {
            text = tostring(stockpile),
            x = 110,
            width = 100,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackPanel,
        }
    end

    local experience--[[ = Spring.GetUnitExperience(self.unitId)]]
    if experience ~= nil then
        local stackPanel = MakeComponentPanel(mainPanel)
        local lblExperience = Label:New {
            caption = "Experience:",
            width = 100,
            x = 1,
            parent = stackPanel,
        }
        self.edExperience = EditBox:New {
            text = tostring(experience),
            x = 110,
            width = 100,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackPanel,
        }
    end

    local fuel --[[= Spring.GetUnitFuel(self.unitId)]]
    if fuel ~= nil then
        local stackPanel = MakeComponentPanel(mainPanel)
        local lblFuel = Label:New {
            caption = "Fuel:",
            width = 100,
            x = 1,
            parent = stackPanel,
        }
        self.edFuel = EditBox:New {
            text = tostring(fuel),
            x = 110,
            width = 100,
            height = SCEN_EDIT.conf.B_HEIGHT,
            parent = stackPanel,
        }
    end

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
--         local cmds = {
--             SetUnitPropertyCommand(self.modelUnitId, "maxhealth", tonumber(self.edMaxHealth.text)),
--             SetUnitPropertyCommand(self.modelUnitId, "health", tonumber(self.edHealth.text)),
--             SetUnitPropertyCommand(self.modelUnitId, "tooltip", self.edTooltip.text),
--         }
--         if self.edStockpile ~= nil then
--             table.insert(cmds, SetUnitPropertyCommand(self.modelUnitId, "stockpile", tonumber(self.edStockpile.text)))
--         end
--         if self.edExperience ~= nil then
--             table.insert(cmds, SetUnitPropertyCommand(self.modelUnitId, "experience", tonumber(self.edExperience.text)))
--         end
--         if self.edFuel ~= nil then
--             table.insert(cmds, SetUnitPropertyCommand(self.modelUnitId, "fuel", tonumber(self.edFuel.text)))
--         end
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

function UnitPropertyWindow:OnSelectionChanged(selection)
    self.selectionChanging = true
    local objectID, bridge
    local keys = { "health" }
    if #selection.units > 0 then
        objectID = selection.units[1]
        bridge = unitBridge
        for _, extra in pairs({"tooltip", "maxHealth"}) do
            table.insert(keys, extra)
        end
    elseif #selection.features > 0 then
        objectID = selection.features[1]
        bridge = featureBridge
    end
    if objectID then
        for _, key in pairs(keys) do
            local value = bridge.s11n:Get(objectID, key)
            self.fields[key].Set(value)
        end
        local pos = bridge.s11n:Get(objectID, "pos")
        self.fields["posX"].Set(pos.x)
        self.fields["posY"].Set(pos.y)
        self.fields["posZ"].Set(pos.z)
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