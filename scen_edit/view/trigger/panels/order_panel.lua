VFS.Include(Path.Join(SB_VIEW_TRIGGER_PANELS_DIR, "type_panel.lua"))

OrderPanel = LCS.class{}

-- TODO: Doesn't invoke self:super, it probably should
-- FIXME: this is probably broken
function OrderPanel:init(opts)
    self.parent = opts.parent
    local stackPanel = MakeComponentPanel(self.parent)
    self.cmbOrderTypes = ComboBox:New {
        items = GetField(SB.metaModel.orderTypes, "humanName"),
        orderTypes = GetField(SB.metaModel.orderTypes, "name"),
        height = SB.conf.B_HEIGHT,
        width = "60%",
        y = "20%",
        x = '20%',
        parent = stackPanel,
    }
    self.orderPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        padding = {0, 0, 0, 0},
        parent = self.parent,
    }
    self.cmbOrderTypes.OnSelect = {
        function(object, itemIdx, selected)
            if selected and itemIdx > 0 then
                self.orderPanel:ClearChildren()
                local ordName = self.cmbOrderTypes.orderTypes[itemIdx]
                local order = SB.metaModel.orderTypes[ordName]
                for i = 1, #order.input do
                    local input = order.input[i]
                    local subPanelName = input.name
                    if input.humanName then
                        Label:New {
                            parent = self.orderPanel,
                            caption = input.humanName,
                            x = 1,
                            right = 1,
                        }
                    end
                    local subPanel = SB.createNewPanel({
                        dataType = input,
                        parent = self.orderPanel,
                        -- FIXME: no reference to self.trigger; things might break
                        -- trigger = self.trigger
                    })
                    if subPanel then
                        self.orderPanel[subPanelName] = subPanel
                        if i ~= #order.input then
                            SB.MakeSeparator(self.orderPanel)
                        end
                    end
                end
            end
        end
    }

    self.cmbOrderTypes:Select(0)
    self.cmbOrderTypes:Select(1)
end

function OrderPanel:UpdateModel(field)
    local ordName = self.cmbOrderTypes.orderTypes[self.cmbOrderTypes.selected]
    local order = SB.metaModel.orderTypes[ordName]
    field.orderTypeName = ordName
    for i = 1, #order.input do
        local input = order.input[i]
        local subPanelName = input.name
        local subPanel = self.orderPanel[subPanelName]
        if subPanel then
            field[subPanelName] = {}
            if not self.orderPanel[subPanelName]:UpdateModel(field[subPanelName]) then
                return false
            end
        end
    end
    return true
end

function OrderPanel:UpdatePanel(field)
    local ordName = field.orderTypeName
    local order = SB.metaModel.orderTypes[ordName]
    self.cmbOrderTypes:Select(GetIndex(self.cmbOrderTypes.orderTypes, ordName))
    for i = 1, #order.input do
        local input = order.input[i]
        local subPanelName = input.name
        local subPanel = self.orderPanel[subPanelName]
        if subPanel then
            subPanel:UpdatePanel(field[subPanelName])
        end
    end
    return true
end
