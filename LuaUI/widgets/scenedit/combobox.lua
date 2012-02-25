--//=============================================================================
local Chili
Chili = WG.Chili
	
ComboBox = Chili.StackPanel:Inherit {
  classname = "combobox",
  defaultWidth  = 70,
  defaultHeight = 20,
  resizeItems = false,
  itemMargin    = {0, 0, 0, 0},
  itemPadding   = {0, 0, 0, 0},
  items = {},
  selected = nil,
  _firstInvocation = true,
  padding = {0, 0, 0, 0},
}
	
	
local this = ComboBox
local inherited = this.inherited

function ComboBox:New(obj)
  if #obj.items > 0 then
    obj.children = { 
      Chili.Button:New {
          caption = obj.items[1],
          width = '100%',
          height = '100%',
          itemMargin    = {0, 0, 0, 0},
          itemPadding    = {0, 0, 0, 0},
        }
    }
  end
  obj = inherited.New(self,obj)
  if obj.selected == nil then
      obj.selected = 1
  end
  if obj.selected > 0 then
      obj:Select(obj.selected)
  end
  return obj
end

function ComboBox:Select(item)
  if (type(item)=="number") then
    self.selected = item
    self.children[1].caption = self.items[item]
    self:SelectItem(item)
    self.children[1]:Invalidate()
    self:Invalidate()
  else
    self:SelectItem(1)
  end
end

function ComboBox:Close()
    if self._dropDownWindow ~= nil then
        self._dropDownWindow:Dispose()
        self._dropDownWindow = nil
    end
end

function ComboBox:AddSelfListeners()
  parent = self.parent
  while parent ~= nil and parent.classname ~= 'screen' do
    table.insert(parent.OnDispose, function() self:Close() end)
    table.insert(parent.OnClick, function() self:Close() end)
    table.insert(parent.OnDblClick, function()  self:Close() end)
    table.insert(parent.OnMouseDown, function() self:Close() end)
    table.insert(parent.OnMouseUp, function() self:Close() end)
    table.insert(parent.OnMouseMove, function() self:Close() end)
    table.insert(parent.OnMouseWheel, function() self:Close() end)
    parent = parent.parent
  end
end

function ComboBox:MouseDown(...)
  self._down = true
  self.state = 'pressed'

  local screen0 = self
  --local sx, sy = self:LocalToScreen(self.x, self.y)
  -- TODO: this should work ^^, but it doesn't
  local sx = self.x
  local sy = self.y
  while screen0.parent ~= nil do
      screen0 = screen0.parent
      sx = sx + screen0.x
      sy = sy + screen0.y 
  end
  sy = sy + self.height + 10
  sx = sx + 10

  if self._dropDownWindow == nil then
      if self._firstInvocation then
          self._firstInvocation = false 
          self:AddSelfListeners()
      end
      labels = {}
      largestStr = 0
      labelHeight = 20
      for i = 1, #self.items do
          largestStr = math.max(largestStr, #self.items[i])
          table.insert(labels, 
            Chili.Button:New {
                caption = self.items[i],
                width = '100%',
                height = labelHeight,
                OnMouseUp = { function() 
                    self:Select(i) 
                    self._dropDownWindow:Dispose()
                    self._dropDownWindow = nil
                end }
            })
      end
      estimatedWidth = 20 + largestStr * 10
      estimatedWidth = math.min(estimatedWidth, 500)
      estimatedWidth = math.max(estimatedWidth, self.width)
      dropDownWindow = Chili.Window:New {
          parent = screen0,
          clientWidth = estimatedWidth,
          clientHeight = 200,
          resizable = false,
          draggable = false,
          x = sx,
          y = sy,
          backgroundColor = {0.8,0.8,0.8,0.9},
            children = {
                Chili.ScrollPanel:New {
                    x = 0,
                    y = 0,
                    right = 0,
                    bottom = 0,
                    horizontalScrollBar = false,
                    children = {
                        Chili.StackPanel:New {
                            orientation = 'horizontal',
                            width = '100%',
                            height = labelHeight * #labels,
                            resizeItems = false,
                            padding = {0,0,0,0},
                            itemPadding = {0,0,0,0},
                            itemMargin = {0,0,0,0},
                            children = labels,
                        },
                    },
                }
            }
        }
      self._dropDownWindow = dropDownWindow
  end

  inherited.MouseDown(self, ...)
  self:Invalidate()
  return self
end

function ComboBox:MouseUp(...)
  if (self._down) then
    self._down = false
    self.state = 'normal'
    inherited.MouseUp(self, ...)
    self:Invalidate()
    return self
  end
end
