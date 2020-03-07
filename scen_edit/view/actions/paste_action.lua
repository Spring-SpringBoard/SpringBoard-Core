SB.Include(Path.Join(SB.DIRS.SRC, 'view/actions/action.lua'))

PasteAction = Action:extends{}

PasteAction:Register({
    name = "sb_paste",
    tooltip = "Paste",
    image = Path.Join(SB.DIRS.IMG, 'stabbed-note.png'),
    toolbar_order = 103,
    hotkey = {
        key = KEYSYMS.V,
        ctrl = true,
    },
    limit_state = true
})

function PasteAction:execute()
    local mx, my, _, _, _ = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(mx, my, true)
    if result == "ground" then
        SB.clipboard:Paste(coords)
    end
end
