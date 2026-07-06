SB.Include(Path.Join(SB.DIRS.SRC, 'view/floating/top_left_menu_model.lua'))

RmlUiTopLeftMenu = LCS.class{}

function RmlUiTopLeftMenu:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/top_left_menu.rml')
    self.model = TopLeftMenuModel()

    -- Load document
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false)

    -- Cache all UI elements and assert they exist
    self.elements = {
        btnExit = self.document:GetElementById("btn-exit"),
        btnMenu = self.document:GetElementById("btn-menu"),
        projectLabel = self.document:GetElementById("project-label"),
    }

    -- Assert all required elements exist
    for name, element in pairs(self.elements) do
        assert(element, "Top Left Menu missing element: " .. name)
    end

    self:SetupButtonVisibility()
    self:BindEvents()
    self:Update()
end

function RmlUiTopLeftMenu:SetupButtonVisibility()
    -- Hide buttons that aren't available
    if not self.model:IsLuaMenuAvailable() then
        self.elements.btnMenu:SetClass("hidden", true)
    end

end

function RmlUiTopLeftMenu:UpdateProjectDisplay()
    self.elements.projectLabel.inner_rml = self.model:GetProjectCaption()
end

function RmlUiTopLeftMenu:BindEvents()
    -- Exit button
    self.elements.btnExit:AddEventListener("click", function()
        -- TODO: Add confirmation dialog
        self.model:Exit()
    end)

    -- Menu button
    if self.model:IsLuaMenuAvailable() then
        self.model:DisableLobbyButton()
        self.elements.btnMenu:AddEventListener("click", function()
            self.model:ShowMenu()
        end)
    end

end

function RmlUiTopLeftMenu:Show()
    if self.document then
        self.document:Show()
    end
end

function RmlUiTopLeftMenu:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiTopLeftMenu:Update()
    if self.model:Update() then
        self:UpdateProjectDisplay()
    end
end

function RmlUiTopLeftMenu:Dispose()
    self.document:Close()
end
