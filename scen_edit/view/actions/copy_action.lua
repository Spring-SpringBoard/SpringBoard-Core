CopyAction = LCS.class{}

function CopyAction:execute()
    SB.clipboard:Copy(SB.view.selectionManager:GetSelection())
end
