--- RmlUi File Dialog
--- File browser dialog - 100% programmatic using AddField()

SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_dialogs/base_dialog.lua'))

RmlUiFileDialog = RmlUiBaseDialog:extends{}

function RmlUiFileDialog:init(opts)
    opts = opts or {}
    opts.title = opts.title or "Select File"
    self:super("init", opts)

    self.directory = opts.directory or "/"
    self.filter = opts.filter
    self.allowDirectories = opts.allowDirectories or false

    -- Add fields programmatically
    self:AddField(StringField({
        name = "fileName",
        title = "File name:",
        value = "",
        width = 500,
    }))

    -- TODO: Add file browser component (AssetView equivalent)
    -- For now, just a simple path field
    self:AddField(StringField({
        name = "directory",
        title = "Directory:",
        value = self.directory,
        width = 500,
    }))

    -- Error message field
    self:AddField(StringField({
        name = "error",
        title = "",
        value = "",
        width = 500,
    }))
end

function RmlUiFileDialog:SetDialogError(error)
    if error ~= nil then
        self:SetFieldValue("error", tostring(error))
    else
        self:SetFieldValue("error", "Unknown error")
    end
end

function RmlUiFileDialog:getSelectedFilePath()
    local dir = self:GetFieldValue("directory") or self.directory
    local fileName = self:GetFieldValue("fileName") or ""
    return Path.Join(dir, fileName)
end

function RmlUiFileDialog:ConfirmDialog()
    -- Validation logic
    local path = self:getSelectedFilePath()

    if not path or path == "" then
        self:SetDialogError("Please select a file.")
        return false
    end

    -- Custom validation callback if provided
    if self.confirmDialogCallback then
        local success, error = self.confirmDialogCallback(path)
        if not success then
            self:SetDialogError(error)
        end
        return success
    end

    return true
end

function RmlUiFileDialog:setConfirmDialogCallback(func)
    self.confirmDialogCallback = func
end
