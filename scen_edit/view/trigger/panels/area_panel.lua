AreaPanel = AbstractTypePanel:extends{}

function AreaPanel:MakePredefinedOpt()
    local stackAreaPanel = MakeComponentPanel(self.parent)
    self.cbPredefined = Checkbox:New {
        caption = "Predefined area: ",
        right = 100 + 10,
        x = 1,
        checked = false,
        parent = stackAreaPanel,
    }
    table.insert(self.radioGroup, self.cbPredefined)
    self.btnPredefined = Button:New {
        caption = '...',
        right = 40,
        width = 60,
        height = SB.conf.B_HEIGHT,
        parent = stackAreaPanel,
        areaId = nil,
    }
    self.btnPredefined.OnClick = {
        function()
            SB.stateManager:SetState(SelectAreaState(self.btnPredefined))
        end
    }
    self.btnPredefined.OnSelectArea = {
        function(areaId)
            self.btnPredefined.areaId = areaId
            self.btnPredefined.caption = "Id=" .. areaId
            self.btnPredefined:Invalidate()
            if not self.cbPredefined.checked then
                self.cbPredefined:Toggle()
            end
        end
    }
    self.btnPredefinedZoom = Button:New {
        caption = "",
        right = 1,
        width = SB.conf.B_HEIGHT,
        height = SB.conf.B_HEIGHT,
        parent = stackAreaPanel,
        padding = {0, 0, 0, 0},
        children = {
            Image:New {
                tooltip = "Select area",
                file=SB_IMG_DIR .. "search.png",
                height = SB.conf.B_HEIGHT,
                width = SB.conf.B_HEIGHT,
                padding = {0, 0, 0, 0},
                margin = {0, 0, 0, 0},
            },
        },
        OnClick = {
            function()
                if self.btnPredefined.areaId ~= nil then
                    local area = SB.model.areaManager:getArea(self.btnPredefined.areaId)
                    if area ~= nil then
                        local x = (area[1] + area[3]) / 2
                        local z = (area[2] + area[4]) / 2
                        local y = Spring.GetGroundHeight(x, z)
                        Spring.SetCameraTarget(x, y, z)
                    end
                end
            end
        }
    }
end

function AreaPanel:UpdateModel(field)
    if self.cbPredefined and self.cbPredefined.checked and self.btnPredefined.areaId ~= nil then
        field.type = "pred"
        field.value = self.btnPredefined.areaId
        return true
    end
    return self:super('UpdateModel', field)
end

function AreaPanel:UpdatePanel(field)
    if field.type == "pred" then
        if not self.cbPredefined.checked then
            self.cbPredefined:Toggle()
        end
        CallListeners(self.btnPredefined.OnSelectArea, field.value)
        return true
    end
    return self:super('UpdatePanel', field)
end
