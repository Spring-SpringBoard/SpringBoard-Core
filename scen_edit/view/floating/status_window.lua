StatusWindow = LCS.class{}

function StatusWindow:init(parent, model)
    self.model = model or StatusWindowModel()

    self.lblStatus = Label:New {
        x = 0,
        bottom = 50,
        width = "100%",
        height = 20,
        caption = "",
    }
    self.lblMemory = Label:New {
        x = 0,
        bottom = 25,
        width = "100%",
        height = 30,
        caption = "",
    }
    self.lblSpringBoard = Label:New {
        x = 0,
        bottom = 0,
        width = "100%",
        height = 20,
        caption = "",
    }
    self.statusWindow = Control:New {
        parent = parent,
        caption = "",
        x = 0,
        bottom = 0,
        width = 400,
        height = "100%",
        children = {
            self.lblStatus,
            self.lblMemory,
            self.lblSpringBoard
        }
    }

    self.model:Initialize()
    self:UpdateUI()
end

function StatusWindow:Update()
    self.model:Update()
    self:UpdateUI()
end

function StatusWindow:UpdateUI()
    self.lblStatus:SetCaption(self.model:GetStatusText())
    self.lblMemory:SetCaption(self.model:GetMemoryText())
    self.lblSpringBoard:SetCaption(self.model:GetVersionText())
end
