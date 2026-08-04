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
use crate::sbc::states::trace::{screen_rect, world_to_screen};

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

    /// Objects whose projected position falls inside the drag rectangle.
    fn objects_in_box(
        &self,
        interface: &NativeInterfaceRef,
        models: &mut Models,
    ) -> Vec<(ObjectKind, i32)> {
        let rect = screen_rect(self.start, self.end);
        let (left, bottom, right, top) = (rect.left, rect.bottom, rect.right, rect.top);
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
                let Some(screen) = world_to_screen(
                    interface,
                    Float3 {
                        x: pos.x,
                        y: pos.y,
                        z: pos.z,
                    },
                ) else {
                    continue;
                };
                if screen.x >= left as f32
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

    /// A second mouse button interrupts the left-button selection gesture. In
    /// particular, right-click must not leave the box on screen forever: the
    /// engine routes later input to the state that claimed the original press.
    fn mouse_press(&mut self, ctx: &mut StateContext, _x: i32, _y: i32, button: i32) -> bool {
        if button != 1 {
            ctx.request(Transition::Default);
        }
        false
    }

    /// Do not poll `get_mouse_state` here: it has a different coordinate
    /// convention from the callback that supplied `start`. Both corners must
    /// come from the same event stream or the overlay tears vertically.
    fn mouse_move(&mut self, _ctx: &mut StateContext, x: i32, y: i32, _button: i32) -> bool {
        self.end = (x, y);
        true
    }

    fn mouse_release(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
        if button != 1 {
            // Keep this cancellation path as well as `mouse_press`: some
            // platforms can deliver the release after another callback has
            // consumed the corresponding press.
            ctx.request(Transition::Default);
            return false;
        }
        self.end = (x, y);
        self.finalize(ctx);
        ctx.request(Transition::Default);
        true
    }

    fn draw_screen(&mut self, interface: &NativeInterfaceRef) {
        let Ok(geometry) = interface.display().get_view_geometry() else {
            return;
        };
        let rect = screen_rect(self.start, self.end);
        let (left, bottom, right, top) = (rect.left, rect.bottom, rect.right, rect.top);
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
        let _ = gfx.depth_test(spring_native::GfxDepthTestOptions {
            enable: false,
            set_func: false,
            func: 0,
        });
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
    fn camera_bounds_sort_the_drag_corners() {
        // Both corners arrive in the engine's bottom-origin space, so a drag
        // from (120, 420) down to (640, 80) still bounds (120, 80)-(640, 420).
        let rect = screen_rect((120, 420), (640, 80));
        assert_eq!(
            (rect.left, rect.bottom, rect.right, rect.top),
            (120, 80, 640, 420)
        );
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
