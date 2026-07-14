use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::objects::{
    ObjectKind, ObjectManager, SelectionManager, SetObjectParamCommand, Vec3,
};
use crate::sbc::states::highlight::ObjectGhost;
use crate::sbc::states::state::StateContext;

/// A selected object and where it started, captured when manipulation began.
pub(super) struct Grabbed {
    pub(super) kind: ObjectKind,
    pub(super) model_id: i32,
    pub(super) origin: Vec3,
    /// What the ghost needs to draw the same model the object is.
    def_id: i32,
    team_id: i32,
    pub(super) yaw: f32,
}

pub(super) fn grab_selection(ctx: &mut StateContext) -> Vec<Grabbed> {
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
    pub(super) fn ghost_at(&self, pos: Vec3, yaw: f32) -> ObjectGhost {
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

/// A `SetObjectParamCommand` moving an object's `pos`.
pub(super) fn set_pos(kind: ObjectKind, model_id: i32, pos: Vec3) -> SetObjectParamCommand {
    set_param(
        kind,
        model_id,
        serde_json::json!("pos"),
        serde_json::json!({ "x": pos.x, "y": pos.y, "z": pos.z }),
    )
}

/// Pose and facing together: `key` carries both, which is the command's
/// many-fields form (one object, one undo entry).
pub(super) fn set_pos_dir(
    kind: ObjectKind,
    model_id: i32,
    pos: Vec3,
    angle: f32,
) -> SetObjectParamCommand {
    set_param(
        kind,
        model_id,
        serde_json::json!({
            "pos": { "x": pos.x, "y": pos.y, "z": pos.z },
            "dir": { "x": angle.sin(), "y": 0.0, "z": angle.cos() },
        }),
        serde_json::Value::Null,
    )
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

fn set_param(
    kind: ObjectKind,
    model_id: i32,
    key: serde_json::Value,
    value: serde_json::Value,
) -> SetObjectParamCommand {
    SetObjectParamCommand::new(kind, model_id, key, value)
}
