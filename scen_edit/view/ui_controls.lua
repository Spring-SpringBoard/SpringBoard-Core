-- UI-agnostic control wrappers for editors
-- Editors should use these instead of Chili components directly
-- These create Chili controls OR RmlUi wrappers depending on mode

-- Detect if RmlUi mode is active
local function IsRmlUiMode()
    return SB.view and SB.view.useRmlUi
end

-- ActionButton - replacement for TabbedPanelButton
-- Used for editor action buttons like "Add", "Set", "Smooth", "Paint", etc.
function ActionButton(opts)
    if IsRmlUiMode() then
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
    if IsRmlUiMode() then
        return RmlUiButton({
            caption = opts.caption or "Button",
            OnClick = opts.OnClick or {},
            width = opts.width,
            height = opts.height,
            tooltip = opts.tooltip,
        })
    else
        -- Chili mode - use original Button
        return Button:New(opts)
    end
end

Log.Notice("UI controls abstraction layer loaded")
