SB.Include(Path.Join(SB.DIRS.SRC, 'view/actions/save_as_action.lua'))

SaveProjectAction = SaveProjectAsAction:extends{}

SaveProjectAction:Register({
    name = "sb_save_project",
    tooltip = "Save project",
    image = Path.Join(SB.DIRS.IMG, 'save.png'),
    toolbar_order = 4,
    hotkey = {
        key = KEYSYMS.S,
        ctrl = true
    },
})

function SaveProjectAction:execute()
    if SB.project.path == nil then
        self:super("execute")
    else
        SB.project:Save()
    end
end
