use std::sync::mpsc::{Receiver, Sender, TryRecvError};

use log::error;

use super::io_api::{IoJob, IoOutcome};

/// Owns the background worker thread and the channels to it. `submit` queues a
/// job (engine thread → worker); `drain` collects finished outcomes back.
/// Created once at plugin init, lives the whole plugin lifetime. The thread is
/// detached — the OS reclaims it when the process goes away.
pub struct IoWorker {
    job_tx: Sender<Box<dyn IoJob>>,
    outcome_rx: Receiver<Box<dyn IoOutcome>>,
}

impl IoWorker {
    pub fn new() -> Self {
        let (job_tx, job_rx) = std::sync::mpsc::channel::<Box<dyn IoJob>>();
        let (outcome_tx, outcome_rx) = std::sync::mpsc::channel::<Box<dyn IoOutcome>>();

        std::thread::Builder::new()
            .name("sbc-io".to_string())
            .spawn(move || {
                // Exits when the job channel closes (IoWorker dropped) or the
                // outcome channel closes (engine side gone).
                while let Ok(job) = job_rx.recv() {
                    if outcome_tx.send(job.run()).is_err() {
                        break;
                    }
                }
            })
            .expect("failed to spawn sbc-io worker thread");

        IoWorker { job_tx, outcome_rx }
    }

    #[allow(dead_code)] // first job type lands with the heightmap slice
    pub fn submit(&self, job: Box<dyn IoJob>) {
        if self.job_tx.send(job).is_err() {
            error!("IO worker thread is gone; job dropped");
        }
    }

    /// Collect all outcomes ready right now. Non-blocking.
    pub fn drain(&self) -> Vec<Box<dyn IoOutcome>> {
        let mut out = Vec::new();
        loop {
            match self.outcome_rx.try_recv() {
                Ok(r) => out.push(r),
                Err(TryRecvError::Empty) => break,
                Err(TryRecvError::Disconnected) => {
                    error!("IO worker outcome channel disconnected");
                    break;
                }
            }
        }
        out
    }
}
