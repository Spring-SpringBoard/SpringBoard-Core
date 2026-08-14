use spring_native::{
    prelude::{Error, NativeInterfaceRef},
    TraceScreenRayOptions as NativeTraceScreenRayOptions,
};

#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) struct GroundHit {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
struct ScreenPoint {
    pub x: f32,
    pub y: f32,
}

#[derive(Debug, Clone, Copy)]
struct TraceOptions {
    pub only_coords: bool,
    pub use_minimap: bool,
    pub include_sky: bool,
    pub ignore_water: bool,
    pub height_offset: f32,
}

impl TraceOptions {
    const fn ground(ignore_water: bool) -> Self {
        Self {
            only_coords: true,
            use_minimap: false,
            include_sky: false,
            ignore_water,
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

const HIT_GROUND: i32 = 3;

pub(crate) fn trace_ground_at_mouse(interface: &NativeInterfaceRef) -> Option<GroundHit> {
    let point = mouse_screen_point(interface)?;
    trace_ground_result(interface, point.x, point.y, false)
        .ok()
        .flatten()
}

fn mouse_screen_point(interface: &NativeInterfaceRef) -> Option<ScreenPoint> {
    let mouse = interface.input().get_mouse_state().ok()?;
    Some(ScreenPoint {
        x: mouse.x,
        y: mouse.y,
    })
}

fn trace_screen_ray(
    interface: &NativeInterfaceRef,
    x: f32,
    y: f32,
    options: TraceOptions,
) -> Result<(i32, GroundHit), Error> {
    let (hit_type, _hit_id, coords) = interface.camera().trace_screen_ray(x, y, options.into())?;
    Ok((
        hit_type,
        GroundHit {
            x: coords.x,
            y: coords.y,
            z: coords.z,
        },
    ))
}

fn trace_ground_result(
    interface: &NativeInterfaceRef,
    x: f32,
    y: f32,
    ignore_water: bool,
) -> Result<Option<GroundHit>, Error> {
    let (hit_type, position) =
        trace_screen_ray(interface, x, y, TraceOptions::ground(ignore_water))?;
    Ok((hit_type == HIT_GROUND).then_some(position))
}
