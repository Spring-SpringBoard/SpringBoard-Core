ProjectStatus = LCS.class{}

function ProjectStatus:init()
    self.lblProject = Label:New {
        x = 0,
        y = 5,
        autosize = true,
        font = {
            size = 22,
            outline = true,
        },
        parent = screen0,
        caption = "",
    }

    -- initial, invalid value to enforce updating the caption
    self.projectDir = -1

    self:Update()
end

function ProjectStatus:Update()
    if SB.projectDir == self.projectDir then
        return
    end
    self.projectDir = SB.projectDir

    local projectCaption
    if self.projectDir then
        projectCaption = "Project: " .. self.projectDir
    else
        projectCaption = "Project not saved"
    end
    if self.lblProject.caption ~= projectCaption then
        self.lblProject:SetCaption(projectCaption)
    end
end
