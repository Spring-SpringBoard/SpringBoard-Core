CutAction = LCS.class{}

function CutAction:execute()
    SB.clipboard:Cut(SB.view.selectionManager:GetSelection())
end
