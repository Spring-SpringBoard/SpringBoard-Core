SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

AreasWindow = Editor:extends{}
Editor.Register({
    name = "areasWindow",
    editor = AreasWindow,
    tab = "Logic",
    caption = "Area",
    tooltip = "Edit areas",
    image = SB_IMG_DIR .. "bolivia.png",
    order = 0,
})


function AreasWindow:init()
    self:super("init")

    self.btnAddArea = TabbedPanelButton({
        x = 0,
        y = 0,
        tooltip = "Add area",
        children = {
            TabbedPanelImage({ file = SB_IMG_DIR .. "area-add.png" }),
            TabbedPanelLabel({ caption = "Add" }),
        },
        OnClick = {
            function()
                SB.stateManager:SetState(AddRectState(self))
            end
        },
    })
    self:AddDefaultKeybinding({
        self.btnAddArea
    })

    self.areasPanel = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        width = "100%",
        autosize = true,
        resizeItems = false,
    }
    local children = {
        ScrollPanel:New {
            x = 0,
            y = 80,
            bottom = 30,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = {
                self.areasPanel
            },
        },
        self.btnAddArea,
    }

    self:Populate()
    local areaManagerListener = AreaManagerListenerWidget(self)
    SB.model.areaManager:addListener(areaManagerListener)

    self:Finalize(children)
end

function AreasWindow:Populate()
    self.areasPanel:ClearChildren()
    local areas = SB.model.areaManager:getAllAreas()
    for _, areaID in pairs(areas) do
        local areaStackPanel = MakeComponentPanel(self.areasPanel)
        areaStackPanel.areaID = areaID
        local lblArea = Label:New {
            caption = "Area ID: " .. tostring(areaID),
            right = SB.conf.B_HEIGHT + 10,
            x = 1,
            height = SB.conf.B_HEIGHT,
            _toggle = nil,
            parent = areaStackPanel,
        }
        local btnFindArea = Button:New {
            caption = "",
            right = SB.conf.B_HEIGHT + 8,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = areaStackPanel,
            padding = {0, 0, 0, 0},
            tooltip = "Center camera on area",
            children = {
                Image:New {
                    file = SB_IMG_DIR .. "position-marker.png",
                    height = SB.conf.B_HEIGHT,
                    width = SB.conf.B_HEIGHT,
                    padding = {0, 0, 0, 0},
                    margin = {0, 0, 0, 0},
                },
            },
            OnClick = {
                function()
                    local area = SB.model.areaManager:getArea(areaID)
                    if area ~= nil then
                        local x = (area[1] + area[3]) / 2
                        local z = (area[2] + area[4]) / 2
                        local y = Spring.GetGroundHeight(x, z)
                        Spring.SetCameraTarget(x, y, z)
                    end
                end
            },
        }
        local btnRemoveArea = Button:New {
            caption = "",
            right = 0,
            width = SB.conf.B_HEIGHT,
            height = SB.conf.B_HEIGHT,
            parent = areaStackPanel,
            padding = {2, 2, 2, 2},
            tooltip = "Remove area",
            classname = "negative_button",
            children = {
                Image:New {
                    file = SB_IMG_DIR .. "cancel.png",
                    height = "100%",
                    width = "100%",
                },
            },
            OnClick = {
                function()
                    local cmd = RemoveObjectCommand(areaBridge.name,
                                                    areaID)
                    SB.commandManager:execute(cmd)
                end
            },
        }
    end
end

function AreasWindow:IsValidState(state)
    return state:is_A(AddRectState)
end

function AreasWindow:OnLeaveState(state)
    for _, btn in pairs({self.btnAddArea}) do
        btn:SetPressedState(false)
    end
end

function AreasWindow:OnEnterState(state)
    self.btnAddArea:SetPressedState(true)
end

AreaManagerListenerWidget = AreaManagerListener:extends{}

function AreaManagerListenerWidget:init(areaWindow)
    self.areaWindow = areaWindow
end

function AreaManagerListenerWidget:onAreaAdded(areaID)
    self.areaWindow:Populate()
end

function AreaManagerListenerWidget:onAreaRemoved(areaID)
    self.areaWindow:Populate()
end

function AreaManagerListenerWidget:onAreaChange(areaID, area)
    self.areaWindow:Populate()
end
