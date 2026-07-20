"""Where things are on screen.

Every scenario measures from the same two landmarks, so a layout change is fixed
in one place rather than in twenty magic numbers.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Final

from x11 import window_geometry

if TYPE_CHECKING:
    from runner import E2ERun

# The editor panel is pinned to the right at this width; modals are 480dp wide,
# centred in the area left of it.
PANEL_WIDTH = 500

# The editor shell, measured from the panel's top-left corner.
TAB_Y = 35
EDITOR_BUTTON_Y = 88
ACTION_Y = 217

# Tab centres, as offsets from the panel's left edge.
TAB_X = {"objects": 42, "map": 110, "env": 180, "misc": 258}

# Field-row geometry, measured in the running Rust panel: a row is 30dp tall
# with a 9dp gap, so consecutive rows in a block sit 39dp apart. Blocks are
# anchored on their first row's centre; a section header between blocks adds
# ~23dp on top of the row pitch. Keep coordinates as `anchor + ROW * i` so a
# layout shift is fixed by editing one anchor, not every row.
ROW = 39

# Column centres: full-width rows, and the halves/thirds of grouped rows.
COL_FULL = 250
HALF = (92, 370)
THIRD = (92, 250, 420)

# Each editor button's centre. Prefer these semantic names to matching a button
# by its ordinal; tab order is presentation detail and changes more often than
# the editor being exercised by a test.
EDITORS: Final = {
    "objects": {"units": 38, "features": 110, "properties": 197, "collision": 270},
    "map": {"terrain": 38, "texture": 110, "metal": 182, "grass": 254, "settings": 326},
    "env": {"lighting": 38, "sky": 110, "water": 182},
    "misc": {"info": 38, "teams": 110, "diplomacy": 182},
    "dev": {"gallery": 40},
}

# Fixed controls in Objects -> Features, Properties, and Collision. Values are
# `(x, y)` offsets from the panel's left edge.
OBJECTS: Final = {
    "add": (54, ACTION_Y),
    "brush": (134, ACTION_Y),
    "feature_type": (104, 336),
    "feature_terrain": (104, 375),
    # The first cell is `geovent`, which has no selectable model. The first
    # tree is the next cell in the unfiltered grid. Keep that semantic choice
    # here so object scenarios never silently arm the default geovent.
    "feature_search": (180, 400),
    "feature_first_tree": (190, 470),
    "feature_amount": (120, 757),
    "property_pos_x": (58, 241),
    "collision_blocking": (100, 664),
    "collision_type": (200, 231),
    "collision_scale_x": (60, 339),
    "collision_shape": (110, 190),
}

ENV_LIGHTING_NUMBERS: Final = (
    ("dirX", (THIRD[0], 280), "0.25"),
    ("dirY", (THIRD[1], 280), "0.35"),
    ("dirZ", (THIRD[2], 280), "0.75"),
    ("groundShadowDensity", (100, 382), "0.65"),
    ("modelShadowDensity", (100, 483), "0.55"),
)
ENV_LIGHTING_COLORS: Final = (
    ("groundDiffuseColor", (THIRD[0], 343), 900),
    ("groundAmbientColor", (THIRD[1], 343), 880),
    ("groundSpecularColor", (THIRD[2], 343), 920),
    ("unitDiffuseColor", (THIRD[0], 444), 940),
    ("unitAmbientColor", (THIRD[1], 444), 860),
    ("unitSpecularColor", (THIRD[2], 444), 900),
)
COLOR_PICKER: Final = {
    "sample_y": 300,
    "team_hue": (220, 255),
    "team_sample_x": 900,
}
ENV_SKY_COLORS: Final = (
    ("sunColor", (THIRD[0], 210), 900),
    ("skyColor", (THIRD[1], 210), 930),
    ("cloudColor", (THIRD[2], 210), 870),
    ("fogColor", (THIRD[0], 311), 950),
)
ENV_SKY_NUMBERS: Final = (
    ("fogStart", (THIRD[1], 311), "0.2"),
    ("fogEnd", (THIRD[2], 311), "0.85"),
)
ENV_WATER_NUMBERS: Final = (
    ("numTiles", (HALF[1], 210), "6"),
    ("perlinStartFreq", (HALF[0], 311), "9"),
    ("perlinLacunarity", (HALF[1], 311), "4"),
    ("perlinAmplitude", (HALF[0], 311 + ROW), "0.7"),
    ("diffuseFactor", (HALF[0], 413), "0.8"),
    ("specularFactor", (HALF[0], 475), "1.2"),
    ("specularPower", (HALF[1], 475), "24"),
    ("ambientFactor", (HALF[0], 475 + ROW * 2), "0.9"),
    ("fresnelMin", (HALF[0], 616), "0.25"),
    ("fresnelMax", (HALF[1], 616), "0.75"),
    ("fresnelPower", (HALF[0], 616 + ROW), "5"),
    ("reflectionDistortion", (HALF[0], 616 + ROW * 2), "1.1"),
    ("blurBase", (HALF[0], 756), "2.2"),
    ("blurExponent", (HALF[1], 756), "1.7"),
    ("repeatX", (HALF[0], 943 + ROW), "2"),
    ("repeatY", (HALF[1], 943 + ROW), "3"),
)
ENV_WATER_COLORS: Final = (
    ("diffuseColor", (HALF[1], 413), 900),
    ("specularColor", (150, 475 + ROW), 930),
    ("planeColor", (HALF[1], 818), 870),
)
ENV_WATER_ASSETS: Final = (
    ("normalTexture", (87, 249)),
    ("foamTexture", (HALF[1], 881)),
    ("texture", (60, 943)),
)

# Fixed controls in Map editors.
MAP: Final = {
    # First terrain-pattern cell in the physical X11 window. The review images
    # are downscaled, so do not read their coordinates directly.
    "terrain_pattern": (42, 400),
    "texture_pattern": (42, 380),
    "saved_brush_add": (42, 335),
    "saved_brush_pattern": (52, 700),
    "void_water": (100, 656),
    "void_ground": (100, 656 + ROW),
    "dnts_diffuse_alpha": (100, 656 + ROW * 2),
    "detail_texture": (70, 241),
    "texture_specular": (140, 241 + ROW),
    "texture_reflection": (140, 241 + ROW * 2),  # the Emission entry
    "texture_direction": (200, 790),
    "texture_rect_pattern": (112, 448),
    "saved_brush_rect": (112, 778),
    "settings_map_size": (142, 525),
    # Terrain's fields start under its pattern grid; Metal/Grass have a
    # "Pattern" section first, so their block sits one header lower.
    "terrain_size": (92, 634),
    "terrain_rotation": (92, 634 + ROW),
    "terrain_strength": (92, 634 + ROW * 2),
    "terrain_height": (92, 634 + ROW * 3),
    "metal_size": (92, 655),
    "metal_rotation": (92, 655 + ROW),
    "metal_amount": (92, 655 + ROW * 2),
    "splat_scale_1": (92, 795), "splat_scale_2": (320, 795),
    "splat_scale_3": (92, 795 + ROW), "splat_scale_4": (320, 795 + ROW),
    "splat_mult_1": (92, 795 + ROW * 2), "splat_mult_2": (320, 795 + ROW * 2),
    "splat_mult_3": (92, 795 + ROW * 3), "splat_mult_4": (320, 795 + ROW * 3),
}
MAP_ACTIONS: Final = {
    "terrain_add": (42, ACTION_Y), "terrain_set": (112, ACTION_Y),
    "terrain_smooth": (188, ACTION_Y), "texture_paint": (42, ACTION_Y),
    "texture_filter": (112, ACTION_Y), "texture_dnts": (188, ACTION_Y),
    "texture_void": (260, ACTION_Y),
}
MAP_TERRAIN_BRUSHES: Final = (
    ("terrain_add", "add", "TerrainShapeModifyCommand"),
    ("terrain_set", "set", "TerrainLevelCommand"),
    ("terrain_smooth", "smooth", "TerrainSmoothCommand"),
)
MAP_TEXTURE_ACTIONS: Final = (
    ("texture_paint", "paint", "paint"),
    ("texture_filter", "filter", "blur"),
    ("texture_void", "void", "void"),
)

# Fixed controls in Environment editors.
ENV: Final = {
    "lighting_shadow_mode": (180, 241),
    "sky_skybox": (64, 249),
    "water_forced_rendering": (100, 210),
    "water_plane": (84, 818),
    "water_shore_waves": (84, 881),
    "terrain_pattern": (42, 365),
    "terrain_height": (92, 751),
    "terrain_strength": (92, 712),
    "terrain_size": (92, 634),
    "terrain_set": (112, ACTION_Y),
}

# Fixed controls in Misc and the panel-wide action toolbar.
MISC: Final = {
    "info_name": (250, 207),
    "team_add": (38, ACTION_Y),
    "team_edit_first": (425, 333),
    "team_remove_first": (468, 333),
}
MISC_INFO_FIELDS: Final = (
    ((250, 207), "Verified Scenario"),
    ((250, 207 + ROW), "All metadata fields"),
    ((250, 207 + ROW * 2), "2.5"),
    ((250, 207 + ROW * 3), "Native UI"),
)
# Rows inside the team-edit dialog: Metal/Storage, then (after the Energy
# section) Energy/Storage, Colour, Start X/Z at the shared row pitch. The
# dialog's halves sit at x=120 and x=390.
TEAM_NUMBERS: Final = (
    ((120, 345), "125"), ((390, 345), "500"),
    ((120, 408), "250"), ((390, 408), "750"),
    ((120, 408 + ROW * 2), "100"), ((390, 408 + ROW * 2), "200"),
)
# The shell action toolbar is a fixed nine-icon row.  Keep the action names
# here, rather than making tests infer an icon's position from its ordinal: the
# action order is UI presentation, while e2e scenarios care about the command
# being invoked.  Centres are measured in the running Rust panel.
TOOLBAR: Final = {
    "new_project": (34, 165),
    "load": (74, 165),
    "import": (114, 165),
    "save": (154, 165),
    "save_as": (194, 165),
    "export": (234, 165),
    "copy": (274, 165),
    "cut": (314, 165),
    "paste": (354, 165),
}

# Modal controls are offsets from `dialog_left()`, not fixed screen positions.
DIALOG: Final = {
    "color_sample": (110, 350),
    "color_ok": (350, 473),
    "color_ok_compact": (348, 473),
    "color_ok_native": (344, 472),
    "color_gradient_start": (20, 422),
    "color_gradient_end": (185, 257),
    "asset_up": (40, 267),
    "asset_first_cell": (50, 335),
    "asset_first_cell_gallery": (52, 333),
    "file_up": (38, 267),
    "file_first_cell": (57, 333),
    "new_project_name": (240, 267),
    "new_project_size_x": (110, 346),
    "new_project_size_y": (350, 346),
    "new_project_create": (347, 407),
    "file_name": (240, 590),
    "file_type": (240, 629),
    "asset_core_cell": (104, 360),
    "asset_ok": (343, 603),
    "asset_ok_gallery": (347, 602),
    "texture_new": (40, 270),
    "texture_existing": (110, 270),
    "texture_create": (70, 320),
    "texture_width": (110, 267),
    "texture_height": (350, 267),
    "team_name": (300, 265),
    "team_ai": (150, 307),
    "team_color": (150, 447),
    "team_ok": (474, 587),
    "skybox_ok": (344, 472),
    "skybox_cancel": (430, 603),
    "skybox_first_cell": (50, 335),
    "skybox_drag_origin": (20, 422),
}

# The visual-only Dev gallery is still a real editor; keeping its field map
# here means the gallery tracks layout changes with the production scenarios.
GALLERY: Final = {
    "dev_tab_x": 328,
    "string": (250, 238),
    "empty": (250, 238 + ROW),
    "number": (80, 343),
    "bounded": (80, 343 + ROW),
    "precise": (80, 343 + ROW * 2),
    "bool_on": (100, 484),
    "bool_off": (100, 484 + ROW),
    "choice": (200, 585),
    "color": (149, 647),
    "asset": (60, 647 + ROW + 1),
    "group_xyz_y": 748,
    "group_second_x": THIRD[1],
    "group_third_x": THIRD[2],
    "tooltip_parking": (400, 900),
}

# Positions used to park a pointer outside an open panel/brush preview. The
# window-relative variant is for controls anchored to the status strip.
PARK_PANEL: Final = (450, 1000)
PARK_PANEL_LOW: Final = (450, 1100)
STATUS: Final = {"height_from_bottom": 92}

# Console and the shell's full-frame smoke test also exercise native widgets
# outside the right panel. These stay window-relative, but their geometry is
# still defined once here.
DEV_CONSOLE: Final = {
    "selection_drag_start": (100, 965),
    "selection_drag_end": (600, 1010),
    "selection_cursor": (300, 985),
    "clear_x": 30,
    "problems_x": 300,
    "status_button_first_x": 23,
    "status_button_step": 56,
    "status_button_y_from_bottom": 40,
    "copy_drag_start_x": 60,
    "copy_drag_end_x": 700,
}
CHONSOLE: Final = {
    "left_fraction": 0.26,
    "top_fraction": 0.245,
    "width_fraction": 0.41,
    "height_fraction": 0.4,
    "header_height": 38,
    "row_height": 27,
    "row_inset_x": 40,
    "header_hover_y": 18,
    "scrollbar_inset_x": 5,
    "scrollbar_width": 12,
    "scrollbar_height": 380,
    "scrollbar_thumb_inset": 7,
    "scrollbar_thumb_start_y": 12,
    "scrollbar_hover_y": 80,
    "scrollbar_drag_end_y": 300,
}


def status_button_point(width: int, height: int, index: int) -> tuple[int, int]:
    """Centre of the Undo, Redo, or Clear button in the status strip."""
    # `#editor-status` ends at the 500dp editor panel. Its command toolbar is
    # right-anchored (255dp) in that remaining area. Do not derive this from
    # the 60%-wide metrics column: that placed clicks in the metrics panel on
    # widescreen runs as soon as the status layout was completed.
    button_outer = 46  # 34dp content + 5dp padding on each side + 1dp borders.
    toolbar_width = button_outer * 3 + 10 * 2
    toolbar_left = width - PANEL_WIDTH - 255 - toolbar_width
    return (
        toolbar_left + button_outer // 2 + (button_outer + 10) * index,
        height - DEV_CONSOLE["status_button_y_from_bottom"],
    )


def dev_console_toolbar_y(height: int) -> int:
    return height - 108


def chonsole_suggestion_box(width: int, height: int) -> tuple[int, int, int, int]:
    return (
        int(width * CHONSOLE["left_fraction"]),
        int(height * CHONSOLE["top_fraction"]),
        int(width * CHONSOLE["width_fraction"]),
        int(height * CHONSOLE["height_fraction"]),
    )


def chonsole_row_point(width: int, height: int, index: int) -> tuple[int, int]:
    left, top, _width, _height = chonsole_suggestion_box(width, height)
    return (
        left + CHONSOLE["row_inset_x"],
        top + CHONSOLE["header_height"] + 4 + 12 + index * CHONSOLE["row_height"],
    )


def chonsole_header_point(width: int, height: int) -> tuple[int, int]:
    left, top, _width, _height = chonsole_suggestion_box(width, height)
    return left + CHONSOLE["row_inset_x"], top + CHONSOLE["header_hover_y"]


def chonsole_scrollbar_point(width: int, height: int) -> tuple[int, int]:
    _left, top, _box_width, _box_height = chonsole_suggestion_box(width, height)
    return (
        int(width * (CHONSOLE["left_fraction"] + CHONSOLE["width_fraction"]))
        - CHONSOLE["scrollbar_inset_x"],
        top + CHONSOLE["header_height"] + CHONSOLE["scrollbar_hover_y"],
    )


def panel_left(run_state: E2ERun) -> int:
    assert run_state.window is not None
    width, _height = window_geometry(run_state.window)
    return width - PANEL_WIDTH


def dialog_left(run_state: E2ERun) -> int:
    assert run_state.window is not None
    width, _height = window_geometry(run_state.window)
    return width // 2 - 490


def window_size(run_state: E2ERun) -> tuple[int, int]:
    assert run_state.window is not None
    return window_geometry(run_state.window)


def dropdown_option(point: tuple[int, int], index: int) -> tuple[int, int]:
    """The centre of the nth option of a drop-down opened at `point`.

    The popup lists options directly under the select row; picking by click
    keeps the keyboard out of it (loose Down/Return keys land in the chonsole,
    which opens over the run).
    """
    return point[0], point[1] + 33 + 35 * index


def editor_button_x(index: int) -> int:
    """The nth editor button in the open tab, as an offset from the panel."""
    return 38 + 72 * index


def editor_point(left: int, tab: str, editor: str) -> tuple[int, int]:
    """The centre of a named editor button in a named tab."""
    return left + EDITORS[tab][editor], EDITOR_BUTTON_Y


def panel_point(left: int, point: tuple[int, int]) -> tuple[int, int]:
    """Translate one of the panel-local points above into window coordinates."""
    return left + point[0], point[1]


def dialog_point(run_state: E2ERun, point: tuple[int, int]) -> tuple[int, int]:
    """Translate a dialog-local point into window coordinates."""
    return dialog_left(run_state) + point[0], point[1]
