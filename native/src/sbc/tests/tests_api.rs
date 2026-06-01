use serde::{Deserialize, Serialize};

use crate::sbc::sbc::SBC;

pub type TestFn = fn(&mut TestCtx) -> Result<(), String>;

pub struct IntegrationTest {
    pub name: &'static str,
    pub run: TestFn,
}

inventory::collect!(IntegrationTest);

pub struct TestCtx<'a> {
    pub sbc: &'a mut SBC,
}

fn beat_heartbeat() {
    if let Ok(path) = std::env::var("SBC_TEST_HEARTBEAT") {
        if !path.is_empty() {
            let _ = std::fs::write(&path, b"1");
        }
    }
}

#[derive(Deserialize)]
struct TestSpec {
    tests: Vec<String>,
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
    let spec: TestSpec = match serde_json::from_str(&spec_raw) {
        Ok(s) => s,
        Err(err) => {
            log::error!("test spec parse: {err}");
            return true;
        }
    };

    beat_heartbeat();

    let mut results = Vec::new();
    for name in &spec.tests {
        beat_heartbeat();
        let test = inventory::iter::<IntegrationTest>
            .into_iter()
            .find(|t| t.name == name);
        let result = match test {
            None => TestResult {
                name: name.clone(),
                passed: false,
                message: "no such registered test".to_string(),
            },
            Some(test) => {
                log::info!("[sbc-test] running {name}");
                let mut ctx = TestCtx { sbc };
                match (test.run)(&mut ctx) {
                    Ok(()) => TestResult {
                        name: name.clone(),
                        passed: true,
                        message: String::new(),
                    },
                    Err(msg) => TestResult {
                        name: name.clone(),
                        passed: false,
                        message: msg,
                    },
                }
            }
        };
        log::info!(
            "[sbc-test] {} {}",
            result.name,
            if result.passed { "PASS" } else { "FAIL" }
        );
        results.push(result);
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
