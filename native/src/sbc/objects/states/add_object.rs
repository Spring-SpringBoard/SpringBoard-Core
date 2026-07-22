//! Placing units and features, a port of `add_object_state.lua` and the object
//! side of `brush_object_state.lua`.
//!
//! Two modes, chosen by the view's Add / Brush buttons:
//! - **Set**: one object per click at the cursor.
//! - **Brush**: density from `size` and `spread`, painted while held.

use std::time::Instant;

use crate::sbc::objects::{AddObjectCommand, ObjectKind, ObjectManager, RemoveObjectCommand};
use crate::sbc::render::ModelShader;
use crate::sbc::states::state::{cursor, EditorState, GroundHit, StateContext, Transition};

const LEFT: i32 = 1;
const RIGHT: i32 = 3;

/// How the placement behaves, from the view's fields.
#[derive(Debug, Clone)]
pub(crate) struct PlacementConfig {
    pub team: i32,
    pub brush: bool,
    /// Objects per brush dab.
    pub amount: u32,
    /// Brush radius.
    pub size: f32,
    /// Brush spacing, in Lua UI units; converted to world-area density.
    pub spread: f32,
    /// Random world offset applied to each brush point.
    pub noise: f32,
    /// Euler rotation ranges in radians: pitch, yaw, roll.
    pub rot_min: [f32; 3],
    pub rot_max: [f32; 3],
}

impl Default for PlacementConfig {
    fn default() -> Self {
        PlacementConfig {
            team: 0,
            brush: false,
            amount: 1,
            size: 100.0,
            spread: 100.0,
            noise: 0.0,
            rot_min: [0.0, -std::f32::consts::PI, 0.0],
            rot_max: [0.0, std::f32::consts::PI, 0.0],
        }
    }
}

pub(crate) struct AddObjectState {
    kind: ObjectKind,
    def_name: String,
    def_id: i32,
    config: PlacementConfig,
    /// Facing set by the mouse wheel (set mode only).
    angle: f32,
    /// Whether the brush is painting (button held).
    painting: bool,
    /// Whether the brush is erasing (right button held).
    erasing: bool,
    last_apply: Option<Instant>,
    /// A tiny PRNG for scatter; deterministic per state, seeded from the clock.
    rng: u64,
    /// The seed the set-mode scatter is generated from. Fixed between clicks, so
    /// the preview and the placement agree; advanced after each click.
    scatter_seed: u64,
    /// Textures the placement ghost; without it the model is a white silhouette.
    shader: ModelShader,
}

impl AddObjectState {
    pub(crate) fn new(
        kind: ObjectKind,
        def_name: String,
        def_id: i32,
        config: PlacementConfig,
    ) -> Self {
        AddObjectState {
            kind,
            def_name,
            def_id,
            config,
            angle: 0.0,
            painting: false,
            erasing: false,
            last_apply: None,
            rng: 0x2545_F491_4F6C_DD1D,
            scatter_seed: 0x9E37_79B9_7F4A_7C15,
            shader: ModelShader::default(),
        }
    }

    /// xorshift; good enough to scatter a brush.
    fn next_rand(&mut self) -> f32 {
        self.rng ^= self.rng << 13;
        self.rng ^= self.rng >> 7;
        self.rng ^= self.rng << 17;
        (self.rng >> 40) as f32 / (1u64 << 24) as f32
    }

    /// Where the `amount` objects of one set-mode click land: the first under
    /// the cursor, the rest scattered around it (Lua's
    /// `(random() - 0.5) * 100 * sqrt(amount)` per axis).
    ///
    /// Seeded from `scatter_seed`, so it is the *same* answer every frame. The
    /// preview draws these and the click places these -- otherwise the ghosts
    /// show one thing and the engine gets another.
    fn scatter(&self, x: f32, z: f32) -> Vec<(f32, f32)> {
        let count = self.config.amount.max(1);
        let mut rng = self.scatter_seed;
        let mut next = || {
            rng ^= rng << 13;
            rng ^= rng >> 7;
            rng ^= rng << 17;
            (rng >> 40) as f32 / (1u64 << 24) as f32
        };
        let spread = 100.0 * (count as f32).sqrt();
        (0..count)
            .map(|i| {
                if i == 0 {
                    return (x, z);
                }
                (x + (next() - 0.5) * spread, z + (next() - 0.5) * spread)
            })
            .collect()
    }

    fn random_in_range(&mut self, axis: usize) -> f32 {
        let (lo, hi) = (self.config.rot_min[axis], self.config.rot_max[axis]);
        if hi <= lo {
            lo
        } else {
            lo + self.next_rand() * (hi - lo)
        }
    }

    fn random_rot(&mut self) -> [f32; 3] {
        [
            self.random_in_range(0),
            self.random_in_range(1),
            self.random_in_range(2),
        ]
    }

    fn place_one(&mut self, ctx: &mut StateContext, x: f32, y: f32, z: f32, rot: [f32; 3]) {
        let params = serde_json::json!({
            "defName": self.def_name,
            "pos": { "x": x, "y": y, "z": z },
            "rot": { "x": rot[0], "y": rot[1], "z": rot[2] },
            "team": self.config.team,
        });
        ctx.command(Box::new(AddObjectCommand::new(self.kind, params)));
    }

    fn apply_set(&mut self, ctx: &mut StateContext, hit: GroundHit) {
        let spots = self.scatter(hit.x, hit.z);
        let grouped = spots.len() > 1;
        if grouped {
            ctx.set_multiple_command_mode(true);
        }
        for (x, z) in spots {
            if let Some((px, py, pz)) = ground(ctx, x, z) {
                self.place_one(ctx, px, py, pz, [0.0, self.angle, 0.0]);
            }
        }
        if grouped {
            ctx.set_multiple_command_mode(false);
        }
        // A fresh scatter for the next click, as Lua re-seeds after placing.
        self.scatter_seed = self
            .scatter_seed
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1);
    }

    /// One dab: density-based scatter in brush mode.
    fn apply_brush(&mut self, ctx: &mut StateContext, cx: f32, cz: f32) {
        if !self.config.brush {
            return;
        }
        let count = brush_count(self.config.size, self.config.spread);
        // This is Lua's `spreadSqrt - tolerance`. A brush is a density tool:
        // it fills unoccupied candidates, rather than blindly adding `count`
        // features on every dab over the same ground.
        let spacing = feature_spacing(self.config.spread);
        // State commands execute after this callback returns, so the engine has
        // not seen earlier candidates in this dab yet. Keep the equivalent of
        // Lua's temporary waitList locally to avoid overlapping those too.
        let mut pending_features = Vec::new();
        // Wrap the scatter in one undo group.
        ctx.set_multiple_command_mode(true);
        for i in 0..count {
            let (ox, oz) = sunflower_point(i, count, self.config.size);
            let noise_angle = self.next_rand() * std::f32::consts::TAU;
            let noise_radius = self.next_rand().sqrt() * self.config.noise;
            let px = cx + ox + noise_radius * noise_angle.cos();
            let pz = cz + oz + noise_radius * noise_angle.sin();
            let rot = self.random_rot();
            if self.kind == ObjectKind::Feature
                && (feature_exists_near(ctx, self.def_id, px, pz, spacing)
                    || pending_feature_conflict(&pending_features, px, pz, spacing))
            {
                continue;
            }
            if let Some(hit) = ground(ctx, px, pz) {
                self.place_one(ctx, hit.0, hit.1, hit.2, rot);
                if self.kind == ObjectKind::Feature {
                    pending_features.push((hit.0, hit.2));
                }
            }
        }
        ctx.set_multiple_command_mode(false);
    }

    fn erase(&mut self, ctx: &mut StateContext, cx: f32, cz: f32) {
        let radius_sq = self.config.size * self.config.size;
        let ids = {
            let objects = ctx.models.get::<ObjectManager>();
            objects
                .all_model_ids(self.kind)
                .into_iter()
                .filter(|&id| {
                    objects.object_pos(self.kind, id).is_some_and(|pos| {
                        let dx = pos.x - cx;
                        let dz = pos.z - cz;
                        dx * dx + dz * dz <= radius_sq
                    })
                })
                .collect::<Vec<_>>()
        };
        if ids.is_empty() {
            return;
        }
        ctx.set_multiple_command_mode(true);
        for id in ids {
            ctx.command(Box::new(RemoveObjectCommand::new(self.kind, id)));
        }
        ctx.set_multiple_command_mode(false);
    }

    fn can_apply(&mut self) -> bool {
        // Brush repeats about every 0.1s while held, matching Lua's applyDelay.
        let now = Instant::now();
        match self.last_apply {
            Some(last) if now.duration_since(last).as_secs_f32() < 0.1 => false,
            _ => {
                self.last_apply = Some(now);
                true
            }
        }
    }
}

fn brush_count(size: f32, spread: f32) -> u32 {
    let density_area = (spread.max(1.0) * 100.0).max(1.0);
    ((size.max(1.0) * size.max(1.0)) / density_area)
        .ceil()
        .max(1.0) as u32
}

/// Lua's `sqrt(spread * 100) - tolerance`, with an empty radius treated as no
/// exclusion rather than accidentally querying a negative cylinder radius.
fn feature_spacing(spread: f32) -> f32 {
    ((spread.max(0.0) * 100.0).sqrt() - 5.0).max(0.0)
}

fn feature_exists_near(ctx: &StateContext, def_id: i32, x: f32, z: f32, distance: f32) -> bool {
    if def_id <= 0 || distance <= 0.0 {
        return false;
    }
    let features = ctx.interface.features();
    features
        .get_features_in_cylinder(x, z, distance, f32::MAX)
        .ok()
        .into_iter()
        .flatten()
        .any(|feature_id| {
            features
                .get_feature_def_id(feature_id)
                .is_ok_and(|existing_def| existing_def == def_id)
        })
}

/// Lua checks its not-yet-executed wait list at twice the engine query radius.
/// It prevents candidates from the same scatter landing too close together even
/// though the engine feature query cannot see queued commands yet.
fn pending_feature_conflict(pending: &[(f32, f32)], x: f32, z: f32, distance: f32) -> bool {
    let min_distance = distance * 2.0;
    let min_distance_sq = min_distance * min_distance;
    pending.iter().any(|(other_x, other_z)| {
        let dx = other_x - x;
        let dz = other_z - z;
        dx * dx + dz * dz < min_distance_sq
    })
}

fn sunflower_point(index: u32, count: u32, radius: f32) -> (f32, f32) {
    if count <= 1 {
        return (0.0, 0.0);
    }
    const GOLDEN_ANGLE: f32 = 2.399_963_1;
    let t = index as f32 / (count - 1) as f32;
    let r = t.sqrt() * radius;
    let angle = index as f32 * GOLDEN_ANGLE;
    (r * angle.cos(), r * angle.sin())
}

/// Cursor-to-world at a map position, via the ground height.
fn ground(ctx: &StateContext, x: f32, z: f32) -> Option<(f32, f32, f32)> {
    let y = ctx.interface.terrain().get_ground_height(x, z).ok()?;
    Some((x, y, z))
}

/// AddObjectState in Lua calls `Spring.TraceScreenRay(mx, my, true)` directly,
/// rather than SpringBoard's helper that forces `ignoreWater = true`.
fn trace_object_ground(
    interface: &spring_native::prelude::NativeInterfaceRef,
    x: f32,
    y: f32,
) -> Option<GroundHit> {
    let (hit_type, _, coords) = interface
        .camera()
        .trace_screen_ray(x, y, true, false, false, false, 0.0)
        .ok()?;
    (hit_type == 3).then_some(GroundHit {
        x: coords.x,
        y: coords.y,
        z: coords.z,
    })
}

impl EditorState for AddObjectState {
    fn name(&self) -> &'static str {
        match self.kind {
            ObjectKind::Unit => "add-unit",
            ObjectKind::Feature => "add-feature",
            ObjectKind::Area => "add-area",
        }
    }

    fn mouse_press(&mut self, ctx: &mut StateContext, x: i32, y: i32, button: i32) -> bool {
        if button == RIGHT && !self.config.brush {
            // Right-click leaves set placement, as Lua's escape does.
            ctx.request(Transition::Default);
            return true;
        }
        if button != LEFT && !(button == RIGHT && self.config.brush) {
            return false;
        }
        let Some(hit) = trace_object_ground(ctx.interface, x as f32, y as f32) else {
            return true;
        };
        if button == RIGHT {
            self.erasing = true;
            self.erase(ctx, hit.x, hit.z);
            return true;
        }
        self.painting = true;
        self.last_apply = Some(Instant::now());
        if self.config.brush {
            self.apply_brush(ctx, hit.x, hit.z);
        } else {
            self.apply_set(ctx, hit);
        }
        true
    }

    fn mouse_release(&mut self, _ctx: &mut StateContext, _x: i32, _y: i32, button: i32) -> bool {
        if button == LEFT {
            self.painting = false;
        }
        if button == RIGHT {
            self.erasing = false;
        }
        false
    }

    /// Brush mode keeps placing where the cursor is while the button is held.
    fn update(&mut self, ctx: &mut StateContext) {
        if (!self.painting && !self.erasing) || !self.config.brush {
            return;
        }
        let Some(mouse) = cursor(ctx.interface) else {
            return;
        };
        let button_held = if self.erasing {
            mouse.right
        } else {
            mouse.left
        };
        if !button_held {
            self.erasing = false;
            self.painting = false;
            return;
        }
        if !self.can_apply() {
            return;
        }
        if let Some(hit) = trace_object_ground(ctx.interface, mouse.x, mouse.y) {
            if self.erasing {
                self.erase(ctx, hit.x, hit.z);
            } else {
                self.apply_brush(ctx, hit.x, hit.z);
            }
        }
    }

    /// A ghost at the cursor: the object model in set mode, and the scatter
    /// reach in brush mode.
    fn draw_world(&mut self, interface: &spring_native::prelude::NativeInterfaceRef) {
        let Some(mouse) = cursor(interface) else {
            return;
        };
        let Some(hit) = trace_object_ground(interface, mouse.x, mouse.y) else {
            return;
        };
        // The brush also shows its reach, since the scatter does not fill it.
        if self.config.brush {
            crate::sbc::states::highlight::draw_cursor_ring(
                interface,
                hit.x,
                hit.z,
                self.config.size,
                None,
                (0.3, 0.9, 0.4, 0.9),
            );
        }
        if self.def_id <= 0 {
            return;
        }
        // One ghost per object the click will place, at the very spots it will
        // place them -- a single ghost for an amount of 5 shows you one thing
        // and gives you another. The brush's noise is not previewed: it is drawn
        // fresh on each dab, so the ghost would jitter under a still cursor.
        let (kind, def_id, team_id, yaw) = (self.kind, self.def_id, self.config.team, self.angle);
        let spots: Vec<(f32, f32)> = if self.config.brush {
            let count = brush_count(self.config.size, self.config.spread);
            (0..count)
                .map(|i| {
                    let (ox, oz) = sunflower_point(i, count, self.config.size);
                    (hit.x + ox, hit.z + oz)
                })
                .collect()
        } else {
            self.scatter(hit.x, hit.z)
        };
        for (x, z) in spots {
            let y = interface.terrain().get_ground_height(x, z).unwrap_or(hit.y);
            crate::sbc::states::highlight::draw_object_ghost(
                interface,
                &mut self.shader,
                &crate::sbc::states::highlight::ObjectGhost {
                    kind,
                    def_id,
                    team_id,
                    x,
                    y,
                    z,
                    yaw,
                },
            );
        }
    }

    /// Shift + wheel resizes the brush, Alt + wheel turns the object being placed.
    /// Anything else falls through, so the camera keeps zooming.
    fn mouse_wheel(&mut self, ctx: &mut StateContext, up: bool, _value: f32) -> bool {
        let Ok((alt, _, _, shift)) = ctx.interface.input().get_mod_key_state() else {
            return false;
        };
        if shift {
            // Through the shared brush, so the view's `size` field follows the
            // wheel -- the same channel the map brushes resize on.
            let brush = ctx.models.get::<crate::sbc::states::BrushSettings>();
            brush.scale_size(up);
            self.config.size = brush.size;
            return true;
        }
        if alt {
            self.angle += if up { 0.1 } else { -0.1 };
            return true;
        }
        false
    }
}

#[cfg(test)]
mod tests {
    use super::{feature_spacing, pending_feature_conflict};

    #[test]
    fn feature_spacing_matches_luas_tolerance() {
        assert!((feature_spacing(100.0) - 95.0).abs() < f32::EPSILON);
    }

    #[test]
    fn pending_features_keep_luas_double_spacing() {
        let pending = [(0.0, 0.0)];
        // Lua uses a strict `< 4 * distance^2` check.
        assert!(pending_feature_conflict(&pending, 189.9, 0.0, 95.0));
        assert!(!pending_feature_conflict(&pending, 190.0, 0.0, 95.0));
    }
}
