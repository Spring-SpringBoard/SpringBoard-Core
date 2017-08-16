PasteAction = LCS.class{}

function PasteAction:execute()
    local mx, my, _, _, _ = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(mx, my, true)
    if result == "ground" then
        SB.clipboard:Paste(coords)
    end
end
