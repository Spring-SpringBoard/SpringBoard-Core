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

    local children = {
        ScrollPanel:New {
            x = 0,
            bottom = SB.conf.B_HEIGHT + 10,
            height = 120,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        },
    }
    if self.lblMessage ~= nil then
        table.insert(children, self.lblMessage)
    end

    self:Finalize(children, {
        notMainWindow = true,
        buttons = { 'ok', 'cancel' },
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