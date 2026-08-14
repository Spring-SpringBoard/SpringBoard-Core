use sysinfo::{get_current_pid, Pid, ProcessesToUpdate, System};

#[derive(Debug, Clone, Copy)]
pub(crate) struct SystemSnapshot {
    pub system_cpu: f32,
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
        let system = System::new();
        let process = get_current_pid().ok();
        let mut metrics = Self { system, process };
        metrics.refresh();
        metrics
    }

    pub(crate) fn sample(&mut self) -> SystemSnapshot {
        self.refresh();
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

    fn refresh(&mut self) {
        self.system.refresh_cpu_usage();
        self.system.refresh_memory();
        if let Some(pid) = self.process {
            self.system
                .refresh_processes(ProcessesToUpdate::Some(&[pid]), true);
        }
    }
}
