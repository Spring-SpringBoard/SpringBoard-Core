from datetime import UTC, datetime
from pathlib import Path

SBC_ROOT = Path(__file__).resolve().parent.parent.parent
ARTIFACT_ROOT = SBC_ROOT / "artifacts" / "ui-e2e"
GAME_DIRNAME = "SpringBoard Core.sdd"


def create_suite_artifact_dir() -> Path:
    """Create a collision-free timestamped directory for a grouped run."""
    stamp = datetime.now(UTC).strftime("%Y%m%d-%H%M%S")
    candidate = ARTIFACT_ROOT / f"{stamp}-suite"
    suffix = 2
    while candidate.exists():
        candidate = ARTIFACT_ROOT / f"{stamp}-suite-{suffix}"
        suffix += 1
    candidate.mkdir(parents=True)
    return candidate
