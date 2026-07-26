"""What a camera framing is, and how it reaches the engine.

Applied by the dev-scene gadget at boot, not over the control channel. The channel
can aim the camera but not place the eye: `camera.set(position=...)` writes the
camera controller's `pos`, which for the editor's overhead camera is the ground
point it orbits rather than the eye. Asking for an eye 420 elmos from the subject
left the camera 5190 elmos away, so framing goes through the gadget, which speaks
that camera's own `height` and `angle`.

The cost is one engine boot per framing. Everything else in a sweep -- opening the
editor, switching debug view, capturing -- goes over the channel.

The framings themselves live one per module in `angles/`.
"""

import math
from dataclasses import dataclass

# Straight down, in the overhead camera's `angle` convention.
_OVERHEAD_DEG = 90.0


@dataclass(frozen=True)
class Framing:
    """One camera setup, in terms of the subject rather than world coordinates."""

    name: str
    distance: float
    """Eye distance from the subject, in elmos."""
    pitch_deg: float
    """Angle above the horizontal. 0 is level with the subject, 90 is above it."""

    @property
    def tilt_rad(self) -> float:
        """Pitch in the overhead camera's `angle` terms: 0 is straight down."""
        return math.radians(_OVERHEAD_DEG - self.pitch_deg)

    def modoptions(self) -> dict[str, str]:
        """How the dev-scene gadget receives this framing."""
        return {
            "sb_dev_scene_dist": f"{self.distance:.0f}",
            "sb_dev_scene_tilt": f"{self.tilt_rad:.3f}",
        }
