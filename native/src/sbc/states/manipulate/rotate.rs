use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::objects::SetObjectParamCommand;
use crate::sbc::panels::ModelShader;
use crate::sbc::states::highlight::ObjectGhost;
use crate::sbc::states::state::{trace_ground, EditorState, StateContext, Transition};

use super::ghost::draw_ghosts;
use super::shared::{grab_selection, set_pos_dir, Grabbed};

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

    fn rotated(
        &self,
        interface: &NativeInterfaceRef,
        g: &Grabbed,
        angle: f32,
    ) -> (crate::sbc::objects::Vec3, f32) {
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
        (crate::sbc::objects::Vec3 { x, y, z }, angle)
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
        let finals: Vec<SetObjectParamCommand> = self
            .grabbed
            .iter()
            .map(|g| {
                let (pos, a) = self.rotated(ctx.interface, g, angle);
                set_pos_dir(g.kind, g.model_id, pos, g.yaw + a)
            })
            .collect();
        ctx.set_multiple_command_mode(true);
        for command in finals {
            ctx.command(Box::new(command));
        }
        ctx.set_multiple_command_mode(false);
        ctx.request(Transition::Default);
        false
    }

    fn draw_world(&mut self, interface: &NativeInterfaceRef) {
        draw_ghosts(interface, &mut self.shader, &self.ghosts);
    }
}
