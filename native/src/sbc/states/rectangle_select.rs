//! Box-selecting objects by dragging on empty ground, a port of
//! `rectangle_select_state.lua`.
//!
//! Lua tests membership in *screen* space (project each object, compare to the
//! screen rectangle). This native port works in *world* space instead: the drag
//! defines a ground rectangle and objects whose position falls inside it are
//! selected. That keeps the whole interaction on the proven world-draw path (the
//! same immediate primitives the selection ring uses) and avoids a screen
//! projection that cannot be verified without a live camera.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::command_system::model::Models;
use crate::sbc::objects::{ObjectKind, ObjectManager, SelectionManager};
use crate::sbc::states::state::{
    cursor, mod_state, trace_ground, EditorState, GroundHit, StateContext, Transition,
};

const KINDS: [ObjectKind; 3] = [ObjectKind::Unit, ObjectKind::Feature, ObjectKind::Area];

pub(crate) struct RectangleSelectState {
    /// The ground corner the drag started from.
    start: (f32, f32),
    /// The current ground corner, updated while the button is held.
    end: (f32, f32),
    /// The selection when the drag began, for shift-modified selects.
    original: Vec<(ObjectKind, i32)>,
}

impl RectangleSelectState {
    pub(crate) fn new(start_x: f32, start_z: f32) -> Self {
        RectangleSelectState {
            start: (start_x, start_z),
            end: (start_x, start_z),
            original: Vec::new(),
        }
    }

    /// The axis-aligned bounds of the drag, as `(x0, z0, x1, z1)`.
    fn bounds(&self) -> (f32, f32, f32, f32) {
        let (x0, x1) = min_max(self.start.0, self.end.0);
        let (z0, z1) = min_max(self.start.1, self.end.1);
        (x0, z0, x1, z1)
    }

    /// Objects whose position falls inside the drag rectangle.
    fn objects_in_box(&self, models: &mut Models) -> Vec<(ObjectKind, i32)> {
        let (x0, z0, x1, z1) = self.bounds();
        let objects = models.get::<ObjectManager>();
        let mut hits = Vec::new();
        for kind in KINDS {
            for id in objects.all_model_ids(kind) {
                if let Some(pos) = objects.object_pos(kind, id) {
                    if pos.x >= x0 && pos.x <= x1 && pos.z >= z0 && pos.z <= z1 {
                        hits.push((kind, id));
                    }
                }
            }
        }
        hits
    }

    /// Resolve the final selection and hand it to the manager.
    fn finalize(&mut self, ctx: &mut StateContext) {
        let shift = mod_state(ctx.interface).shift;
        let boxed = self.objects_in_box(ctx.models);
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

    /// Track the far corner each tick; when the button is up, finalize and leave.
    fn update(&mut self, ctx: &mut StateContext) {
        let Some(mouse) = cursor(ctx.interface) else {
            return;
        };
        if let Some(GroundHit { x, z, .. }) = trace_ground(ctx.interface, mouse.x, mouse.y) {
            self.end = (x, z);
        }
        if !mouse.left {
            self.finalize(ctx);
            ctx.request(Transition::Default);
        }
    }

    fn draw_world(&mut self, interface: &NativeInterfaceRef) {
        let (x0, z0, x1, z1) = self.bounds();
        crate::sbc::states::highlight::draw_ground_rect(
            interface,
            x0,
            z0,
            x1,
            z1,
            (0.3, 0.7, 1.0, 0.9),
        );
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

fn min_max(a: f32, b: f32) -> (f32, f32) {
    if a <= b {
        (a, b)
    } else {
        (b, a)
    }
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
        assert_eq!(min_max(3.0, 1.0), (1.0, 3.0));
        assert_eq!(min_max(1.0, 3.0), (1.0, 3.0));
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
