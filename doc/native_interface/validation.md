# Native Interface Validation

To ensure feature parity between the legacy Lua bridge and the new native interface, we plan a capture/replay workflow rather than traditional unit tests:

1. **Capture Phase** – launch a dedicated "test game" where Lua scripts exercise each targeted API (covering multiple argument patterns) and log inputs, outputs, and relevant side effects.
2. **Replay Phase** – run the same scenario with a Rust module using the native interface, capturing its outputs and state transitions.
3. **Comparison** – diff the recorded data sets to confirm behavior matches before enabling the native path for production tools.

This approach gives high confidence with minimal bespoke harnesses. Classic unit or performance tests can still be added later if desired.
