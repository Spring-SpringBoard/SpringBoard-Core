use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::objects::{ObjectKind, Vec3};
use crate::sbc::render::ModelShader;
use crate::sbc::states::highlight::ObjectGhost;
use crate::sbc::states::state::{EditorState, StateContext, Transition};
use crate::sbc::states::trace::trace_ground;

use super::ghost::draw_ghosts;
use super::shared::{grab_selection, set_pos, Grabbed};

pub(crate) struct DragObjectState {
    grabbed: Vec<Grabbed>,
    /// Object-to-cursor offset of the grabbed object, so it stays under the grab
    /// point rather than snapping its centre to the cursor.
    diff_x: f32,
    diff_z: f32,
    /// The object the drag was started on, whose motion the rest follow.
    anchor: (ObjectKind, i32),
    /// Where the objects would land: drawn as ghosts, applied on release.
    ghosts: Vec<ObjectGhost>,
    shader: ModelShader,
}

impl DragObjectState {
    pub(crate) fn new(kind: ObjectKind, model_id: i32, diff_x: f32, diff_z: f32) -> Self {
        DragObjectState {
            grabbed: Vec::new(),
            diff_x,
            diff_z,
            anchor: (kind, model_id),
            ghosts: Vec::new(),
            shader: ModelShader::default(),
        }
    }

    /// The (dx, dz) the anchor object should move so its grab point tracks the
    /// cursor, applied to every selected object.
    fn cursor_delta(&self, ctx: &mut StateContext, x: i32, y: i32) -> Option<(f32, f32)> {
        let hit = trace_ground(ctx.interface, x as f32, y as f32)?;
        let anchor = self
            .grabbed
            .iter()
            .find(|g| (g.kind, g.model_id) == self.anchor)?;
        Some((
            hit.x - anchor.origin.x + self.diff_x,
            hit.z - anchor.origin.z + self.diff_z,
        ))
    }

    /// Where each grabbed object lands for a cursor delta.
    fn moved(&self, interface: &NativeInterfaceRef, dx: f32, dz: f32) -> Vec<(usize, Vec3)> {
        self.grabbed
            .iter()
            .enumerate()
            .map(|(i, g)| {
                (
                    i,
                    keep_height(interface, g.origin, g.origin.x + dx, g.origin.z + dz),
                )
            })
            .collect()
    }
}

impl EditorState for DragObjectState {
    fn name(&self) -> &'static str {
        "drag-object"
    }

    fn cursor(&self) -> Option<&'static str> {
        Some("drag")
    }

    fn enter(&mut self, ctx: &mut StateContext) {
        self.grabbed = grab_selection(ctx);
    }

    fn mouse_move(&mut self, ctx: &mut StateContext, x: i32, y: i32, _button: i32) -> bool {
        let Some((dx, dz)) = self.cursor_delta(ctx, x, y) else {
            return true;
        };
        self.ghosts = self
            .moved(ctx.interface, dx, dz)
            .into_iter()
            .map(|(i, pos)| self.grabbed[i].ghost_at(pos, self.grabbed[i].yaw))
            .collect();
        true
    }

    /// The drag started mid-press (a move in DefaultState), so it ends when the
    /// button comes up.
    fn mouse_release(&mut self, ctx: &mut StateContext, x: i32, y: i32, _button: i32) -> bool {
        let finals: Vec<(ObjectKind, i32, Vec3)> = self
            .cursor_delta(ctx, x, y)
            .map(|(dx, dz)| self.moved(ctx.interface, dx, dz))
            .unwrap_or_default()
            .into_iter()
            .map(|(i, pos)| {
                let g = &self.grabbed[i];
                (g.kind, g.model_id, pos)
            })
            .collect();
        commit_positions(ctx, &finals);
        ctx.request(Transition::Default);
        false
    }

    fn draw_world(&mut self, interface: &NativeInterfaceRef) {
        draw_ghosts(interface, &mut self.shader, &self.ghosts);
    }
}

/// Keep an object its original height above the terrain as it moves.
fn keep_height(interface: &NativeInterfaceRef, origin: Vec3, x: f32, z: f32) -> Vec3 {
    let terrain = interface.terrain();
    let ground_at_origin = terrain
        .get_ground_height(origin.x, origin.z)
        .unwrap_or(origin.y);
    let above = origin.y - ground_at_origin;
    let ground = terrain.get_ground_height(x, z).unwrap_or(origin.y);
    Vec3 {
        x,
        y: ground + above,
        z,
    }
}

/// Commit the final positions as one undoable group.
fn commit_positions(ctx: &mut StateContext, finals: &[(ObjectKind, i32, Vec3)]) {
    if finals.is_empty() {
        return;
    }
    ctx.set_multiple_command_mode(true);
    for (kind, model_id, pos) in finals {
        ctx.command(Box::new(set_pos(*kind, *model_id, *pos)));
    }
    ctx.set_multiple_command_mode(false);
}
