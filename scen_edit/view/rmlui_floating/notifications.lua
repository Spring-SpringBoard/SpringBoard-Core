RmlUiNotifications = LCS.class{}

-- Replaces Chotify (which is Chili) in RmlUi mode. Notifications are rows in a
-- data model; `SB.ActionProgress` / `SB.NotifyWarn` route here.
function RmlUiNotifications:init()
    self.rmlPath = Path.Join(SB.DIRS.SRC, 'view/rml/floating/notifications.rml')

    local context = SB.rmlui.context
    assert(context, "RmlUi context not initialized")

    self.data = { notifications = {} }
    self.dataModel = context:OpenDataModel("notifications", self.data)
    assert(self.dataModel, "Notifications failed to create data model")

    self.document = context:LoadDocument(self.rmlPath)
    assert(self.document, "Notifications failed to load document")

    -- Expiry lives outside the data model: RmlUi cannot bind the timer userdata.
    self.meta = {}
    self.nextID = 0
end

function RmlUiNotifications:__Refresh()
    self.dataModel.notifications = self.data.notifications
end

function RmlUiNotifications:__Find(id)
    for i, n in ipairs(self.data.notifications) do
        if n.id == id then
            return i, n
        end
    end
end

-- opts: title, body, time (seconds), warning, progress (0..1 or nil)
function RmlUiNotifications:Post(opts)
    self.nextID = self.nextID + 1
    local id = self.nextID

    local entry = {
        id = id,
        title = opts.title or "",
        body = opts.body or "",
        warning = opts.warning or false,
        hasProgress = opts.progress ~= nil,
        progressWidth = string.format("%d%%", math.floor((opts.progress or 0) * 100)),
    }
    -- Wall clock, not game seconds: the editor runs paused.
    self.meta[id] = { postedAt = Spring.GetTimer(), time = opts.time }
    table.insert(self.data.notifications, entry)
    self:__Refresh()
    return id
end

function RmlUiNotifications:Update(id, body, progress)
    local _, entry = self:__Find(id)
    if not entry then
        return
    end
    if body ~= nil then
        entry.body = body
    end
    if progress ~= nil then
        entry.hasProgress = true
        entry.progressWidth = string.format("%d%%", math.floor(progress * 100))
    end
    self:__Refresh()
end

function RmlUiNotifications:Close(id)
    local i = self:__Find(id)
    if not i then
        return
    end
    table.remove(self.data.notifications, i)
    self.meta[id] = nil
    self:__Refresh()
end

function RmlUiNotifications:Exists(id)
    return (self:__Find(id)) ~= nil
end

function RmlUiNotifications:Show()
    if self.document then
        self.document:Show()
    end
end

function RmlUiNotifications:Hide()
    if self.document then
        self.document:Hide()
    end
end

function RmlUiNotifications:Tick()
    local now = Spring.GetTimer()
    local removed = false
    for i = #self.data.notifications, 1, -1 do
        local entry = self.data.notifications[i]
        local meta = self.meta[entry.id]
        if meta and meta.time and Spring.DiffTimers(now, meta.postedAt) >= meta.time then
            table.remove(self.data.notifications, i)
            self.meta[entry.id] = nil
            removed = true
        end
    end
    if removed then
        self:__Refresh()
    end
end
