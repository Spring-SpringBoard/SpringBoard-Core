TabbedWindow = LCS.class{}

local CreateTabsFromEditorRegistry

function TabbedWindow:init()
    self.mainPanelY = 130

    local controls = {}
    if SB.conf.SHOW_BASIC_CONTROLS then
        controls = self:MakeActionButtons(SB.actionRegistry)
        self.mainPanelY = self.mainPanelY + 45
    end

    self.tabs, self.mainPanels = CreateTabsFromEditorRegistry()

    self.__tabPanel = Chili.TabPanel:New {
        x = 0,
        right = 0,
        y = 10,
        bottom = 20,
        scrollTabs = true,
        padding = {0, 0, 0, 0},
        tabs = self.tabs,
    }
    self:__ResizeTabPanel()
    table.insert(controls, self.__tabPanel)

    table.insert(controls, Chili.Line:New {
        y = self.mainPanelY - 5,
        x = 0,
        width = "100%",
    })

    self.mainPanel = Chili.Control:New {
        x = 0,
        width = "100%",
        y = self.mainPanelY,
        bottom = 5,
        padding = {0, 0, 0, 0},
    }
    table.insert(controls, self.mainPanel)

    self.window = Window:New {
        right = 0,
        y = 0,
        width = SB.conf.RIGHT_PANEL_WIDTH,
        --height = 110 + SB.conf.TOOLBOX_ITEM_HEIGHT,
        height = "100%",
        parent = screen0,
        caption = "",
        resizable = false,
        draggable = false,
        padding = {5, 0, 0, 0},
        children = controls,
        classname = "sb_window",
    }
end

CreateTabsFromEditorRegistry = function()
    local tabs = {}
    local mainPanels = {}

    -- Group editors by the tab they belong to
    local tabMapping = SB.GroupByField(SB.editorRegistry, "tab")
    -- Order tabs as specified in Conf first, and in alphabetical order second
    local tabMapping_ = {}
    for _, v in pairs(tabMapping) do
        table.insert(tabMapping_, v)
    end
    tabMapping = tabMapping_
    table.sort(tabMapping, function(a, b)
        local tab1, tab2 = a[1].tab, b[1].tab
        local order1, order2 = SB.conf:GetTabOrder(tab1), SB.conf:GetTabOrder(tab2)
        if order1 ~= order2 then
            return order1 < order2
        end
        return tab1 < tab2
    end)
    -- Create tab panels
    for _, editors in pairs(tabMapping) do
        table.sort(editors, function(a, b)
            if a.order ~= b.order then
                return a.order < b.order
            end
            return a.caption < b.caption
        end)

        local tabName = editors[1].tab
        local panel = MainWindowPanel()
        panel:AddElements(editors)
        table.insert(tabs, {
            name = tabName,
            children = {
                panel:GetControl()
            },
        })
        mainPanels[tabName] = panel
    end

    return tabs, mainPanels
end

function TabbedWindow:AddEditor(editor)
    local tabName = editor.tab
    local mainPanel = self.mainPanels[tabName]
    if mainPanel == nil then
        mainPanel = MainWindowPanel()
        local tab = {
            name = tabName,
            children = {
                mainPanel:GetControl()
            }
        }
        table.insert(self.tabs, tab)
        self.__tabPanel:AddTab(tab)
        self.mainPanels[tabName] = mainPanel
        self:__ResizeTabPanel()
    end

    mainPanel:AddElement(editor)
end

function TabbedWindow:RemoveEditor(editor)
    local tabName = editor.tab
    local mainPanel = self.mainPanels[tabName]
    if mainPanel == nil then
        return
    end

    mainPanel:RemoveEditor(editor)

    if mainPanel:IsEmpty() then
        if self.__tabPanel.tabbar:IsSelected(tabName) then
            self.__tabPanel.tabbar:Select(nil)
        end
        self.__tabPanel:RemoveTab(tabName)
        self.mainPanels[tabName] = nil
        for i, tab in ipairs(self.tabs) do
            if tabName == tab.name then
                table.remove(self.tabs, i)
                break
            end
        end
    end

    self:__ResizeTabPanel()
end

function TabbedWindow:SetMainPanel(panel)
    local mp = self.mainPanel

    -- initialize if needed
    if mp._hidden == nil then
        mp._hidden = {}
    end

    -- hide existing
    local existing = mp.children[1]
    if existing ~= nil then
        mp._hidden[existing] = existing
        existing:Hide()
    end

    -- add new or show hidden
    if mp._hidden[panel] == nil then
        mp:AddChild(panel)
    else
        mp._hidden[panel]:Show()
        mp._hidden[panel] = nil
    end
end

function TabbedWindow:MakeActionButton(actionCfg)
    local btnAction = Button:New {
        y = self.mainPanelY,
        height = 40,
        width = 40,
        caption = '',
        tooltip = actionCfg.tooltip,
        OnClick = {
            function()
                local action = actionCfg.action()
                if not action.canExecute or action:canExecute() then
                    action:execute()
                end
            end
        },
        children = {
            Image:New {
                file = actionCfg.image,
                height = 20,
                width = 20,
                margin = {0, 0, 0, 0},
                x = 0,
            },
        },
    }
    return btnAction
end

function TabbedWindow:MakeActionButtons(actions)
    local i = 1
    local x = 5
    local btnActions = {}
    actions = Table.Filter(actions, function(v)
        return v.toolbar_order ~= nil
    end)
    actions = Table.SortByAttr(actions, "toolbar_order")
    for _, action in pairs(actions) do
        if action.image and action.tooltip then
            local btnAction = self:MakeActionButton(action)
            btnAction.x = x
            table.insert(btnActions, btnAction)
            x = x + 40 + 1
        end
    end
    return btnActions
end


function TabbedWindow:NextTab()
    local nextTab
    for i, tab in pairs(self.tabs) do
        local name = tab.name
        if self.__tabPanel.tabbar:IsSelected(name) then
            if i + 1 <= #self.tabs then
                nextTab = self.tabs[i + 1]
            else
                nextTab = self.tabs[1]
            end
            break
        end
    end

    if nextTab == nil then
        nextTab = self.tabs[1]
    end
    if nextTab ~= nil then
        self.__tabPanel.tabbar:Select(nextTab.name)
    end
end

function TabbedWindow:PreviousTab()
    local prevTab
    for i, tab in pairs(self.tabs) do
        local name = tab.name
        if self.__tabPanel.tabbar:IsSelected(name) then
            if i - 1 >= 1 then
                prevTab = self.tabs[i - 1]
            else
                prevTab = self.tabs[#self.tabs]
            end
            break
        end
    end
    if prevTab == nil then
        prevTab = self.tabs[1]
    end
    if prevTab ~= nil then
        self.__tabPanel.tabbar:Select(prevTab.name)
    end
end

function TabbedWindow:__ResizeTabPanel()
    self.__tabPanel.tabbar:SetPos(nil, nil, #self.tabs * self.__tabPanel.tabbar.children[1].width + 4, nil)
end