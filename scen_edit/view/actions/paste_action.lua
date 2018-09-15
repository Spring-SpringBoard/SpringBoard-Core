SB.Include(Path.Join(SB_VIEW_ACTIONS_DIR, "action.lua"))

PasteAction = Action:extends{}

PasteAction:Register({
    name = "sb_paste",
    tooltip = "Paste",
    image = SB_IMG_DIR .. "stabbed-note.png",
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
