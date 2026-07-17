//! Box-selecting objects by dragging over the map or sky, a port of
//! `rectangle_select_state.lua`.
//!
//! Chili tests membership in *screen* space. The engine exposes the same query
//! for units and features, which also lets a fresh module instance discover
//! objects that survived `/reloadnativemodules`; areas remain editor-only and
//! are projected locally. A drag may begin over the sky, where a world-space
//! ground corner does not exist.

use spring_native::{prelude::NativeInterfaceRef, sys::Float3};

use crate::sbc::command_system::model::Models;
use crate::sbc::objects::{ObjectKind, ObjectManager, SelectionManager};
use crate::sbc::states::state::{mod_state, EditorState, StateContext, Transition};

const GL_LINE_LOOP: u32 = 0x0002;
const GL_MODELVIEW: u32 = 0x1700;
const GL_PROJECTION: u32 = 0x1701;

pub(crate) struct RectangleSelectState {
    /// The screen corner the drag started from, in the mouse callback's
    /// top-origin coordinate space.
    start: (i32, i32),
    /// The current screen corner, updated while the button is held.
    end: (i32, i32),
    /// The selection when the drag began, for shift-modified selects.
    original: Vec<(ObjectKind, i32)>,
}

impl RectangleSelectState {
    pub(crate) fn new(start_x: i32, start_y: i32) -> Self {
        RectangleSelectState {
            start: (start_x, start_y),
            end: (start_x, start_y),
            original: Vec::new(),
        }
    }

    /// The axis-aligned bounds in the mouse callback's top-origin space.
    fn pointer_bounds(&self) -> (i32, i32, i32, i32) {
        let (x0, x1) = min_max(self.start.0, self.end.0);
        let (y0, y1) = min_max(self.start.1, self.end.1);
        (x0, y0, x1, y1)
    }

    /// Convert the pointer rectangle to camera projection space. Mouse events
    /// use a top-left origin; `world_to_screen_coords` and our OpenGL overlay
    /// use a bottom-left origin.
    fn camera_bounds(&self, view_height: i32) -> (i32, i32, i32, i32) {
        let (left, top, right, bottom) = self.pointer_bounds();
        (
            left,
            flip_y(bottom, view_height),
            right,
            flip_y(top, view_height),
        )
    }

    /// Objects whose projected position falls inside the drag rectangle.
    fn objects_in_box(
        &self,
        interface: &NativeInterfaceRef,
        models: &mut Models,
    ) -> Vec<(ObjectKind, i32)> {
        let Ok(geometry) = interface.display().get_view_geometry() else {
            return Vec::new();
        };
        let (left, bottom, right, top) = self.camera_bounds(geometry.viewSizeY);
        // These screen-rectangle APIs use bottom-origin coordinates, like the
        // camera. Query engine objects directly instead of the editor model: a
        // hot reload deliberately recreates that model while its units/features
        // stay alive in the engine.
        let unsynced = interface.unsynced_read();
        let rendering = unsynced.unit_rendering();
        let units = rendering
            .get_units_in_screen_rectangle(left as f32, top as f32, right as f32, bottom as f32, -1)
            .unwrap_or_default();
        let features = rendering
            .get_features_in_screen_rectangle(left as f32, top as f32, right as f32, bottom as f32)
            .unwrap_or_default();
        let objects = models.get::<ObjectManager>();
        let mut hits = units
            .into_iter()
            .filter_map(|spring_id| {
                objects
                    .model_id_for_spring(ObjectKind::Unit, spring_id)
                    .map(|model_id| (ObjectKind::Unit, model_id))
            })
            .collect::<Vec<_>>();
        hits.extend(features.into_iter().filter_map(|spring_id| {
            objects
                .model_id_for_spring(ObjectKind::Feature, spring_id)
                .map(|model_id| (ObjectKind::Feature, model_id))
        }));

        // Areas have no engine representation, so retain Chili's local
        // projection path for them.
        for id in objects.all_model_ids(ObjectKind::Area) {
            if let Some(pos) = objects.object_pos(ObjectKind::Area, id) {
                let Ok((screen, valid)) = interface.camera().world_to_screen_coords(Float3 {
                    x: pos.x,
                    y: pos.y,
                    z: pos.z,
                }) else {
                    continue;
                };
                if valid
                    && screen.x >= left as f32
                    && screen.x <= right as f32
                    && screen.y >= bottom as f32
                    && screen.y <= top as f32
                {
                    hits.push((ObjectKind::Area, id));
                }
            }
        }
        hits
    }

    /// Resolve the final selection and hand it to the manager.
    fn finalize(&mut self, ctx: &mut StateContext) {
        let shift = mod_state(ctx.interface).shift;
        let boxed = self.objects_in_box(ctx.interface, ctx.models);
        let selection = if shift {
            symmetric_difference(&self.original, &boxed)
        } else {
            boxed
        };

        ctx.models
            .get::<SelectionManager>()
            .set_selection(selection);
        mirror_units_to_engine(ctx);
    }
}

impl EditorState for RectangleSelectState {
    fn name(&self) -> &'static str {
        "rectangle-select"
    }

    fn enter(&mut self, ctx: &mut StateContext) {
        self.original = ctx.models.get::<SelectionManager>().all();
    }

    /// Do not poll `get_mouse_state` here: it has a different coordinate
    /// convention from the callback that supplied `start`. Both corners must
    /// come from the same event stream or the overlay tears vertically.
    fn mouse_move(&mut self, _ctx: &mut StateContext, x: i32, y: i32, _button: i32) -> bool {
        self.end = (x, y);
        true
    }

    fn mouse_release(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
        if button == 1 {
            self.end = (x, y);
            self.finalize(ctx);
            ctx.request(Transition::Default);
            return true;
        }
        false
    }

    fn draw_screen(&mut self, interface: &NativeInterfaceRef) {
        let Ok(geometry) = interface.display().get_view_geometry() else {
            return;
        };
        let (left, bottom, right, top) = self.camera_bounds(geometry.viewSizeY);
        let gfx = interface.gfx();
        // `draw_screen` has no guaranteed projection matrix. Establish a local
        // pixel-space projection, then restore both matrix stacks before RmlUi
        // renders its panels above the selection outline.
        let _ = gfx.matrix_mode(GL_PROJECTION);
        let _ = gfx.push_matrix();
        let _ = gfx.load_identity();
        let _ = gfx.ortho(
            0.0,
            geometry.viewSizeX as f32,
            0.0,
            geometry.viewSizeY as f32,
            -1.0,
            1.0,
        );
        let _ = gfx.matrix_mode(GL_MODELVIEW);
        let _ = gfx.push_matrix();
        let _ = gfx.load_identity();
        let _ = gfx.depth_test(false, false, 0);
        let _ = gfx.line_width(2.0);
        let _ = gfx.color(0.3, 0.7, 1.0, 0.9);
        let _ = gfx.begin_end(GL_LINE_LOOP, || {
            for (x, y) in [(left, bottom), (right, bottom), (right, top), (left, top)] {
                let _ = gfx.vertex(x as f32, y as f32, 0.0, 1.0, 3);
            }
        });
        let _ = gfx.matrix_mode(GL_MODELVIEW);
        let _ = gfx.pop_matrix();
        let _ = gfx.matrix_mode(GL_PROJECTION);
        let _ = gfx.pop_matrix();
        let _ = gfx.matrix_mode(GL_MODELVIEW);
    }
}

/// Mirror the unit part of the selection into the engine so its glow shows.
fn mirror_units_to_engine(ctx: &mut StateContext) {
    let unit_ids = ctx.models.get::<SelectionManager>().get(ObjectKind::Unit);
    let objects = ctx.models.get::<ObjectManager>();
    let spring_ids: Vec<i32> = unit_ids
        .into_iter()
        .filter_map(|id| objects.spring_id(ObjectKind::Unit, id))
        .collect();
    let _ = ctx
        .interface
        .selection()
        .select_unit_array(&spring_ids, false);
}

fn min_max<T: Ord>(a: T, b: T) -> (T, T) {
    if a <= b {
        (a, b)
    } else {
        (b, a)
    }
}

/// Translate a top-origin input y coordinate to the bottom-origin camera and
/// OpenGL coordinate space.
fn flip_y(y: i32, view_height: i32) -> i32 {
    view_height - 1 - y
}

/// The symmetric difference of two selections: everything in exactly one of
/// them. Matches Lua's shift-select (toggle the boxed set against the original).
fn symmetric_difference(
    a: &[(ObjectKind, i32)],
    b: &[(ObjectKind, i32)],
) -> Vec<(ObjectKind, i32)> {
    let mut out: Vec<(ObjectKind, i32)> = a.iter().filter(|x| !b.contains(x)).copied().collect();
    out.extend(b.iter().filter(|x| !a.contains(x)).copied());
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn min_max_orders_the_pair() {
        assert_eq!(min_max(3, 1), (1, 3));
        assert_eq!(min_max(1, 3), (1, 3));
    }

    #[test]
    fn camera_bounds_flip_pointer_y_without_moving_x() {
        let state = RectangleSelectState {
            start: (120, 80),
            end: (640, 420),
            original: Vec::new(),
        };
        // A drag from (120, 80) to (640, 420) in a 1,000px-high window is
        // drawn and tested from (120, 919) to (640, 579) in camera space.
        assert_eq!(state.camera_bounds(1000), (120, 579, 640, 919));
    }

    #[test]
    fn shift_select_toggles_the_box_against_the_original() {
        let u = ObjectKind::Unit;
        // Original has 1 and 2; the box covers 2 and 3. Shift keeps the ones in
        // exactly one set: 1 (kept) and 3 (added), dropping the overlap 2.
        let original = [(u, 1), (u, 2)];
        let boxed = [(u, 2), (u, 3)];
        let mut result = symmetric_difference(&original, &boxed);
        result.sort();
        assert_eq!(result, vec![(u, 1), (u, 3)]);
    }

    #[test]
    fn empty_box_with_shift_keeps_the_original() {
        let u = ObjectKind::Unit;
        let original = [(u, 5), (u, 6)];
        let mut result = symmetric_difference(&original, &[]);
        result.sort();
        assert_eq!(result, vec![(u, 5), (u, 6)]);
    }
}
