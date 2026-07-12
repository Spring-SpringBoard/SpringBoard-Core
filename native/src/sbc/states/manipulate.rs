//! Moving and rotating the selected objects, ports of `drag_object_state.lua`
//! and `rotate_object_state.lua`.
//!
//! The object itself does not move until the button comes up: a ghost of it is
//! drawn where it would land, and the original stays put. Only the release
//! commits, as one undoable group.

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::objects::{ObjectKind, ObjectManager, SelectionManager, Vec3};
use crate::sbc::panels::ModelShader;
use crate::sbc::states::highlight::{draw_object_ghost, ObjectGhost};
use crate::sbc::states::state::{trace_ground, EditorState, StateContext, Transition};

/// A selected object and where it started, captured when manipulation began.
struct Grabbed {
    kind: ObjectKind,
    model_id: i32,
    origin: Vec3,
    /// What the ghost needs to draw the same model the object is.
    def_id: i32,
    team_id: i32,
    yaw: f32,
}

fn grab_selection(ctx: &mut StateContext) -> Vec<Grabbed> {
    let mut grabbed = Vec::new();
    for kind in [ObjectKind::Unit, ObjectKind::Feature, ObjectKind::Area] {
        let ids = ctx.models.get::<SelectionManager>().get(kind);
        for model_id in ids {
            let objects = ctx.models.get::<ObjectManager>();
            let Some(origin) = objects.object_pos(kind, model_id) else {
                continue;
            };
            let spring_id = objects.spring_id(kind, model_id);
            let (def_id, team_id, yaw) = spring_id
                .map(|id| shape_of(ctx.interface, kind, id))
                .unwrap_or((0, 0, 0.0));
            grabbed.push(Grabbed {
                kind,
                model_id,
                origin,
                def_id,
                team_id,
                yaw,
            });
        }
    }
    grabbed
}

impl Grabbed {
    fn ghost_at(&self, pos: Vec3, yaw: f32) -> ObjectGhost {
        ObjectGhost {
            kind: self.kind,
            def_id: self.def_id,
            team_id: self.team_id,
            x: pos.x,
            y: pos.y,
            z: pos.z,
            yaw,
        }
    }
}

/// The def, team and facing of a live object, for drawing its ghost.
fn shape_of(interface: &NativeInterfaceRef, kind: ObjectKind, spring_id: i32) -> (i32, i32, f32) {
    match kind {
        ObjectKind::Unit => {
            let units = interface.units_info();
            (
                units.get_unit_def_id(spring_id).unwrap_or(0),
                units.get_unit_team(spring_id).unwrap_or(0),
                units.get_unit_heading(spring_id, true).unwrap_or(0.0),
            )
        }
        ObjectKind::Feature => {
            let features = interface.features();
            // Feature headings come as the engine's 16-bit turns, unlike units'.
            let heading = features.get_feature_heading(spring_id).unwrap_or(0) as f32;
            // A feature's team is often gaia's, or none at all; the shape draw
            // wants a real one.
            let team = features.get_feature_team(spring_id).unwrap_or(0).max(0);
            (
                features.get_feature_def_id(spring_id).unwrap_or(0),
                team,
                heading * std::f32::consts::TAU / 65536.0,
            )
        }
        ObjectKind::Area => (0, 0, 0.0),
    }
}

/// One `SetObjectParamCommand` moving an object's `pos`.
fn set_pos(kind: ObjectKind, model_id: i32, pos: Vec3) -> serde_json::Value {
    serde_json::json!({
        "objType": kind_wire(kind),
        "modelID": model_id,
        "key": "pos",
        "value": { "x": pos.x, "y": pos.y, "z": pos.z },
    })
}

fn set_pos_dir(kind: ObjectKind, model_id: i32, pos: Vec3, angle: f32) -> serde_json::Value {
    serde_json::json!({
        "objType": kind_wire(kind),
        "modelID": model_id,
        "key": {
            "pos": { "x": pos.x, "y": pos.y, "z": pos.z },
            "dir": { "x": angle.sin(), "y": 0.0, "z": angle.cos() },
        },
    })
}

fn kind_wire(kind: ObjectKind) -> &'static str {
    match kind {
        ObjectKind::Unit => "unit",
        ObjectKind::Feature => "feature",
        ObjectKind::Area => "area",
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

// ── Drag ───────────────────────────────────────────────────────────

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

// ── Rotate ─────────────────────────────────────────────────────────

pub(crate) struct RotateObjectState {
    grabbed: Vec<Grabbed>,
    centre: (f32, f32),
    /// Cursor angle about the centre when the rotate began; subtracted so the
    /// object does not jump on the first move.
    start_angle: Option<f32>,
    last_angle: f32,
    ghosts: Vec<ObjectGhost>,
    shader: ModelShader,
}

impl RotateObjectState {
    pub(crate) fn new() -> Self {
        RotateObjectState {
            grabbed: Vec::new(),
            centre: (0.0, 0.0),
            start_angle: None,
            last_angle: 0.0,
            ghosts: Vec::new(),
            shader: ModelShader::default(),
        }
    }

    fn rotated(&self, interface: &NativeInterfaceRef, g: &Grabbed, angle: f32) -> (Vec3, f32) {
        let (cx, cz) = self.centre;
        let dx = g.origin.x - cx;
        let dz = g.origin.z - cz;
        let len = (dx * dx + dz * dz).sqrt();
        let object_angle = dx.atan2(dz) + angle;
        if len <= 0.0 {
            return (g.origin, angle);
        }
        let x = cx + len * (object_angle).sin();
        let z = cz + len * (object_angle).cos();
        // Stick to the ground only if the object was on it.
        let ground = interface
            .terrain()
            .get_ground_height(g.origin.x, g.origin.z)
            .unwrap_or(g.origin.y);
        let y = if (g.origin.y - ground).abs() < 5.0 {
            interface
                .terrain()
                .get_ground_height(x, z)
                .unwrap_or(g.origin.y)
        } else {
            g.origin.y
        };
        (Vec3 { x, y, z }, angle)
    }

    /// The cursor angle about the selection centre.
    fn cursor_angle(&self, ctx: &mut StateContext, x: i32, y: i32) -> Option<f32> {
        let hit = trace_ground(ctx.interface, x as f32, y as f32)?;
        Some((hit.x - self.centre.0).atan2(hit.z - self.centre.1))
    }
}

impl EditorState for RotateObjectState {
    fn name(&self) -> &'static str {
        "rotate-object"
    }

    fn cursor(&self) -> Option<&'static str> {
        Some("resize-x")
    }

    fn enter(&mut self, ctx: &mut StateContext) {
        self.grabbed = grab_selection(ctx);
        let count = self.grabbed.len().max(1) as f32;
        let sum = self
            .grabbed
            .iter()
            .fold((0.0, 0.0), |(sx, sz), g| (sx + g.origin.x, sz + g.origin.z));
        self.centre = (sum.0 / count, sum.1 / count);
    }

    fn mouse_move(&mut self, ctx: &mut StateContext, x: i32, y: i32, _button: i32) -> bool {
        let Some(cursor) = self.cursor_angle(ctx, x, y) else {
            log::debug!("rotate: no ground under ({x}, {y})");
            return true;
        };
        let start = *self.start_angle.get_or_insert(cursor);
        let angle = cursor - start;
        self.last_angle = angle;

        self.ghosts = self
            .grabbed
            .iter()
            .map(|g| {
                let (pos, yaw) = self.rotated(ctx.interface, g, angle);
                g.ghost_at(pos, g.yaw + yaw)
            })
            .collect();
        // The first move only seeds the baseline, so its angle is 0 and the ghosts
        // land on the originals -- worth being able to see when a rotate looks
        // like it did nothing.
        log::debug!(
            "rotate: centre={:?} angle={angle} ghosts={:?}",
            self.centre,
            self.ghosts.iter().map(|g| (g.x, g.z)).collect::<Vec<_>>()
        );
        true
    }

    fn mouse_release(&mut self, ctx: &mut StateContext, _x: i32, _y: i32, _button: i32) -> bool {
        let angle = self.last_angle;
        let finals: Vec<serde_json::Value> = self
            .grabbed
            .iter()
            .map(|g| {
                let (pos, a) = self.rotated(ctx.interface, g, angle);
                set_pos_dir(g.kind, g.model_id, pos, g.yaw + a)
            })
            .collect();
        ctx.set_multiple_command_mode(true);
        for value in finals {
            ctx.command_fields("SetObjectParamCommand", value);
        }
        ctx.set_multiple_command_mode(false);
        ctx.request(Transition::Default);
        false
    }

    fn draw_world(&mut self, interface: &NativeInterfaceRef) {
        draw_ghosts(interface, &mut self.shader, &self.ghosts);
    }
}

/// Commit the final positions as one undoable group.
fn commit_positions(ctx: &mut StateContext, finals: &[(ObjectKind, i32, Vec3)]) {
    if finals.is_empty() {
        return;
    }
    ctx.set_multiple_command_mode(true);
    for (kind, model_id, pos) in finals {
        ctx.command_fields("SetObjectParamCommand", set_pos(*kind, *model_id, *pos));
    }
    ctx.set_multiple_command_mode(false);
}

fn draw_ghosts(interface: &NativeInterfaceRef, shader: &mut ModelShader, ghosts: &[ObjectGhost]) {
    for ghost in ghosts {
        draw_object_ghost(interface, shader, ghost);
    }
}
