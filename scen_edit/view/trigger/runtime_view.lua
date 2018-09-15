SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

RuntimeWindow = Editor:extends{}
-- TODO: Unnecessary check?
if Spring.GetGameRulesParam("sb_gameMode") ~= "play" then
    RuntimeWindow:Register({
        name = "runtimeWindow",
        tab = "Logic",
        caption = "Runtime",
        tooltip = "See runtime triggers and variables",
        image = SB_IMG_DIR .. "trigger-inspect.png",
        order = 4,
    })
end

function RuntimeWindow:init()
    self:super("init")

    self.dvv = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    self.dtv = StackPanel:New {
        itemMargin = {0, 0, 0, 0},
        x = 1,
        y = 1,
        right = 1,
        autosize = true,
        resizeItems = false,
    }
    self.btnToggleShowDevelop = Button:New {
        caption='Hide dev view',
        x = 0,
        y = 0,
        width= 110,
        height = SB.conf.B_HEIGHT + 20,
        tooltip = "Toggle displaying of debugging symbols",
        OnClick = {
            function()
                SB.view.displayDevelop = not SB.view.displayDevelop
                if SB.view.displayDevelop then
                    self.btnToggleShowDevelop.caption = 'Hide dev view'
                else
                    self.btnToggleShowDevelop.caption = 'Show dev view'
                end
            end
        }
    }

    local children = {
        Control:New {
            orientation = 'horizontal',
            width = '100%',
            y = 10,
            height = SB.conf.B_HEIGHT * 2,
            padding = {0,0,0,0},
            itemPadding = {0,10,10,10},
            itemMargin = {0,0,0,0},
            children = {
                self.btnToggleShowDevelop,
            },
        },
        StackPanel:New {
            y = SB.conf.B_HEIGHT * 2 + 10,
            x = 1,
            right = 1,
            bottom = 30,
            itemMargin = {0, 0, 0, 0},
            children = {
                ScrollPanel:New {
                    width = "100%",
                    height = "100%",
                    children = {
                        self.dvv,
                    },
                },
                ScrollPanel:New {
                    width = "100%",
                    height = "100%",
                    children = {
                        self.dtv,
                    },
                },
            },
        },
    }
    self:Populate()

    self:Finalize(children)

    self:Populate()
end

function RuntimeWindow:Populate()
    DebugTriggerView(self.dtv)
    DebugVariableView(self.dvv)
end
