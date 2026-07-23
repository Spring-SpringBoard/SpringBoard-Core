use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

use crate::sbc::sbc::SBC;

pub type TestFn = fn(&mut TestCtx) -> Result<(), String>;

pub struct IntegrationTest {
    pub name: &'static str,
    /// The test's slice, taken from its module path (e.g. `..::textures::..`).
    /// Callers filter on a substring of this; see [`integration_test`].
    pub tag: &'static str,
    pub run: TestFn,
    /// Opt-in tests are skipped by the default (unfiltered) run and only execute
    /// when a filter explicitly selects their tag. Use for slow tests (e.g. a
    /// full map compile) that shouldn't tax every suite run.
    pub opt_in: bool,
}

inventory::collect!(IntegrationTest);

/// Register an in-engine integration test, tagging it with its module path so the
/// runner can filter by slice without anyone maintaining a list. The optional
/// `opt_in` form registers a test that only runs when its tag is explicitly
/// requested.
#[macro_export]
macro_rules! integration_test {
    ($name:expr, $run:expr) => {
        $crate::integration_test!($name, $run, opt_in = false);
    };
    ($name:expr, $run:expr, opt_in = $opt_in:expr) => {
        inventory::submit! {
            $crate::sbc::tests::tests_api::IntegrationTest {
                name: $name,
                tag: module_path!(),
                run: $run,
                opt_in: $opt_in,
            }
        }
    };
}

pub struct TestCtx<'a> {
    pub sbc: &'a mut SBC,
}

static NEXT_TEST_COMMAND_ID: AtomicU64 = AtomicU64::new(1_000_000);

impl TestCtx<'_> {
    /// Route a command payload the way Lua does: wrapped and carrying `__cmd_id`.
    pub fn route_command(&mut self, mut data: Value) {
        if let Some(obj) = data.as_object_mut() {
            obj.entry("__cmd_id").or_insert_with(|| {
                Value::from(NEXT_TEST_COMMAND_ID.fetch_add(1, Ordering::Relaxed))
            });
        }
        self.sbc
            .route(&serde_json::json!({ "tag": "command", "data": data }).to_string());
    }

    /// Route a non-command message (e.g. `save_model`) under an explicit tag.
    #[allow(dead_code)]
    pub fn route_message(&mut self, tag: &str, data: Value) {
        self.sbc
            .route(&serde_json::json!({ "tag": tag, "data": data }).to_string());
    }

    /// Block until `path` exists or `timeout` elapses, pumping background IO.
    pub fn wait_for_file(&mut self, path: &std::path::Path, timeout: Duration) -> bool {
        self.wait_for_io(timeout, |_| path.is_file())
    }

    /// Block until `done` observes the wanted state or `timeout` elapses,
    /// draining background-IO outcomes each poll (the synced tick is blocked
    /// while a test runs, so the test pumps IO itself).
    pub fn wait_for_io(
        &mut self,
        timeout: Duration,
        mut done: impl FnMut(&mut SBC) -> bool,
    ) -> bool {
        let deadline = Instant::now() + timeout;
        loop {
            self.sbc.drain_io();
            if done(self.sbc) {
                return true;
            }
            if Instant::now() >= deadline {
                return false;
            }
            // Keep the heartbeat fresh while a test blocks the engine tick, so
            // the external harness doesn't mistake a working test for a hang.
            beat_heartbeat();
            std::thread::sleep(Duration::from_millis(20));
        }
    }

    pub fn heartbeat(&self) {
        beat_heartbeat();
    }
}

#[derive(Default, Deserialize)]
struct TestSpec {
    /// Optional slice filter: run tests whose tag contains any of these
    /// substrings. Absent (or empty) runs every registered test.
    #[serde(default)]
    tags: Vec<String>,
}

#[derive(Serialize)]
struct TestResult {
    name: String,
    passed: bool,
    message: String,
}

#[derive(Serialize)]
struct TestResults {
    results: Vec<TestResult>,
}

pub fn run_if_requested(sbc: &mut SBC) -> bool {
    let spec_path = match std::env::var("SBC_TEST_SPEC") {
        Ok(p) if !p.is_empty() => p,
        _ => return false,
    };

    let spec_raw = match std::fs::read_to_string(&spec_path) {
        Ok(s) => s,
        Err(err) => {
            log::error!("test spec {spec_path}: {err}");
            return true;
        }
    };
    let spec: TestSpec = serde_json::from_str(&spec_raw).unwrap_or_default();
    let filters: Vec<&str> = spec
        .tags
        .iter()
        .map(String::as_str)
        .filter(|t| !t.is_empty())
        .collect();

    beat_heartbeat();

    // Deep run (`SBC_TEST_DEEP=1`, via `just test-deep`) includes opt-in tests
    // even without an explicit tag filter.
    let include_opt_in = matches!(
        std::env::var("SBC_TEST_DEEP").as_deref(),
        Ok("1") | Ok("true")
    );

    let mut tests: Vec<&IntegrationTest> = inventory::iter::<IntegrationTest>
        .into_iter()
        .filter(|t| {
            if filters.is_empty() {
                // Default run: everything except opt-in (slow) tests, unless deep.
                include_opt_in || !t.opt_in
            } else {
                // Explicit filter: run matches, including opt-in tests.
                filters.iter().any(|f| t.tag.contains(f))
            }
        })
        .collect();
    tests.sort_by_key(|t| (t.tag, t.name));

    let mut results = Vec::new();
    for test in tests {
        beat_heartbeat();
        log::info!("[sbc-test] running {}", test.name);
        let mut ctx = TestCtx { sbc };
        let (passed, message) = match (test.run)(&mut ctx) {
            Ok(()) => (true, String::new()),
            Err(msg) => (false, msg),
        };
        log::info!(
            "[sbc-test] {} {}",
            test.name,
            if passed { "PASS" } else { "FAIL" }
        );
        results.push(TestResult {
            name: test.name.to_string(),
            passed,
            message,
        });
    }

    let out = TestResults { results };
    let results_path =
        std::env::var("SBC_TEST_RESULTS").unwrap_or_else(|_| "sbc_test_results.json".to_string());
    match serde_json::to_string_pretty(&out) {
        Ok(json) => {
            if let Err(err) = std::fs::write(&results_path, json) {
                log::error!("write test results {results_path}: {err}");
            }
        }
        Err(err) => log::error!("serialize test results: {err}"),
    }

    log::info!("[sbc-test] done; quitting engine");
    let _ = sbc.interface().system_control().quit();

    true
}

fn beat_heartbeat() {
    if let Ok(path) = std::env::var("SBC_TEST_HEARTBEAT") {
        if !path.is_empty() {
            let _ = std::fs::write(&path, b"1");
        }
    }
}
