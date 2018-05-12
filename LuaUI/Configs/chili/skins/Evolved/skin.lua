--//=============================================================================
--// Skin

local skin = {
  info = {
    name    = "Evolved",
    version = "0.3",
    author  = "jK",
  }
}

--//=============================================================================
--//

skin.general = {
  focusColor  = {0.14, 0.50, 0.73, 0.7},
  borderColor = {1.0, 1.0, 1.0, 1.0},

  font = {
    font    = SKINDIR .. "fonts/n019003l.pfb",
    color        = {1,1,1,1},
    outlineColor = {0.05,0.05,0.05,0.9},
    outline = false,
    shadow  = true,
    size    = 14,
  },

  --padding         = {5, 5, 5, 5}, --// padding: left, top, right, bottom
}


skin.icons = {
  imageplaceholder = ":cl:placeholder.png",
}

local buttonPressedColor = {4, 4, 4, 4}
function DrawMyButton(obj, ...)
    if obj.state and obj.state.pressed then
        local oldColor = obj.backgroundColor
        obj.backgroundColor = buttonPressedColor
        DrawButton(obj, ...)
        obj.backgroundColor = oldColor
    else
        DrawButton(obj, ...)
    end
end

skin.button = {
  TileImageBK = ":cl:tech_button_bright_small_bk.png",
  TileImageFG = ":cl:tech_button_bright_small_fg.png",
  tiles = {20, 14, 20, 14}, --// tile widths: left,top,right,bottom
  padding = {10, 10, 10, 10},

  backgroundColor = {0, 0, 0, 0.7},
  borderColor = {1,1,1,0},

  DrawControl = DrawMyButton,
}

function DrawMyToggleButton(obj, ...)
    if obj.checked then
        local oldColor = obj.backgroundColor
        obj.backgroundColor = buttonPressedColor
        DrawButton(obj, ...)
        obj.backgroundColor = oldColor
    else
        DrawButton(obj, ...)
    end
    -- Draw custom toggle button (largely based on DrawCheckbox)
    local boxSize = obj.boxsize
    local cx, cy, cw, ch = unpack4(obj.clientArea)
    local x = cx + cw      - boxSize
    local y = cy + ch*0.5 - boxSize*0.5
    local w = boxSize
    local h = boxSize

    local skLeft,skTop,skRight,skBottom = unpack4(obj.tilesCheckbox)

    local TileImage, color
    if obj.checked then
        TileImage = obj.TileImageChecked
        color = obj.checkedColor
    else
        TileImage = obj.TileImageUnchecked
        color = obj.uncheckedColor
    end
    gl.Color(color)
    TextureHandler.LoadTexture(0, TileImage, obj)
      local texInfo = gl.TextureInfo(TileImage) or {xsize=1, ysize=1}
      local tw,th = texInfo.xsize, texInfo.ysize

      gl.BeginEnd(GL.TRIANGLE_STRIP, _DrawTiledTexture, x,y,w,h, skLeft,skTop,skRight,skBottom, tw,th, 0)
    gl.Texture(0,false)
end

skin.toggle_button = {
  -- TileImageFG = ":cl:tech_checkbox_checked.png",
  -- TileImageBK = ":cl:tech_checkbox_unchecked.png",
  -- tiles       = {3,3,3,3},
  -- boxsize     = 13,

  TileImageBK = ":cl:tech_button_bright_small_bk.png",
  TileImageFG = ":cl:tech_button_bright_small_fg.png",

  tiles = {20, 14, 20, 14}, --// tile widths: left,top,right,bottom
  padding = {10, 10, 10, 10},

  backgroundColor = {0, 0, 0, 0.7},
  borderColor = {1,1,1,0},

  align = 'left',

  -- Checkbox specific properties
  TileImageChecked = ":cl:little_blurred_circle.png",
  TileImageUnchecked = ":cl:little_blurred_circle_empty.png",
  tilesCheckbox = {0.1,0.1,0.1,0.1},
  uncheckedColor = {0, 0, 0, 1},
  --checkedColor = {0.14, 0.4, 0.8, 1.0},
  checkedColor = {0, 1, 0, 1.0},
  boxsize = 15,

  DrawControl = DrawMyToggleButton,
}

function DrawMyProgressButton(obj, ...)
    if obj.state and obj.state.pressed then
        local oldColor = obj.backgroundColor
        obj.backgroundColor = buttonPressedColor
        DrawButton(obj, ...)
        obj.backgroundColor = oldColor

        if obj.__progress then
            local w = obj.width
            local h = obj.height
            local skLeft,skTop,skRight,skBottom = unpack4(obj.tiles)

            gl.Color(obj.progressColor)
            TextureHandler.LoadTexture(0,obj.TileImageBK,obj)
              local texInfo = gl.TextureInfo(obj.TileImageBK) or {xsize=1, ysize=1}
              local tw,th = texInfo.xsize, texInfo.ysize

              gl.ClipPlane(1, -1,0,0, w * obj.__progress)
              gl.BeginEnd(GL.TRIANGLE_STRIP, _DrawTiledTexture, 0,0,w,h, skLeft,skTop,skRight,skBottom, tw,th, 0)
              gl.ClipPlane(1, false)
            gl.Texture(0,false)
        end
    else
        DrawButton(obj, ...)
    end
end

skin.progress_button = {
  -- TileImageFG = ":cl:tech_checkbox_checked.png",
  -- TileImageBK = ":cl:tech_checkbox_unchecked.png",
  -- tiles       = {3,3,3,3},
  -- boxsize     = 13,

  TileImageBK = ":cl:tech_button_bright_small_bk.png",
  TileImageFG = ":cl:tech_button_bright_small_fg.png",

  tiles = {20, 14, 20, 14}, --// tile widths: left,top,right,bottom
  padding = {10, 10, 10, 10},

  backgroundColor = {0, 0, 0, 0.7},
  borderColor = {1,1,1,0},


  -- Checkbox specific properties
  -- TileImageBK = ":cl:tech_button_bright_small_bk.png",
  -- TileImageFG = ":cl:tech_button_bright_small_fg.png",

  progressColor = {0, 0.4, 0.8, 1.0},

  DrawControl = DrawMyProgressButton,
}

skin.button_large = {
  TileImageBK = ":cl:tech_button_bk.png",
  TileImageFG = ":cl:tech_button_fg.png",
  tiles = {120, 60, 120, 60}, --// tile widths: left,top,right,bottom
  padding = {10, 10, 10, 10},

  backgroundColor = {0, 0, 0, 0.7},
  focusColor  = {0.94, 0.50, 0.23, 0.7},
  borderColor = {1,1,1,0},

  DrawControl = DrawMyButton,
}

skin.button_highlight = {
  TileImageBK = ":cl:tech_button_bright_small_bk.png",
  TileImageFG = ":cl:tech_button_bright_small_fg.png",
  tiles = {20, 14, 20, 14}, --// tile widths: left,top,right,bottom
  padding = {10, 10, 10, 10},

  backgroundColor = {0.2, 0.25, 0.35, 0.7},
  focusColor  = {0.3, 0.375, 0.525, 0.5},
  borderColor = {1,1,1,0},

  DrawControl = DrawMyButton,
}

skin.button_square = {
  TileImageBK = ":cl:tech_button_action_bk.png",
  TileImageFG = ":cl:tech_button_action_fg.png",
  tiles = {22, 22, 22, 22}, --// tile widths: left,top,right,bottom
  padding = {10, 10, 10, 10},

  backgroundColor = {0, 0, 0, 0.7},
  focusColor  = {0.94, 0.50, 0.23, 0.4},
  borderColor = {1,1,1,0},

  DrawControl = DrawMyButton,
}

skin.option_button = {
  TileImageBK = ":cl:tech_button_bright_small_bk.png",
  TileImageFG = ":cl:tech_button_bright_small_fg.png",
  tiles = {20, 14, 20, 14}, --// tile widths: left,top,right,bottom
  padding = {10, 10, 10, 10},

  backgroundColor = {0.1, 0.8, 1.0, 0.7},
  focusColor      = {0.1, 0.8, 1.0, 1.0},
  borderColor     = {0.21, 0.53, 0.60, 0.15},

  DrawControl = DrawMyButton,
}

skin.positive_button = {
  TileImageBK = ":cl:tech_button_bright_small_bk.png",
  TileImageFG = ":cl:tech_button_bright_small_fg.png",
  tiles = {20, 14, 20, 14}, --// tile widths: left,top,right,bottom
  padding = {10, 10, 10, 10},

  backgroundColor = {0.36, 0.72, 0.36, 0.7},
  focusColor      = {0.36, 0.72, 0.36, 1.0},
  borderColor     = {0.98, 0.48, 0.26, 0.15},

  DrawControl = DrawMyButton,
}

skin.negative_button = {
  TileImageBK = ":cl:tech_button_bright_small_bk.png",
  TileImageFG = ":cl:tech_button_bright_small_fg.png",
  tiles = {20, 14, 20, 14}, --// tile widths: left,top,right,bottom
  padding = {10, 10, 10, 10},

  backgroundColor = {0.85, 0.05, 0.25, 0.7},
  focusColor      = {0.85, 0.05, 0.25, 1.0},
  borderColor     = {0.85, 0.05, 0.25, 0.15},

  DrawControl = DrawMyButton,
}

skin.collapse_panel_header = {
  TileImageBK = ":cl:tech_button_bright_small_bk.png",
  TileImageFG = ":cl:tech_button_bright_small_fg.png",
  tiles = {20, 14, 20, 14}, --// tile widths: left,top,right,bottom
  padding = {10, 10, 10, 10},

  backgroundColor = {0.4, 0.4, 0.4, 0.8},
  focusColor      = {0.4, 0.4, 0.4, 1.0},
  borderColor     = {0.85, 0.05, 0.25, 0.0},

  DrawControl = DrawMyButton,
}

skin.combobox = {
	TileImageBK = ":cl:combobox_ctrl.png",
	TileImageFG = ":cl:combobox_ctrl_fg.png",
	TileImageArrow = ":cl:combobox_ctrl_arrow.png",
	tiles   = {22, 22, 48, 22},
	padding = {10, 10, 24, 10},

	backgroundColor = {1, 1, 1, 0.7},
	borderColor = {1,1,1,0},

	DrawControl = DrawComboBox,
}


skin.combobox_window = {
	clone     = "window";
	TileImage = ":cl:combobox_wnd.png";
	tiles     = {2, 2, 2, 2};
	padding   = {4, 3, 3, 4};
}


skin.combobox_scrollpanel = {
	clone       = "scrollpanel";
	borderColor = {1, 1, 1, 0};
	padding     = {0, 0, 0, 0};
}


skin.combobox_item = {
	clone       = "button";
	borderColor = {1, 1, 1, 0};
}


skin.checkbox = {
  TileImageFG = ":cl:tech_checkbox_checked.png",
  TileImageBK = ":cl:tech_checkbox_unchecked.png",
  tiles       = {3,3,3,3},
  boxsize     = 13,

  DrawControl = DrawCheckbox,
}

skin.editbox = {
  hintFont = table.merge({color = {1,1,1,0.7}}, skin.general.font),

  backgroundColor = {0.1, 0.1, 0.1, 0},
  cursorColor     = {1.0, 0.7, 0.1, 0.8},

  focusColor  = {1, 1, 1, 1},
  borderColor = {1, 1, 1, 0.6},

  TileImageBK = ":cl:panel2_bg.png",
  TileImageFG = ":cl:editbox_border.png",
  tiles       = {2, 2, 2, 2},
  cursorFramerate = 1, -- Per second

  DrawControl = DrawEditBox,
}

skin.textbox = {
  hintFont = table.merge({color = {1,1,1,0.7}}, skin.general.font),

  TileImageBK = ":cl:panel2_bg.png",
  bkgndtiles = {14,14,14,14},

  TileImageFG = ":cl:panel2_border.png",
  tiles       = {2, 2, 2, 2},

  borderColor     = {0.0, 0.0, 0.0, 0.0},
  focusColor      = {0.0, 0.0, 0.0, 0.0},

  DrawControl = DrawEditBox,
}

skin.imagelistview = {
  imageFolder      = "folder.png",
  imageFolderUp    = "folder_up.png",

  --DrawControl = DrawBackground,

  colorBK          = {1,1,1,0.3},
  colorBK_selected = {1,0.7,0.1,0.8},

  colorFG          = {0, 0, 0, 0},
  colorFG_selected = {2, 2, 2, 2},

  imageBK  = ":cl:node_selected_bw.png",
  imageFG  = ":cl:node_selected.png",
  tiles    = {9, 9, 9, 9},

  DrawItemBackground = DrawItemBkGnd,
}
--[[
skin.imagelistviewitem = {
  imageFG = ":cl:glassFG.png",
  imageBK = ":cl:glassBK.png",
  tiles = {17,15,17,20},

  padding = {12, 12, 12, 12},

  DrawSelectionItemBkGnd = DrawSelectionItemBkGnd,
}
--]]

skin.panel = {
  TileImageBK = ":cl:tech_button.png",
  TileImageFG = ":cl:empty.png",
  tiles = {2, 2, 2, 2},

  DrawControl = DrawPanel,
}

skin.panel_light = {
  TileImageBK = ":cl:tech_overlaywindow.png",
  TileImageFG = ":cl:empty.png",
  tiles = {2, 2, 2, 2},

  backgroundColor = {0.4, 0.4, 0.4, 0.7},

  DrawControl = DrawPanel,
}

skin.overlay_panel = {
  TileImageBK = ":cl:tech_overlaywindow.png",
  TileImageFG = ":cl:empty.png",
  tiles = {2, 2, 2, 2},

  backgroundColor = {0.1, 0.1, 0.1, 0.7},

  DrawControl = DrawPanel,
}


skin.progressbar = {
  TileImageFG = ":cl:tech_progressbar_full.png",
  TileImageBK = ":cl:tech_progressbar_empty.png",
  tiles       = {10, 10, 10, 10},

  font = {
    shadow = true,
  },

  backgroundColor = {0,0,0,0.5},

  DrawControl = DrawProgressbar,
}

skin.scrollpanel = {
  backgroundColor = {0,0,0,0},

  BorderTileImage = ":cl:panel2_border.png",
  bordertiles = {2, 2, 2, 2},

  BackgroundTileImage = ":cl:panel2_bg.png",
  bkgndtiles = {14,14,14,14},

  TileImage = ":cl:tech_scrollbar.png",
  tiles     = {7,7,7,7},
  KnobTileImage = ":cl:tech_scrollbar_knob.png",
  KnobTiles     = {6,8,6,8},

  HTileImage = ":cl:tech_scrollbar.png",
  htiles     = {7,7,7,7},
  HKnobTileImage = ":cl:tech_scrollbar_knob.png",
  HKnobTiles     = {6,8,6,8},

  KnobColorSelected = {1,0.7,0.1,0.8},

  padding = {5, 5, 5, 0},

  scrollbarSize = 14,
  DrawControl = DrawScrollPanel,
  DrawControlPostChildren = DrawScrollPanelBorder,
}

skin.trackbar = {
  TileImage = ":cn:trackbar.png",
  tiles     = {10, 14, 10, 14}, --// tile widths: left,top,right,bottom

  ThumbImage = ":cl:trackbar_thumb.png",
  StepImage  = ":cl:trackbar_step.png",

  hitpadding  = {4, 4, 5, 4},

  DrawControl = DrawTrackbar,
}

skin.treeview = {
  --ImageNode         = ":cl:node.png",
  ImageNodeSelected = ":cl:node_selected.png",
  tiles = {9, 9, 9, 9},

  ImageExpanded  = ":cl:treeview_node_expanded.png",
  ImageCollapsed = ":cl:treeview_node_collapsed.png",
  treeColor = {1,1,1,0.1},

  DrawNode = DrawTreeviewNode,
  DrawNodeTree = DrawTreeviewNodeTree,
}

skin.window = {
  TileImage = ":c:tech_dragwindow.png",
  --TileImage = ":c:tech_dragwindow_full.png",
  tiles = {2, 2, 2, 2}, --// tile widths: left,top,right,bottom
  padding = {13, 13, 13, 13},
  hitpadding = {4, 4, 4, 4},

  captionColor = {1, 1, 1, 0.45},

  backgroundColor = {0.1, 0.1, 0.1, 0.7},

  boxes = {
    resize = {-21, -21, -10, -10},
    drag = {0, 0, "100%", 10},
  },

  NCHitTest = NCHitTestWithPadding,
  NCMouseDown = WindowNCMouseDown,
  NCMouseDownPostChildren = WindowNCMouseDownPostChildren,
  noClickThrough = true,

  DrawControl = DrawWindow,
  DrawDragGrip = function() end,
  DrawResizeGrip = DrawResizeGrip,
}

skin.sb_window = {
  TileImage = ":c:tech_dragwindow_full.png",
  tiles = {2, 2, 2, 2}, --// tile widths: left,top,right,bottom
  padding = {13, 13, 13, 13},
  hitpadding = {4, 4, 4, 4},

  captionColor = {1, 1, 1, 0.45},

  color = {0.3, 0.3, 0.3, 0.90},
  backgroundColor = {0.1, 0.1, 0.1, 0.7},

  boxes = {
    resize = {-21, -21, -10, -10},
    drag = {0, 0, "100%", 10},
  },

  NCHitTest = NCHitTestWithPadding,
  NCMouseDown = WindowNCMouseDown,
  NCMouseDownPostChildren = WindowNCMouseDownPostChildren,
  noClickThrough = true,

  DrawControl = DrawWindow,
  DrawDragGrip = function() end,
  DrawResizeGrip = DrawResizeGrip,
}

skin.line = {
  TileImage = ":cl:tech_line.png",
  tiles = {0, 0, 0, 0},
  TileImageV = ":cl:tech_line_vert.png",
  tilesV = {0, 0, 0, 0},
  borderColor = {50/255, 125/255, 141/255, 1},
  DrawControl = DrawLine,
}

skin.lineStandOut = {
  TileImage = ":cl:tech_line.png",
  tiles = {0, 0, 0, 0},
  TileImageV = ":cl:tech_line_vert.png",
  tilesV = {0, 0, 0, 0},
  borderColor = {1, 0.2, 0.2, 1},
  DrawControl = DrawLine,
}

skin.tabbar = {
  padding = {3, 1, 1, 0},
}

skin.tabbaritem = {
  -- yes these are reverted, but also a lie (see images), only one is used
  TileImageFG = ":cl:tech_tabbaritem_bk.png",
  TileImageBK = ":cl:tech_tabbaritem_bk.png",
  tiles = {12, 12, 12, 12}, --// tile widths: left,top,right,bottom
  padding = {1, 1, 1, 2},
  -- since it's color multiplication, it's easier to control white color (1, 1, 1) than black color (0, 0, 0) to get desired results
  backgroundColor = {0.3, 0.3, 0.3, 0.5},
  -- actually kill this anyway
  borderColor     = {0, 0, 0, 0},
  focusColor      = {0.46, 0.54, 0.68, 1.0},

  DrawControl = DrawTabBarItem,
}


skin.control = skin.general


--//=============================================================================
--//

return skin
