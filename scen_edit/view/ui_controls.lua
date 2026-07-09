-- UI-agnostic control wrappers for editors
-- Editors should use these instead of Chili components directly
-- These create Chili controls OR RmlUi wrappers depending on mode

-- ActionButton - replacement for TabbedPanelButton
-- Used for editor action buttons like "Add", "Set", "Smooth", "Paint", etc.
function ActionButton(opts)
    if SB.useRmlUi then
        -- Extract caption and image from children (Chili pattern)
        local caption = ""
        local image = nil
        if opts.children then
            for _, child in ipairs(opts.children) do
                if child.caption then
                    caption = child.caption
                elseif child.file then
                    image = child.file
                end
            end
        end

        return RmlUiTabbedPanelButton({
            x = opts.x,
            y = opts.y,
            tooltip = opts.tooltip or "",
            OnClick = opts.OnClick or {},
            caption = caption,
            image = image,
        })
    else
        -- Chili mode - use original TabbedPanelButton
        return TabbedPanelButton(opts)
    end
end

-- EditorButton - replacement for Button:New in AddControl
-- Used for regular buttons like "Show elevation", "Compile", etc.
function EditorButton(opts)
    if SB.useRmlUi then
        return RmlUiButton({
            caption = opts.caption or "Button",
            OnClick = opts.OnClick or {},
            width = opts.width,
            height = opts.height,
            tooltip = opts.tooltip,
            image = opts.image,
        })
    end

    -- Chili mode - use original Button. An icon is a child Image.
    if opts.image then
        opts = Table.Merge({}, opts)
        opts.children = {
            Image:New {
                file = opts.image,
                height = "100%",
                width = "100%",
            },
        }
        opts.image = nil
    end
    return Button:New(opts)
end

-- EditorProgressBar - a progress bar updated after creation (map compile).
function EditorProgressBar(opts)
    opts = opts or {}
    if SB.useRmlUi then
        return RmlUiProgressBar({ value = opts.value })
    end
    return Progressbar:New(opts)
end

-- EditorLabel - a Label whose caption is updated later (dialog error lines).
function EditorLabel(opts)
    opts = opts or {}
    if SB.useRmlUi then
        return RmlUiLabel({ caption = opts.caption })
    end
    return Label:New(opts)
end

-- SectionLabel / SectionLine - replacements for Label:New / Line:New used as
-- section separators inside Editor:AddControl. In RmlUi these are plain
-- descriptors, so no Chili control is constructed; ConvertPlaceholderChildToRmlUi
-- turns them into markup.
function SectionLabel(opts)
    opts = opts or {}
    if SB.useRmlUi then
        return { __sectionLabel = true, caption = opts.caption }
    end
    return Label:New(opts)
end

function SectionLine(opts)
    opts = opts or {}
    if SB.useRmlUi then
        return { __sectionLine = true }
    end
    return Line:New(opts)
end

-- FilterLabel - replacement for Label:New in filter UI
-- Used for filter labels like "Type:", "Terrain:", "Search:", etc.
function FilterLabel(opts)
    if SB.useRmlUi then
        return RmlUiLabel(opts)
    else
        -- Chili mode - use original Label
        return Label:New(opts)
    end
end

-- FilterComboBox - replacement for ComboBox:New in filter UI
-- Used for dropdown filters like terrain type, unit type, etc.
function FilterComboBox(opts)
    if SB.useRmlUi then
        return RmlUiComboBox(opts)
    else
        -- Chili mode - use original ComboBox
        return ComboBox:New(opts)
    end
end

-- FilterEditBox - replacement for EditBox:New in filter UI
-- Used for search input fields
function FilterEditBox(opts)
    if SB.useRmlUi then
        return RmlUiEditBox(opts)
    else
        -- Chili mode - use original EditBox
        return EditBox:New(opts)
    end
end

Log.Notice("UI controls abstraction layer loaded")
