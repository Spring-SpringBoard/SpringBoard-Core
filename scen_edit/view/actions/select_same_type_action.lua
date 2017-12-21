SelectSameTypeAction = LCS.class{}

-- NOTE: This currently filters based on def and additionally whether the object
-- is in screen
-- NOTE: In the future maybe rewrite this to support arbitrary filters, but seems
-- unnecessary now

function SelectSameTypeAction:execute()
    local currentSelection = SB.view.selectionManager:GetSelection()
    local selection = {}
    for name, bridge in pairs(ObjectBridge.GetObjectBridges()) do
        if bridge.s11n and bridge.s11n.GetAllObjectIDs then
            local allIDs = bridge.s11n:GetAllObjectIDs()

            -- if there is no def field and if at least one such object is already selected
            -- then select all such objects
            if not (bridge.s11n.funcs and bridge.s11n.funcs.defName) then
                if #currentSelection[name] > 0 then
                    selection[name] = allIDs
                end
            -- if there is a def field, first figure out what things are selected,
            -- then select objects that have a matching def id
            else
                -- get unique def names and put in a map for faster access
                local defNames = bridge.s11n:Get(currentSelection[name], "defName")
                defNames = Table.Unique(GetValues(defNames))
                defNameMap = {}
                for _, v in pairs(defNames) do
                    defNameMap[v] = true
                end

                -- filter based on defName
                selection[name] = {}
                local vsx, vsy = Spring.GetViewGeometry()
                for _, objectID in ipairs(allIDs) do
                    if defNameMap[bridge.s11n:Get(objectID, "defName")] then
                        if not self.checkPos then
                            table.insert(selection[name], objectID)
                        else
                            -- filter only those in view
                            local pos = bridge.s11n:Get(objectID, "pos")
                            local sx, sy, sz = Spring.WorldToScreenCoords(pos.x, pos.y, pos.z)
                            if sx >= 0 and sy >= 0 and sx < vsx and sy < vsy then
                                table.insert(selection[name], objectID)
                            end
                        end
                    end
                end
            end
        end
    end
    SB.view.selectionManager:Select(selection)
end

SelectSameTypeInViewAction = SelectSameTypeAction:extends{}
SelectSameTypeInViewAction.checkPos = true
