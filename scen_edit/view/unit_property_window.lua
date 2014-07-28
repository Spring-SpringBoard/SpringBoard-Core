UnitPropertyWindow = LCS.class{}

function UnitPropertyWindow:init(unitId)
    self.unitId = unitId
    self.modelUnitId = SCEN_EDIT.model.unitManager:getModelUnitId(self.unitId)

    local btnOk = Button:New {
        caption='OK',
        width='40%',
        x = 1,
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        backgroundColor = SCEN_EDIT.conf.BTN_OK_COLOR,
    }
    local btnCancel = Button:New {
        caption='Cancel',
        width='40%',
        x = '50%',
        bottom = 1,
        height = SCEN_EDIT.conf.B_HEIGHT,
        backgroundColor = SCEN_EDIT.conf.BTN_CANCEL_COLOR,
        OnClick={function() self.window:Dispose() end}
    }

    local mainPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }

    local stackPanel = MakeComponentPanel(mainPanel)
    local lblHealth = Label:New {
        caption = "Health:",
        width = 100,
        x = 1,
        parent = stackPanel,
    }
    self.edHealth = EditBox:New {
        text = tostring(Spring.GetUnitHealth(self.unitId)),
        x = 110,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackPanel,
    }

    local stackPanel = MakeComponentPanel(mainPanel)
    local lblMaxHealth = Label:New {
        caption = "Max health:",
        width = 100,
        x = 1,
        parent = stackPanel,
    }
    local _, maxHealth = Spring.GetUnitHealth(self.unitId)
    self.edMaxHealth = EditBox:New {
        text = tostring(maxHealth),
        x = 110,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackPanel,
    }

    local stackPanel = MakeComponentPanel(mainPanel)
    local lblTooltip = Label:New {
        caption = "Tooltip:",
        width = 100,
        x = 1,
        parent = stackPanel,
    }
    self.edTooltip = EditBox:New {
        text = Spring.GetUnitTooltip(self.unitId),
        x = 110,
        width = 100,
        height = SCEN_EDIT.conf.B_HEIGHT,
        parent = stackPanel,
    }

    local stockpile = Spring.GetUnitStockpile(self.unitId)
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

    local experience = Spring.GetUnitExperience(self.unitId)
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

    local fuel = Spring.GetUnitFuel(self.unitId)
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

    self.window = Window:New {
        width = 340,
        height = 450,
        minimumSize = {150,200},
        x = 500,
        y = 300,
        parent = screen0,
        children = { 
            btnOk,
            btnCancel,
            mainPanel,
        }
    }

    SCEN_EDIT.MakeConfirmButton(self.window, btnOk)
    table.insert(self.window.OnConfirm, function()        
        local cmds = {
            SetUnitPropertyCommand(self.modelUnitId, "health", tonumber(self.edHealth.text)),
            SetUnitPropertyCommand(self.modelUnitId, "maxhealth", tonumber(self.edMaxHealth.text)),
            SetUnitPropertyCommand(self.modelUnitId, "tooltip", self.edTooltip.text),
        }
        if self.edStockpile ~= nil then
            table.insert(cmds, SetUnitPropertyCommand(self.modelUnitId, "stockpile", tonumber(self.edStockpile.text)))
        end        
        if self.edExperience ~= nil then
            table.insert(cmds, SetUnitPropertyCommand(self.modelUnitId, "experience", tonumber(self.edExperience.text)))
        end
        if self.edFuel ~= nil then
            table.insert(cmds, SetUnitPropertyCommand(self.modelUnitId, "fuel", tonumber(self.edFuel.text)))
        end

        local compoundCommand = CompoundCommand(cmds)
        SCEN_EDIT.commandManager:execute(compoundCommand)
    end)
end