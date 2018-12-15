SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

Dialog = Editor:extends{}

function Dialog:init(opts)
    Editor.init(self)

    -- if opts.OnOK ~= nil then
    --     assert(type(opts.OnOK) == 'table')
    --     self.OnOK = opts.OnOK
    -- end
    -- if opts.OnCancel ~= nil then
    --     assert(type(opts.OnCancel) == 'table')
    --     self.OnCancel = opts.OnCancel
    -- end
    if opts.ConfirmDialog then
        assert(type(opts.ConfirmDialog) == 'function')
        -- TODO: This should be simplified...
        self.ConfirmDialog = function()
            opts.ConfirmDialog()
            return true
        end
    end
    if opts.message ~= nil then
        self:AddMessage(opts.message)
    end

    local btnOK = Button:New {
        width = '40%',
        x = 1,
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        caption = "OK",
        classname = "option_button",
        OnClick = {
            function()
                self:ConfirmDialog()
                self:__MaybeClose()
            end
        }
    }

    local btnCancel = Button:New {
        width = '40%',
        x = '50%',
        bottom = 1,
        height = SB.conf.B_HEIGHT,
        caption = "Cancel",
        classname = "negative_button",
        OnClick = {
            function()
                self:__MaybeClose()
            end
        }
    }

    local children = {
        self.lblMessage,
        ScrollPanel:New {
            x = 0,
            bottom = SB.conf.B_HEIGHT + 10,
            height = 120,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
        btnOK,
        btnCancel,
    }

    self:Finalize(children, {
        notMainWindow = true,
        noCloseButton = true,
        x = 500,
        y = 200,
        width = 500,
        height = 200,
    })
end

function Dialog:AddMessage(message)
    assert(type(message) == 'string')
    self.lblMessage = TextBox:New {
        text = message,
        x = 0,
        y = 0,
        width = '100%',
        height = '100%'
    }
end