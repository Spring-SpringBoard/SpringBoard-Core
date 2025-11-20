--- RmlUi Dynamic UI Builder
--- Provides helpers to dynamically generate RML/RCSS similar to Chili widget creation
--- Used to replace dynamic Chili:New{} calls with RML generation

-- Only load if RmlUi is available
if not RmlUi then
    return
end

RmlUiBuilder = {}

--- Generate a unique ID for dynamic elements
local _elementIdCounter = 0
function RmlUiBuilder.GenerateId(prefix)
    _elementIdCounter = _elementIdCounter + 1
    return (prefix or "elem") .. "_" .. _elementIdCounter
end

--- Build RML string for a button
--- @param opts table {caption, id, onclick, x, y, width, height, parent}
--- @return string RML string
function RmlUiBuilder.Button(opts)
    local id = opts.id or RmlUiBuilder.GenerateId("btn")
    local style = ""

    if opts.x then style = style .. string.format("left: %dpx; ", opts.x) end
    if opts.y then style = style .. string.format("top: %dpx; ", opts.y) end
    if opts.width then
        if type(opts.width) == "string" then
            style = style .. string.format("width: %s; ", opts.width)
        else
            style = style .. string.format("width: %dpx; ", opts.width)
        end
    end
    if opts.height then style = style .. string.format("height: %dpx; ", opts.height) end

    return string.format('<button id="%s" style="%s">%s</button>',
        id, style, opts.caption or "Button")
end

--- Build RML string for a label
--- @param opts table {caption, id, x, y, width, height}
--- @return string RML string
function RmlUiBuilder.Label(opts)
    local id = opts.id or RmlUiBuilder.GenerateId("label")
    local style = ""

    if opts.x then style = style .. string.format("left: %dpx; ", opts.x) end
    if opts.y then style = style .. string.format("top: %dpx; ", opts.y) end
    if opts.width then style = style .. string.format("width: %dpx; ", opts.width) end
    if opts.height then style = style .. string.format("height: %dpx; ", opts.height) end

    return string.format('<div id="%s" class="label" style="%s">%s</div>',
        id, style, opts.caption or "")
end

--- Build RML string for a text input
--- @param opts table {text, id, x, y, width, height}
--- @return string RML string
function RmlUiBuilder.EditBox(opts)
    local id = opts.id or RmlUiBuilder.GenerateId("input")
    local style = ""

    if opts.x then style = style .. string.format("left: %dpx; ", opts.x) end
    if opts.y then style = style .. string.format("top: %dpx; ", opts.y) end
    if opts.width then style = style .. string.format("width: %dpx; ", opts.width) end
    if opts.height then style = style .. string.format("height: %dpx; ", opts.height) end

    return string.format('<input type="text" id="%s" value="%s" style="%s" />',
        id, opts.text or "", style)
end

--- Build RML string for a window/panel
--- @param opts table {caption, id, x, y, width, height, children}
--- @return string RML string
function RmlUiBuilder.Window(opts)
    local id = opts.id or RmlUiBuilder.GenerateId("window")
    local style = ""

    if opts.x then style = style .. string.format("left: %dpx; ", opts.x) end
    if opts.y then style = style .. string.format("top: %dpx; ", opts.y) end
    if opts.width then style = style .. string.format("width: %dpx; ", opts.width) end
    if opts.height then style = style .. string.format("height: %dpx; ", opts.height) end

    local childrenRml = ""
    if opts.children then
        for _, child in ipairs(opts.children) do
            if type(child) == "string" then
                childrenRml = childrenRml .. child
            end
        end
    end

    return string.format([[
<div id="%s" class="window" style="%s">
    <div class="window-title">%s</div>
    <div class="window-content">
        %s
    </div>
</div>]], id, style, opts.caption or "", childrenRml)
end

--- Build RML string for a container panel
--- @param opts table {id, x, y, width, height, children}
--- @return string RML string
function RmlUiBuilder.StackPanel(opts)
    local id = opts.id or RmlUiBuilder.GenerateId("panel")
    local style = "display: flex; flex-direction: column; "

    if opts.x then style = style .. string.format("left: %dpx; ", opts.x) end
    if opts.y then style = style .. string.format("top: %dpx; ", opts.y) end
    if opts.width then
        if type(opts.width) == "string" then
            style = style .. string.format("width: %s; ", opts.width)
        else
            style = style .. string.format("width: %dpx; ", opts.width)
        end
    end
    if opts.height then
        if type(opts.height) == "string" then
            style = style .. string.format("height: %s; ", opts.height)
        else
            style = style .. string.format("height: %dpx; ", opts.height)
        end
    end

    local childrenRml = ""
    if opts.children then
        for _, child in ipairs(opts.children) do
            if type(child) == "string" then
                childrenRml = childrenRml .. child
            end
        end
    end

    return string.format('<div id="%s" class="stack-panel" style="%s">%s</div>',
        id, style, childrenRml)
end

--- Create a separator line
--- @param opts table {width, height}
--- @return string RML string
function RmlUiBuilder.Separator(opts)
    local style = "border-bottom: 1px solid #555; margin: 5px 0; "
    if opts.width then style = style .. string.format("width: %s; ", opts.width) end
    if opts.height then style = style .. string.format("height: %dpx; ", opts.height or 1) end

    return string.format('<div class="separator" style="%s"></div>', style)
end

--- Inject RML into a document at an element
--- @param document RmlDocument The RmlUi document
--- @param elementId string The parent element ID
--- @param rmlString string The RML to inject
function RmlUiBuilder.InjectRML(document, elementId, rmlString)
    local element = document:GetElementById(elementId)
    if not element then
        Log.Error("RmlUiBuilder: Element not found: " .. elementId)
        return false
    end

    element.inner_rml = rmlString
    return true
end

--- Create a dynamic form based on field metadata
--- @param fields table Array of field definitions
--- @return string RML string
function RmlUiBuilder.BuildForm(fields)
    local formRml = '<div class="form">'

    for _, field in ipairs(fields) do
        formRml = formRml .. '<div class="form-row">'

        -- Label
        if field.label then
            formRml = formRml .. RmlUiBuilder.Label({
                caption = field.label,
                width = field.labelWidth or 100
            })
        end

        -- Input based on type
        if field.type == "string" or field.type == "text" then
            formRml = formRml .. RmlUiBuilder.EditBox({
                id = field.id,
                text = field.value or "",
                width = field.width or 200
            })
        elseif field.type == "number" then
            formRml = formRml .. string.format(
                '<input type="number" id="%s" value="%s" style="width: %dpx;" />',
                field.id, field.value or 0, field.width or 200
            )
        elseif field.type == "boolean" then
            formRml = formRml .. string.format(
                '<input type="checkbox" id="%s" %s />',
                field.id, (field.value and 'checked="checked"' or '')
            )
        elseif field.type == "button" then
            formRml = formRml .. RmlUiBuilder.Button({
                id = field.id,
                caption = field.caption or "Button",
                width = field.width or 100
            })
        end

        formRml = formRml .. '</div>'
    end

    formRml = formRml .. '</div>'
    return formRml
end

return RmlUiBuilder
