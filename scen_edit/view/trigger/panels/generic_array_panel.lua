VFS.Include(Path.Join(SB_VIEW_TRIGGER_PANELS_DIR, "type_panel.lua"))

GenericArrayPanel = TypePanel:extends{}

function GenericArrayPanel:init(opts)
    self.subPanels = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
        parent = opts.parent,
    }

    opts.FieldType = function(opts)
        return Field({
            name = opts.name,
            title = opts.title,
            height = 30,
            width = 150,
            components = {
                Button:New {
                    caption = opts.title,
                    width = 150,
                    height = 30,
                    OnClick = {
                        function()
                            self:AddElement()
                            self:Set("cbPredefined", true)
                        end
                    },
                }
            }
        })
    end

    TypePanel.init(self, opts)

    self.atomicType = opts.dataType.type:gsub("_array", "")
    self.elements = {}
end

function GenericArrayPanel:AddElement()
	local subPanel = SB.createNewPanel({
        dataType = {
            type = self.atomicType,
            sources = self.sources
        },
        parent = self.subPanels,
        trigger = self.trigger,
        params = {},
    })
    table.insert(self.elements, subPanel)
	SB.MakeSeparator(self.subPanels)
end

function GenericArrayPanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked then
        field.type = "pred"
        field.value = {}
        for _, subPanel in pairs(self.elements) do
            local subPanelValue = {}
            subPanel:UpdateModel(subPanelValue)
            table.insert(field.value, subPanelValue)
        end
        return true
    end
    return self:super('UpdateModel', field)
end

function GenericArrayPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        for i, data in pairs(field.value) do
            self:AddElement()
            self.elements[i]:UpdatePanel(data)
        end
        return true
    end
    return self:super('UpdatePanel', field)
end
