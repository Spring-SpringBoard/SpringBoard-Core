SB.Include(Path.Join(SB_VIEW_DIR, "editor.lua"))

ColorPickerWindow = Editor:extends{}

function ColorPickerWindow:init(opts)
    self:super("init")

    self.format = opts.format
    self.color = opts.value or {1, 1, 1, 1}
    self.OnUpdate = opts.OnUpdate
    -- Listeners suffix is necessary as the self.On*Change methods exist
    self.OnStartChangeListeners = opts.OnStartChange
    self.OnEndChangeListeners = opts.OnEndChange

    local hsvSliders = {
        {
            background = SB_IMG_DIR .. "color_picker/h_grad.png",
            max        = 360,
        },
        {
            background = SB_IMG_DIR .. "color_picker/ticks.png",
            max        = 100,
        },
        {
            background = SB_IMG_DIR .. "color_picker/bw_grad.png",
            max        = 100,
        },
    }
    if self.format == 'rgba' then
        table.insert(hsvSliders, {
            background = SB_IMG_DIR .. "color_picker/ticks.png",
            max        = 100,
        })
    end

    self:AddField(ColorPickerField({
        name = "hsvColor",
        colorSliders = hsvSliders,
        CalculateColor = function(obj, color)
            local c = Table.DeepCopy(color)
            c[1] = math.min(0.998, c[1])
            c[2] = math.max(0.001, c[2])
            c[3] = math.max(0.001, c[3])
            if #c == 4 then
                c[4] = math.max(0.001, c[4])
            end
            return hsv2rgb(c)
        end,
        ApplyColor = function(obj, color)
            return rgb2hsv(color)
        end,
    }))

    local rgbSliders = {
        {
            background = SB_IMG_DIR .. "color_picker/bw_grad.png",
            color      = {1, 0, 0, 1},
            max        = 256,
        },
        {
            background = SB_IMG_DIR .. "color_picker/bw_grad.png",
            color      = {0, 1, 0, 1},
            max        = 256,
        },
        {
            background = SB_IMG_DIR .. "color_picker/bw_grad.png",
            color      = {0, 0, 1, 1},
            max        = 256,
        },
    }
    if self.format == 'rgba' then
        table.insert(rgbSliders, {
            background = SB_IMG_DIR .. "color_picker/ticks.png",
            max        = 100,
        })
    end
    self:AddField(ColorPickerField({
        name = "rgbaColor",
        colorSliders = rgbSliders
    }))

    self:Set("rgbaColor", self.color)
    self:Set("hsvColor", self.color)

    local children = {}

    table.insert(children,
        ScrollPanel:New {
            x = 0,
            y = 0,
            bottom = 0,
            right = 0,
            borderColor = {0,0,0,0},
            horizontalScrollbar = false,
            children = { self.stackPanel },
        }
    )
    if opts.expand then
        self:Finalize(children)
    else
        self:Finalize(children, {
            notMainWindow = true,
            buttons = { "close" },
            disposeOnClose = false,
            width = 500,
            -- height = 300,
            height = 400,
        })
    end
end

function rgb2hsv(value)
    local r, g, b = value[1], value[2], value[3]
    local h, s, v
    local minC = math.min(r, g, b)
    local maxC = math.max(r, g, b)
    v = maxC

    local delta = maxC - minC

    if maxC ~= 0 then
        s = delta / maxC
    else -- s = 0, v is undefined
        s = 0
        h = 0
        return {h, s, v, value[4]}
    end

    if r == maxC then
        h = (g - b) / delta
    elseif g == maxC then
        h = 2 + (b - r) / delta
    else
        h = 4 + (r - g) / delta
    end
    h = h * 60
    if h < 0 then
        h = h + 360
    end
    h = h / 360

    return {h, s, v, value[4]}
end

function hsv2rgb(value)
    local h, s, v = value[1] * 360, value[2], value[3]
    local chroma = v * s
    local h1 = h / 60
    local x = chroma * (1 - math.abs(h1 % 2 - 1))

    local r, g, b = 0, 0, 0
    if h1 >= 0 and h1 < 1 then
        r, g, b = chroma, x, 0
    elseif h1 < 2 then
        r, g, b   = x, chroma, 0
    elseif h1 < 3 then
        r, g, b   = 0, chroma, x
    elseif h1 < 4 then
        r, g, b   = 0, x, chroma
    elseif h1 < 5 then
        r, g, b   = x, 0, chroma
    elseif h1 < 6 then
        r, g, b   = chroma, 0, x
    end

    local m = v - chroma
    r, g, b = r + m, g + m, b + m
    return {r, g, b, value[4]}
end

-- SB.Include(SB_VIEW_DIR .. "color_picker_window.lua")
-- not the best naming, but this component is a specific implementation/listener
-- for the ColorPickerWindow used to set the color field's value
ColorFieldPickerWindow = ColorPickerWindow:extends{}
function ColorFieldPickerWindow:OnFieldChange(name, value)
    -- Link RGB and HSL color sliders
    if self.updating then
        return
    end
    self.updating = true
    if name == "rgbaColor" then
        self:Set("hsvColor", value)
    elseif name == "hsvColor" then
        self:Set("rgbaColor", value)
    end
    self.updating = false

    CallListeners(self.OnUpdate, value)
end

function ColorFieldPickerWindow:OnStartChange(name)
    CallListeners(self.OnStartChangeListeners, name)
end

function ColorFieldPickerWindow:OnEndChange(name)
    CallListeners(self.OnEndChangeListeners, name)
end


SB.Include(SB_VIEW_FIELDS_DIR .. "field.lua")

ColorPickerField = Field:extends{}

function ColorPickerField:Update(source)
    self.imValue.color = self.value
    self.imValue:Invalidate()
    local value = self.value
    if self.ApplyColor then
        value = self:ApplyColor(value)
    end
    if #value == 3 then
        value[4] = 1
    end
    for i, tbSlider in pairs(self.sliders) do
        if tbSlider ~= source then
            tbSlider:SetValue(value[i] * tbSlider.max)
        end
    end
end

function ColorPickerField:Changed(source)
    local value = {}
    for _, tbSlider in pairs(self.sliders) do
        table.insert(value, tbSlider.value / tbSlider.max)
    end
    if self.CalculateColor then
        value = self:CalculateColor(value)
    end
    self:Set(value, source)
end

function ColorPickerField:init(field)
    self.trackbarHeight = 25
    self.trackbarWidth  = 300
    self:super('init', field)

    self.sliders = {}
    self.height = 0
    for i, slider in pairs(field.colorSliders) do
        local tbSlider = self:AddColorTrackbar({
            y = self.height,
            x = #field.colorSliders * (self.trackbarHeight + 10),
            height = self.trackbarHeight,
            width  = self.trackbarWidth,
            background = slider.background,
            color = slider.color or {1, 1, 1, 1},
            max = slider.max or 256,
        })
        tbSlider.OnChange = {
            function()
                self:Changed(tbSlider)
            end
        }
        tbSlider.MouseDown = function(...)
            self.ev:_OnStartChange(self.name)
            local result = Trackbar.MouseDown(...)
            if not result then
                self.ev:_OnEndChange(self.name)
            end
            return result
        end
        tbSlider.MouseUp = function(...)
            self.ev:_OnEndChange(self.name)
            return Trackbar.MouseUp(...)
        end
        self.height = self.height + self.trackbarHeight + 10
        table.insert(self.sliders, tbSlider)
    end

    self.imValue = Image:New {
        color       = {1, 1, 1, 1},
        x           = 5,
        y           = 5,
        height      = self.height - 10,
        width       = self.height - 10,
        keepAspect  = false,
        file        = SB_IMG_DIR .. "color_picker/texture.png",
        color       = {1, 1, 1, 1},
    }
    local bkg = Image:New {
        color       = {1, 1, 1, 1},
        x           = 5,
        y           = 5,
        height      = self.height - 10,
        width       = self.height - 10,
        keepAspect  = false,
        file        = SB_IMG_DIR .. "color_picker/bkg_big.png",
        color       = {1, 1, 1, 1},
    }
    self.components = { self.imValue, bkg }
    for _, tbSlider in pairs(self.sliders) do
        table.insert(self.components, tbSlider)
    end
end

function ColorPickerField:AddColorImage(tbl)
    return Image:New(Table.Merge({
        parent    = self.window,
        file      = SB_IMG_DIR .. "color_picker/texture.png",
        color     = {1, 1, 1, 1},
    }, tbl))
end

function ColorPickerField:AddColorTrackbar(tbl)
    return Trackbar:New(Table.Merge({
        parent       = self.window,
        color        = tbl.color,
        ThumbImage   = SB_IMG_DIR .. "color_picker/trackbar_thumb.png",
        children = {
            Image:New {
                color       = tbl.color,
                x           = 0,
                y           = 0,
                keepAspect  = false;
                width       = "100%",
                height      = "100%",
                file        = tbl.background,
            },
        },
    }, tbl))
end
