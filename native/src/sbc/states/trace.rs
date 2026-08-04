//! Shared screen-to-world tracing and coordinate conversion for editor input.

use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    sys::Float3,
    TraceScreenRayOptions as NativeTraceScreenRayOptions,
};

/// Where the cursor is pointing on the map, in world coordinates.
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) struct GroundHit {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

/// A point in the engine's bottom-origin screen space.
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) struct ScreenPoint {
    pub x: f32,
    pub y: f32,
}

/// A rectangle in the engine's bottom-origin screen space.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct ScreenRect {
    pub left: i32,
    pub bottom: i32,
    pub right: i32,
    pub top: i32,
}

/// The coordinate space accepted by the native camera ray query.
///
/// x is view-relative and y is bottom-origin. Both the polled mouse state and
/// the engine's mouse callbacks report in exactly this space, so neither needs
/// converting before a ray. Only RmlUi, which lays out top-origin, does.
#[derive(Debug, Clone, Copy)]
pub(crate) struct TraceOptions {
    pub only_coords: bool,
    pub use_minimap: bool,
    pub include_sky: bool,
    pub ignore_water: bool,
    pub height_offset: f32,
}

impl TraceOptions {
    pub(crate) const fn ground(ignore_water: bool) -> Self {
        Self {
            only_coords: true,
            use_minimap: false,
            include_sky: false,
            ignore_water,
            height_offset: 0.0,
        }
    }

    pub(crate) const fn objects() -> Self {
        Self {
            only_coords: false,
            use_minimap: false,
            include_sky: false,
            ignore_water: true,
            height_offset: 0.0,
        }
    }
}

impl From<TraceOptions> for NativeTraceScreenRayOptions {
    fn from(options: TraceOptions) -> Self {
        Self {
            only_coords: options.only_coords,
            use_minimap: options.use_minimap,
            include_sky: options.include_sky,
            ignore_water: options.ignore_water,
            height_offset: options.height_offset,
        }
    }
}

/// The compact result returned by the native camera ray query.
#[derive(Debug, Clone, Copy)]
pub(crate) struct ScreenTrace {
    pub hit_type: i32,
    pub hit_id: i32,
    pub position: GroundHit,
}

/// The engine's `hitType`: 0 miss, 1 unit, 2 feature, 3 ground.
pub(crate) const HIT_UNIT: i32 = 1;
pub(crate) const HIT_FEATURE: i32 = 2;
pub(crate) const HIT_GROUND: i32 = 3;

/// What the cursor is over. Ports the several shapes `SB.TraceScreenRay` returns.
#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) enum Trace {
    Sky,
    Ground(GroundHit),
    Unit { spring_id: i32, hit: GroundHit },
    Feature { spring_id: i32, hit: GroundHit },
}

/// The full trace, for selecting whatever is under the cursor.
pub(crate) fn trace_object(interface: &NativeInterfaceRef, x: f32, y: f32) -> Trace {
    let Ok(trace) = trace_screen_ray(interface, x, y, TraceOptions::objects()) else {
        return Trace::Sky;
    };
    match trace.hit_type {
        HIT_UNIT => Trace::Unit {
            spring_id: trace.hit_id,
            hit: trace.position,
        },
        HIT_FEATURE => Trace::Feature {
            spring_id: trace.hit_id,
            hit: trace.position,
        },
        HIT_GROUND => Trace::Ground(trace.position),
        _ => Trace::Sky,
    }
}

/// Convert between the engine's bottom-origin screen space and the top-origin
/// space RmlUi lays out in.
pub(crate) fn flip_screen_y(view_height: f32, y: f32) -> f32 {
    view_height - 1.0 - y
}

/// Order the two corners of a drag into an engine query rectangle. Both corners
/// are already in the engine's bottom-origin screen space, so this only sorts
/// them.
pub(crate) fn screen_rect(start: (i32, i32), end: (i32, i32)) -> ScreenRect {
    let (left, right) = if start.0 <= end.0 {
        (start.0, end.0)
    } else {
        (end.0, start.0)
    };
    let (bottom, top) = if start.1 <= end.1 {
        (start.1, end.1)
    } else {
        (end.1, start.1)
    };
    ScreenRect {
        left,
        bottom,
        right,
        top,
    }
}

/// Project a world position into the same bottom-origin screen space used by
/// the engine's rectangle queries and screen overlays.
pub(crate) fn world_to_screen(
    interface: &NativeInterfaceRef,
    world: Float3,
) -> Option<ScreenPoint> {
    let (screen, valid) = interface.camera().world_to_screen_coords(world).ok()?;
    valid.then_some(ScreenPoint {
        x: screen.x,
        y: screen.y,
    })
}

/// The current mouse position in the engine's native screen space.
pub(crate) fn mouse_screen_point(interface: &NativeInterfaceRef) -> Option<ScreenPoint> {
    let mouse = interface.input().get_mouse_state().ok()?;
    Some(ScreenPoint {
        x: mouse.x,
        y: mouse.y,
    })
}

/// The mouse position used for a paste/ground query.
///
/// Lua's paste action traces the polled mouse position directly. When the
/// pointer is over SpringBoard's fixed editor panel, use the centre of the map
/// viewport instead, matching the native editor's visible fallback.
pub(crate) fn map_mouse_screen_point(interface: &NativeInterfaceRef) -> Option<ScreenPoint> {
    const PANEL_WIDTH: f32 = 500.0;

    let geometry = interface.display().get_view_geometry().ok()?;
    let map_width = (geometry.viewSizeX as f32 - PANEL_WIDTH).max(1.0);
    match mouse_screen_point(interface) {
        Some(point) if point.x < map_width => Some(point),
        _ => Some(ScreenPoint {
            x: map_width / 2.0,
            y: geometry.viewSizeY as f32 / 2.0,
        }),
    }
}

/// The polled cursor, in the same screen space accepted by the ray helper.
///
/// `get_mouse_state` exposes the bottom-origin coordinate used by the Lua paste
/// path and by the native camera ray query, so it is passed through unchanged.
pub(crate) fn cursor(interface: &NativeInterfaceRef) -> Option<Cursor> {
    let mouse = interface.input().get_mouse_state().ok()?;
    Some(Cursor {
        x: mouse.x,
        y: mouse.y,
        left: mouse.left,
        right: mouse.right,
    })
}

/// The cursor position, ready to trace with.
#[derive(Debug, Clone, Copy)]
pub(crate) struct Cursor {
    pub x: f32,
    pub y: f32,
    pub left: bool,
    pub right: bool,
}

/// Trace the cursor against units, features and the ground.
pub(crate) fn trace_screen_ray(
    interface: &NativeInterfaceRef,
    x: f32,
    y: f32,
    options: TraceOptions,
) -> Result<ScreenTrace, Error> {
    let (hit_type, hit_id, coords) = interface.camera().trace_screen_ray(x, y, options.into())?;
    Ok(ScreenTrace {
        hit_type,
        hit_id,
        position: GroundHit {
            x: coords.x,
            y: coords.y,
            z: coords.z,
        },
    })
}

/// Trace a screen point using SpringBoard's normal editor ground semantics.
pub(crate) fn trace_editor_ground(
    interface: &NativeInterfaceRef,
    x: f32,
    y: f32,
) -> Result<ScreenTrace, Error> {
    trace_screen_ray(interface, x, y, TraceOptions::ground(true))
}

pub(crate) fn trace_ground_result(
    interface: &NativeInterfaceRef,
    x: f32,
    y: f32,
    ignore_water: bool,
) -> Result<Option<GroundHit>, Error> {
    let trace = trace_screen_ray(interface, x, y, TraceOptions::ground(ignore_water))?;
    Ok((trace.hit_type == HIT_GROUND).then_some(trace.position))
}

pub(crate) fn trace_ground(interface: &NativeInterfaceRef, x: f32, y: f32) -> Option<GroundHit> {
    trace_ground_result(interface, x, y, true).ok().flatten()
}

/// Trace the current mouse position using Lua's direct
/// `Spring.TraceScreenRay(mx, my, true)` defaults, including water.
pub(crate) fn trace_ground_at_mouse(interface: &NativeInterfaceRef) -> Option<GroundHit> {
    let point = mouse_screen_point(interface)?;
    trace_ground_result(interface, point.x, point.y, false)
        .ok()
        .flatten()
}

/// Trace the current mouse position for an operation initiated from the
/// editor panel. The panel is not map input, so use the centre of the visible
/// map when the toolbar action was invoked there.
pub(crate) fn trace_ground_at_map_mouse(interface: &NativeInterfaceRef) -> Option<GroundHit> {
    let point = map_mouse_screen_point(interface)?;
    trace_ground_result(interface, point.x, point.y, false)
        .ok()
        .flatten()
}

/// Trace a screen point using Lua's direct
/// `Spring.TraceScreenRay(mx, my, true)` defaults, including water.
pub(crate) fn trace_ground_with_water(
    interface: &NativeInterfaceRef,
    x: f32,
    y: f32,
) -> Option<GroundHit> {
    trace_ground_result(interface, x, y, false).ok().flatten()
}

#[cfg(test)]
mod tests {
    use super::flip_screen_y;

    #[test]
    fn screen_y_flip_is_symmetric_at_the_view_bounds() {
        assert_eq!(flip_screen_y(1_000.0, 0.0), 999.0);
        assert_eq!(flip_screen_y(1_000.0, 999.0), 0.0);
        assert_eq!(flip_screen_y(1_000.0, flip_screen_y(1_000.0, 123.0)), 123.0);
    }

    #[test]
    fn screen_rect_sorts_corners_in_bottom_origin_space() {
        let rect = super::ScreenRect {
            left: 40,
            bottom: 100,
            right: 140,
            top: 300,
        };
        assert_eq!(super::screen_rect((40, 100), (140, 300)), rect);
        assert_eq!(super::screen_rect((140, 300), (40, 100)), rect);
    }
}
