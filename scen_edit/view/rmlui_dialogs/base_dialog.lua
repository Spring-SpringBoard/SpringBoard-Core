--- RmlUi Base Dialog
--- Base class for all RmlUi dialogs
--- Like Chili Dialog, this extends EditorBase to get AddField() support

SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_editor_base.lua'))

RmlUiBaseDialog = RmlUiEditorBase:extends{}

function RmlUiBaseDialog:init(opts)
    self:super("init")

    opts = opts or {}
    self.editorTitle = opts.title or "Dialog"
    self.onConfirm = opts.onConfirm
    self.onCancel = opts.onCancel
    self.visible = false

    -- Dialogs can have custom validation/confirmation logic
    if opts.ConfirmDialog then
        assert(type(opts.ConfirmDialog) == 'function')
        self.ConfirmDialog = opts.ConfirmDialog
    end
end

-- Show/Hide/Close are inherited from RmlUiEditorBase

function RmlUiBaseDialog:Show()
    -- Initialize if not already done
    if not self.document then
        self:Initialize()
    end

    -- Finalize fields (generate RML from AddField calls)
    self:Finalize()

    -- Show the dialog
    self:super("Show")
    self.visible = true
end

function RmlUiBaseDialog:ConfirmDialog()
    -- Default confirmation - override in subclasses for validation
    -- Return true to close dialog, false to keep it open
    return true
end

function RmlUiBaseDialog:OnOK()
    -- Call custom confirmation logic
    local canClose = self:ConfirmDialog()

    if canClose then
        if self.onConfirm then
            -- Call the onConfirm callback if provided
            local result = self.onConfirm(self:GetAllFieldValues())
            if result ~= false then
                self:Close()
            end
        else
            self:Close()
        end
    end
end

function RmlUiBaseDialog:OnCancel()
    if self.onCancel then
        self.onCancel()
    end
    self:Close()
end

-- Override Finalize to add OK/Cancel buttons
function RmlUiBaseDialog:Finalize(children, opts)
    -- Call parent Finalize to render fields
    self:super("Finalize", children, opts)

    if not self.document then
        return
    end

    -- Inject OK/Cancel buttons into footer
    local footer = self.document:GetElementById("editor-footer")
    if footer then
        footer.inner_rml = [[
            <button id="btn-ok" class="dialog-button primary">OK</button>
            <button id="btn-cancel" class="dialog-button">Cancel</button>
        ]]

        -- Bind button events
        local btnOk = self.document:GetElementById("btn-ok")
        if btnOk then
            btnOk:AddEventListener("click", function()
                self:OnOK()
            end)
        end

        local btnCancel = self.document:GetElementById("btn-cancel")
        if btnCancel then
            btnCancel:AddEventListener("click", function()
                self:OnCancel()
            end)
        end
    end

    Log.Notice("Dialog finalized: " .. self.editorTitle)
end
