# E2E testing

1. Run everything once; do not stop on the first failure.
2. Fix all failures and test only the failed tests until they all pass.
3. Once every previously failing test passes independently, rerun the whole sweep, including tests that passed initially.

Inspect and analyse every visual difference. If a visual difference exposes a real issue, tighten the E2E assertions where possible so the behavior is tested deterministically with less dependence on pixel comparison.
