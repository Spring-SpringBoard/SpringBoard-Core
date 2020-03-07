SB.Include(Path.Join(SB.DIRS.SRC, 'view/actions/action.lua'))

ReloadAction = Action:extends{}

ReloadAction:Register({
    name = "sb_reload",
    tooltip = "Reload meta model",
    toolbar_order = 201,
    image = Path.Join(SB.DIRS.IMG, 'recycle.png')
})

function ReloadAction:execute()
    SB.conf:initializeListOfMetaModelFiles()
    local command = ReloadMetaModelCommand(SB.conf:GetMetaModelFiles())
    SB.commandManager:execute(command)
    SB.commandManager:execute(command, true)
end
