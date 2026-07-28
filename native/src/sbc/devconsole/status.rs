//! Slow-changing data rendered in the editor status surface.

use std::time::{Duration, Instant};

use spring_native::prelude::NativeInterfaceRef;

use crate::sbc::devconsole::metrics::SystemMetrics;
use crate::sbc::objects::SelectionManager;
use crate::sbc::states::{cursor, trace_ground};

pub(super) struct StatusPresenter {
    last_metrics_refresh: Option<Instant>,
    performance: [StatusMetric; 3],
    system_performance: [StatusMetric; 4],
    system_metrics: SystemMetrics,
    version: String,
}

pub(super) struct StatusContent<'a> {
    pub(super) position: String,
    pub(super) performance: &'a [StatusMetric; 3],
    pub(super) system_performance: &'a [StatusMetric; 4],
    pub(super) version: &'a str,
}

/// A fixed status-strip slot. The label and location are static RML; only the
/// native value and its semantic severity change at runtime.
pub(super) struct StatusMetric {
    pub(super) value: String,
    pub(super) tone: MetricTone,
}

#[derive(Clone, Copy, PartialEq, Eq)]
pub(super) enum MetricTone {
    Normal,
    Healthy,
    Warning,
    Critical,
}

impl MetricTone {
    pub(super) const ALL: [Self; 4] = [Self::Normal, Self::Healthy, Self::Warning, Self::Critical];

    pub(super) const fn class(self) -> &'static str {
        match self {
            Self::Normal => "normal",
            Self::Healthy => "healthy",
            Self::Warning => "warning",
            Self::Critical => "critical",
        }
    }
}

impl Default for StatusMetric {
    fn default() -> Self {
        Self {
            value: String::new(),
            tone: MetricTone::Normal,
        }
    }
}

impl StatusPresenter {
    pub(super) fn new(interface: &NativeInterfaceRef) -> Self {
        Self {
            last_metrics_refresh: None,
            performance: Default::default(),
            system_performance: Default::default(),
            system_metrics: SystemMetrics::new(),
            version: game_version(interface),
        }
    }

    pub(super) fn refresh<'a>(
        &'a mut self,
        interface: &NativeInterfaceRef,
        selection: &SelectionManager,
    ) -> StatusContent<'a> {
        let now = Instant::now();
        if self.performance[0].value.is_empty()
            || self
                .last_metrics_refresh
                .is_none_or(|last| now.duration_since(last) >= Duration::from_secs(2))
        {
            (self.performance, self.system_performance) =
                performance(interface, &mut self.system_metrics);
            self.last_metrics_refresh = Some(now);
        }
        StatusContent {
            position: status_position(interface, selection),
            performance: &self.performance,
            system_performance: &self.system_performance,
            version: &self.version,
        }
    }
}

fn status_position(interface: &NativeInterfaceRef, selection: &SelectionManager) -> String {
    let ground = cursor(interface)
        .and_then(|mouse| trace_ground(interface, mouse.x, mouse.y))
        .map(|hit| format!("X: {:.0}, Y: {:.0}, Z: {:.0}", hit.x, hit.y, hit.z))
        .unwrap_or_else(|| "Off-screen".to_string());
    match selection.count() {
        0 => format!("{ground}. No selection"),
        1 => selection
            .primary()
            .map(|(_, id)| format!("{ground}. Selected: 1 (ID={id})"))
            .unwrap_or_else(|| format!("{ground}. Selected: 1")),
        count => format!("{ground}. Selected: {count}"),
    }
}

fn performance(
    interface: &NativeInterfaceRef,
    system_metrics: &mut SystemMetrics,
) -> ([StatusMetric; 3], [StatusMetric; 4]) {
    let fps = interface.display().get_fps().unwrap_or_default();
    let memory = interface
        .profiling()
        .get_lua_mem_usage()
        .map(|(_, _, global, ..)| global / 1024.0)
        .unwrap_or_default();
    let (video_used, video_available) = interface
        .profiling()
        .get_vid_mem_usage()
        .unwrap_or_default();
    let system = system_metrics.sample();
    let process_cpus = system.process_cpu / 100.0;
    let system_cpus = system.system_cpu / 100.0 * system.logical_cpus.max(1) as f32;
    (
        [
            metric(format!("{fps}"), fps_tone(fps as f32)),
            metric(
                format!("{process_cpus:.1} CPUs"),
                usage_tone(process_cpus / system.logical_cpus.max(1) as f32),
            ),
            metric(
                format!("{system_cpus:.1} / {} CPUs", system.logical_cpus.max(1)),
                usage_tone(system.system_cpu / 100.0),
            ),
        ],
        [
            metric(format!("{memory:.0} MiB"), MetricTone::Normal),
            metric(
                format!("{video_used:.0} / {video_available:.0} MiB"),
                usage_tone(ratio(video_used, video_available)),
            ),
            metric(
                format!(
                    "{:.1} / {:.1} GiB",
                    bytes_to_gib(system.system_used_memory),
                    bytes_to_gib(system.system_total_memory)
                ),
                usage_tone(ratio(
                    system.system_used_memory as f32,
                    system.system_total_memory as f32,
                )),
            ),
            metric(
                format!("{} MiB", bytes_to_mib(system.process_memory)),
                MetricTone::Normal,
            ),
        ],
    )
}

fn metric(value: String, tone: MetricTone) -> StatusMetric {
    StatusMetric { value, tone }
}

fn usage_tone(used: f32) -> MetricTone {
    if used >= 0.90 {
        MetricTone::Critical
    } else if used >= 0.70 {
        MetricTone::Warning
    } else {
        MetricTone::Healthy
    }
}
fn fps_tone(fps: f32) -> MetricTone {
    if fps < 30.0 {
        MetricTone::Critical
    } else if fps < 55.0 {
        MetricTone::Warning
    } else {
        MetricTone::Healthy
    }
}
fn ratio(used: f32, total: f32) -> f32 {
    if total > 0.0 {
        used / total
    } else {
        0.0
    }
}
fn bytes_to_mib(bytes: u64) -> u64 {
    bytes / (1024 * 1024)
}
fn bytes_to_gib(bytes: u64) -> f64 {
    bytes as f64 / (1024.0 * 1024.0 * 1024.0)
}

fn game_version(interface: &NativeInterfaceRef) -> String {
    let Ok(info) = interface.game().get_game_mod_info_owned() else {
        return "SpringBoard".to_string();
    };
    let name = if info.game_name.is_empty() {
        "SpringBoard".to_string()
    } else {
        info.game_name
    };
    format!("{name} {}", info.game_version).trim().to_string()
}
