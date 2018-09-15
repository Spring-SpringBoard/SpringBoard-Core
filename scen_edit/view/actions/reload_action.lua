SB.Include(Path.Join(SB_VIEW_ACTIONS_DIR, "action.lua"))

ReloadAction = Action:extends{}

ReloadAction:Register({
    name = "sb_reload",
    tooltip = "Reload meta model",
    toolbar_order = 201,
    image = SB_IMG_DIR .. "recycle.png"
})

function ReloadAction:execute()
    SB.conf:initializeListOfMetaModelFiles()
    local command = ReloadMetaModelCommand(SB.conf:GetMetaModelFiles())
    SB.commandManager:execute(command)
    SB.commandManager:execute(command, true)
end
