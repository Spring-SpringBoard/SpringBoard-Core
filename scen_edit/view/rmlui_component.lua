--- RmlUi Base Component
--- Simpler base class for RmlUi windows/components that aren't full dialogs
--- (pickers, floating windows, etc.)

-- Only load if RmlUi is available
if not RmlUi then
    return
end

RmlUiComponent = LCS.class{}

function RmlUiComponent:init(rmlPath, title)
    assert(SB.rmlui and SB.rmlui.initialized, "RmlUi not initialized")

    self.rmlPath = rmlPath
    self.title = title or "Component"
    self.visible = false

    -- Load document immediately in init
    self.document = SB.rmlui:LoadDocument(self.rmlPath, false, true)
    assert(self.document, "Failed to load component: " .. self.rmlPath)

    local titleElement = self.document:GetElementById("component-title")
    if titleElement then
        titleElement.inner_rml = self.title
    end

    self:_EnableHeaderDragging()

    Log.Notice(self.title .. " component initialized")
end

local function FirstByClass(document, className)
    if not document.GetElementsByClassName then
        return nil
    end
    local elements = document:GetElementsByClassName(className)
    return elements and elements[1] or nil
end

-- Make dialogs draggable by their header. `.dialog-header` carries `drag: drag`
-- so RmlUi emits dragstart/drag; the dialog box is centred with
-- left/right/top/bottom + margin:auto, so the first drag pins it to explicit
-- left/top coordinates before moving it.
function RmlUiComponent:_EnableHeaderDragging()
    local document = self.document
    local header = FirstByClass(document, "dialog-header")
    local dialog = FirstByClass(document, "dialog")
    if not (header and dialog) then
        return
    end

    local startLeft, startTop, startMouseX, startMouseY

    header:AddEventListener("dragstart", function(event)
        startLeft = dialog.absolute_left
        startTop = dialog.absolute_top
        startMouseX = event.parameters.mouse_x
        startMouseY = event.parameters.mouse_y
        -- Stop the centring rules from fighting the explicit position.
        dialog.style["right"] = "auto"
        dialog.style["bottom"] = "auto"
        dialog.style["margin"] = "0px"
    end)

    header:AddEventListener("drag", function(event)
        if not startLeft then
            return
        end
        local dx = event.parameters.mouse_x - startMouseX
        local dy = event.parameters.mouse_y - startMouseY
        dialog.style["left"] = tostring(math.floor(startLeft + dx)) .. "px"
        dialog.style["top"] = tostring(math.floor(startTop + dy)) .. "px"
    end)

    header:AddEventListener("dragend", function()
        startLeft, startTop = nil, nil
    end)
end

function RmlUiComponent:Show()
    assert(self.document, "Component document not loaded")

    self.document:Show()
    -- Bring document to front to ensure it's above other UI elements
    if self.document.PullToFront then
        self.document:PullToFront()
    end
    self.visible = true

    -- Register global key listener for ESC
    if not self._keyListener then
        self._keyListener = function(key, mods, isRepeat, label, unicode)
            if self.visible and key == KEYSYMS.ESCAPE then
                self:Close()
                return true  -- Consume the event
            end
            return false
        end
        SB.stateManager:AddGlobalKeyListener(self._keyListener)
    end
end

function RmlUiComponent:Hide()
    assert(self.document, "Component not initialized")
    self.document:Hide()
    self.visible = false
end

function RmlUiComponent:Close()
    assert(self.document, "Component not initialized")

    -- Remove global key listener
    if self._keyListener then
        SB.stateManager:RemoveGlobalKeyListener(self._keyListener)
        self._keyListener = nil
    end

    self.document:Close()
    self.document = nil
    self.visible = false
end

function RmlUiComponent:IsVisible()
    return self.visible
end
