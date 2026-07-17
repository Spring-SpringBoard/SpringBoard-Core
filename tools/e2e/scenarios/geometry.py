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
TAB_X = {"objects": 42, "map": 110, "env": 180, "misc": 300}

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
    "feature_type": (104, 316),
    "feature_terrain": (104, 358),
    "feature_search": (180, 400),
    "feature_first_tree": (55, 470),
    "feature_amount": (120, 757),
    "property_health": (58, 223),
    "property_pos_x": (58, 241),
    "collision_blocking": (100, 953),
    "collision_type": (200, 231),
    "collision_scale_x": (60, 339),
    "collision_shape": (110, 190),
}

ENV_LIGHTING_NUMBERS: Final = (
    ("dirX", (92, 265), "0.25"),
    ("dirY", (200, 265), "0.35"),
    ("dirZ", (300, 265), "0.75"),
    ("groundShadowDensity", (100, 418), "0.65"),
    ("modelShadowDensity", (100, 570), "0.55"),
)
ENV_LIGHTING_COLORS: Final = (
    ("groundDiffuseColor", (150, 332), 900),
    ("groundAmbientColor", (320, 332), 880),
    ("groundSpecularColor", (150, 375), 920),
    ("unitDiffuseColor", (150, 484), 940),
    ("unitAmbientColor", (320, 484), 860),
    ("unitSpecularColor", (150, 527), 900),
)
COLOR_PICKER: Final = {
    "sample_y": 300,
    "team_hue": (220, 255),
    "team_sample_x": 900,
}
ENV_SKY_COLORS: Final = (
    ("sunColor", (150, 192), 900),
    ("skyColor", (320, 192), 930),
    ("cloudColor", (150, 237), 870),
    ("fogColor", (150, 347), 950),
)
ENV_SKY_NUMBERS: Final = (
    ("fogStart", (260, 347), "0.2"),
    ("fogEnd", (90, 390), "0.85"),
)
ENV_WATER_NUMBERS: Final = (
    ("numTiles", (250, 193), "6"),
    ("perlinStartFreq", (90, 302), "9"),
    ("perlinLacunarity", (250, 302), "4"),
    ("perlinAmplitude", (90, 344), "0.7"),
    ("diffuseFactor", (90, 411), "0.8"),
    ("specularFactor", (90, 477), "1.2"),
    ("specularPower", (250, 477), "24"),
    ("ambientFactor", (90, 563), "0.9"),
    ("fresnelMin", (90, 630), "0.25"),
    ("fresnelMax", (250, 630), "0.75"),
    ("fresnelPower", (90, 673), "5"),
    ("reflectionDistortion", (90, 717), "1.1"),
    ("blurBase", (90, 783), "2.2"),
    ("blurExponent", (250, 783), "1.7"),
    ("repeatX", (90, 1024), "2"),
    ("repeatY", (250, 1024), "3"),
)
ENV_WATER_COLORS: Final = (
    ("diffuseColor", (320, 411), 900),
    ("specularColor", (150, 520), 930),
    ("planeColor", (220, 849), 870),
)
ENV_WATER_ASSETS: Final = (
    ("normalTexture", (87, 237)),
    ("foamTexture", (180, 914)),
    ("texture", (60, 980)),
)

# Fixed controls in Map editors.
MAP: Final = {
    "terrain_pattern": (42, 365),
    "texture_pattern": (42, 380),
    "saved_brush_add": (42, 335),
    "saved_brush_pattern": (42, 665),
    "void_water": (100, 677),
    "void_ground": (100, 720),
    "dnts_diffuse_alpha": (100, 763),
    "detail_texture": (70, 220),
    "texture_specular": (140, 518),
    "texture_reflection": (140, 562),
    "texture_direction": (200, 783),
    "texture_rect_pattern": (112, 448),
    "saved_brush_rect": (112, 748),
    "settings_map_size": (142, 525),
    "terrain_size": (92, 604),
    "terrain_rotation": (92, 646),
    "terrain_strength": (92, 690),
    "terrain_height": (92, 732),
    "metal_size": (92, 625),
    "metal_rotation": (92, 668),
    "metal_amount": (92, 711),
    "splat_scale_1": (92, 834), "splat_scale_2": (260, 834),
    "splat_scale_3": (92, 878), "splat_scale_4": (260, 878),
    "splat_mult_1": (92, 922), "splat_mult_2": (260, 922),
    "splat_mult_3": (92, 966), "splat_mult_4": (260, 966),
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
    "lighting_shadow_mode": (180, 222),
    "sky_skybox": (64, 280),
    "water_forced_rendering": (138, 193),
    "water_plane": (84, 849),
    "water_shore_waves": (84, 914),
    "terrain_pattern": (42, 365),
    "terrain_height": (92, 741),
    "terrain_strength": (92, 692),
    "terrain_size": (92, 612),
    "terrain_set": (112, ACTION_Y),
}

# Fixed controls in Misc and the panel-wide action toolbar.
MISC: Final = {
    "info_name": (200, 190),
    "info_color": (110, 310),
    "team_add": (38, ACTION_Y),
    "team_edit_first": (425, 313),
    "team_remove_first": (468, 347),
}
MISC_INFO_FIELDS: Final = (
    ((200, 190), "Verified Scenario"),
    ((200, 233), "All metadata fields"),
    ((200, 276), "2.5"),
    ((200, 318), "Native UI"),
)
TEAM_NUMBERS: Final = (
    ((120, 350), "125"), ((260, 350), "500"),
    ((120, 416), "250"), ((260, 416), "750"),
    ((120, 501), "100"), ((260, 501), "200"),
)
TOOLBAR: Final = {"new_project": (24, 150), "export": (239, 150)}

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
    "asset_core_cell": (104, 360),
    "asset_ok": (343, 603),
    "asset_ok_gallery": (347, 602),
    "texture_new": (40, 270),
    "texture_existing": (110, 270),
    "team_name": (292, 269),
    "team_ai": (150, 304),
    "team_color": (153, 459),
    "team_ok": (472, 609),
    "skybox_ok": (344, 472),
    "skybox_cancel": (430, 603),
    "skybox_first_cell": (50, 335),
    "skybox_drag_origin": (20, 422),
}

# The visual-only Dev gallery is still a real editor; keeping its field map
# here means the gallery tracks layout changes with the production scenarios.
GALLERY: Final = {
    "dev_tab_x": 376,
    "string": (200, 222),
    "empty": (200, 264),
    "number": (80, 331),
    "bounded": (80, 374),
    "precise": (80, 417),
    "bool_on": (142, 475),
    "bool_off": (142, 515),
    "choice": (200, 583),
    "color": (149, 650),
    "asset": (60, 692),
    "group_xyz_y": 760,
    "group_second_x": 220,
    "group_third_x": 385,
    "toolbar_new": (22, 150),
    "toolbar_step": 35,
    "tooltip_parking": (400, 900),
}

# Positions used to park a pointer outside an open panel/brush preview. The
# window-relative variant is for controls anchored to the status strip.
PARK_PANEL: Final = (450, 1000)
PARK_PANEL_LOW: Final = (450, 1100)
STATUS: Final = {"map_toggle_from_right": (610, 115), "height_from_bottom": 92}

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
SHELL: Final = {
    "lighting_shadow_density": (90, 419),
    "lighting_ground_diffuse": (90, 331),
    "color_gradient_origin": (10, 252),
    "water_normal_texture": (87, 236),
}


def status_button_point(width: int, height: int, index: int) -> tuple[int, int]:
    """Centre of the Undo, Redo, or Clear button in the status strip."""
    toolbar_left = round((width - PANEL_WIDTH) * 0.55) + 10
    return (
        toolbar_left + DEV_CONSOLE["status_button_first_x"] + DEV_CONSOLE["status_button_step"] * index,
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
