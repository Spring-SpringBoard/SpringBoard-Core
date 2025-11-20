SB.Include(Path.Join(SB.DIRS.SRC, 'view/floating/status_window_model.lua'))

StatusWindow = LCS.class{}

function StatusWindow:init(parent)
    self.model = StatusWindowModel()

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
        caption = self.model:GetVersionString(),
        --valign = "ascender",
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

    -- Register view callbacks with model
    self.model.onStatusUpdate = function(statusText)
        self.lblStatus:SetCaption(statusText)
    end
    self.model.onMemoryUpdate = function(memoryStr)
        self.lblMemory:SetCaption(memoryStr)
    end
end

function StatusWindow:Update()
    self.model:Update()
end
