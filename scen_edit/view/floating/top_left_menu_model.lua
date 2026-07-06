TopLeftMenuModel = LCS.class{}

function TopLeftMenuModel:init()
    self.projectDir = -1 -- Invalid initial value to force update
end

function TopLeftMenuModel:Exit()
    Spring.SendCommands("quit", "quitforce")
end

function TopLeftMenuModel:ShowMenu()
    if Spring.SendLuaMenuMsg then
        Spring.SendLuaMenuMsg("showLobby")
    end
end

function TopLeftMenuModel:GetProjectPath()
    if SB.project and SB.project.path then
        return SB.project.path
    end
    return nil
end

function TopLeftMenuModel:GetProjectCaption()
    local path = self:GetProjectPath()
    if path then
        return "Project: " .. path
    else
        return "Project not saved"
    end
end

function TopLeftMenuModel:HasProjectPath()
    return self:GetProjectPath() ~= nil
end

function TopLeftMenuModel:IsLuaMenuAvailable()
    local luaMenu = Spring.GetMenuName and Spring.SendLuaMenuMsg and Spring.GetMenuName()
    return luaMenu and luaMenu ~= ""
end

function TopLeftMenuModel:DisableLobbyButton()
    if self:IsLuaMenuAvailable() then
        Spring.SendLuaMenuMsg("disableLobbyButton")
    end
end

function TopLeftMenuModel:Update()
    -- Check if project changed
    local newPath = self:GetProjectPath()
    if newPath ~= self.projectDir then
        self.projectDir = newPath
        return true -- Changed
    end
    return false -- No change
end
