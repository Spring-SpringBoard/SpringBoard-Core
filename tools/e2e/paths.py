from __future__ import annotations

from pathlib import Path


SBC_ROOT = Path(__file__).resolve().parent.parent.parent
ARTIFACT_ROOT = SBC_ROOT / "artifacts" / "ui-e2e"
GAME_DIRNAME = "SpringBoard Core.sdd"
TOOLS_SMOKE = SBC_ROOT / "tools" / "smoke"
