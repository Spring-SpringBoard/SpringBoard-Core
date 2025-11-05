--- RmlUi File Dialog
--- File browser dialog

SB.Include(Path.Join(SB.DIRS.SRC, 'view/rmlui_dialogs/base_dialog.lua'))

RmlUiFileDialog = RmlUiBaseDialog:extends{}

function RmlUiFileDialog:init(opts)
    opts = opts or {}
    opts.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/dialogs/file_dialog.rml')
    opts.title = opts.title or "Select File"
    RmlUiBaseDialog.init(self, opts)

    self.directory = opts.directory or "/"
    self.filter = opts.filter
    self.allowDirectories = opts.allowDirectories or false
    self.selectedPath = nil
end

function RmlUiFileDialog:Show()
    RmlUiBaseDialog.Show(self)

    if self.document then
        self:PopulateFileList()
        self:BindFileDialogEvents()
    end
end

function RmlUiFileDialog:PopulateFileList()
    -- Stub: Populate file list dynamically
    -- TODO: Implement actual file browsing
    local fileList = self.document:GetElementById("file-list")
    if not fileList then
        return
    end

    -- Example files (stub)
    local filesRml = [[
        <div class="file-item directory" data-path="/example">Example Directory</div>
        <div class="file-item file" data-path="/example/file.txt">file.txt</div>
    ]]

    fileList.inner_rml = filesRml
end

function RmlUiFileDialog:BindFileDialogEvents()
    -- Path input
    local pathInput = self.document:GetElementById("path-input")
    if pathInput then
        pathInput.value = self.directory
    end

    -- Up button
    local btnUp = self.document:GetElementById("btn-up")
    if btnUp then
        btnUp:AddEventListener("click", function()
            -- TODO: Navigate up directory
            Log.Notice("Navigate up (not implemented)")
        end)
    end

    -- OK button override
    local btnOk = self.document:GetElementById("btn-ok")
    if btnOk then
        btnOk.inner_rml = "Open"
    end
end

function RmlUiFileDialog:OnOK()
    local fileNameInput = self.document:GetElementById("file-name-input")
    if fileNameInput then
        self.selectedPath = fileNameInput.value
    end

    if self.onConfirm then
        local result = self.onConfirm(self.selectedPath)
        if result ~= false then
            self:Close()
        end
    else
        self:Close()
    end
end
