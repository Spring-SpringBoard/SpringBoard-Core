//! Low-frequency machine and process metrics for the editor status strip.
//!
//! The engine already reports the renderer's VRAM use, which is portable across
//! GPU drivers. `sysinfo` supplies the missing system/process CPU and RAM data
//! without making the editor depend on NVIDIA's NVML runtime.

use sysinfo::{get_current_pid, Pid, ProcessesToUpdate, System};

#[derive(Debug, Clone, Copy)]
pub(crate) struct SystemSnapshot {
    /// Whole-machine CPU use, normalised as a percentage by sysinfo.
    pub system_cpu: f32,
    /// Can exceed 100% when the editor uses several cores.
    pub process_cpu: f32,
    pub logical_cpus: usize,
    pub system_used_memory: u64,
    pub system_total_memory: u64,
    pub process_memory: u64,
}

pub(crate) struct SystemMetrics {
    system: System,
    process: Option<Pid>,
}

impl SystemMetrics {
    pub(crate) fn new() -> Self {
        let mut system = System::new();
        system.refresh_cpu_usage();
        system.refresh_memory();
        let process = get_current_pid().ok();
        if let Some(pid) = process {
            system.refresh_processes(ProcessesToUpdate::Some(&[pid]), true);
        }
        Self { system, process }
    }

    /// Refresh at the status cadence (about once each second), never per frame.
    pub(crate) fn sample(&mut self) -> SystemSnapshot {
        self.system.refresh_cpu_usage();
        self.system.refresh_memory();
        if let Some(pid) = self.process {
            self.system
                .refresh_processes(ProcessesToUpdate::Some(&[pid]), true);
        }
        let process = self.process.and_then(|pid| self.system.process(pid));
        SystemSnapshot {
            system_cpu: self.system.global_cpu_usage(),
            process_cpu: process.map_or(0.0, |info| info.cpu_usage()),
            logical_cpus: self.system.cpus().len(),
            system_used_memory: self.system.used_memory(),
            system_total_memory: self.system.total_memory(),
            process_memory: process.map_or(0, |info| info.memory()),
        }
    }
}
