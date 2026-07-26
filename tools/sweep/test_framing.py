"""Tests for the sweep's framings and the angle registry.

No editor: this is the part with logic worth checking. The overhead camera measures
its tilt from straight down while a framing is stated as an angle above the
horizontal, and getting that backwards silently produces top-down captures at every
angle -- which still looks like a working sweep.
"""

import math

import pytest

from sweep.framing import Framing
from sweep.registry import NAMES, angle, angles


def test_overhead_pitch_is_zero_tilt() -> None:
    assert Framing("t", distance=100, pitch_deg=90).tilt_rad == pytest.approx(0.0)


def test_level_pitch_is_a_quarter_turn_of_tilt() -> None:
    assert Framing("t", distance=100, pitch_deg=0).tilt_rad == pytest.approx(math.pi / 2)


def test_lower_pitch_means_more_tilt() -> None:
    steep = Framing("steep", distance=100, pitch_deg=60).tilt_rad
    shallow = Framing("shallow", distance=100, pitch_deg=10).tilt_rad

    assert shallow > steep


def test_a_framing_passes_its_distance_and_tilt_to_the_scene() -> None:
    options = Framing("t", distance=210, pitch_deg=28).modoptions()

    assert float(options["sb_dev_scene_dist"]) == pytest.approx(210)
    assert float(options["sb_dev_scene_tilt"]) == pytest.approx(math.radians(62), abs=1e-3)


@pytest.mark.parametrize("name", NAMES)
def test_every_registered_angle_loads_and_is_usable(name: str) -> None:
    loaded = angle(name)

    assert loaded.distance > 0
    assert loaded.name


@pytest.mark.parametrize("name", NAMES)
def test_every_registered_angle_stays_inside_the_cameras_clamped_range(name: str) -> None:
    """The overhead camera clamps `angle` to (0, pi/2]; outside it, a framing
    silently becomes a different shot than the one asked for."""
    assert 0.0 < angle(name).tilt_rad <= math.pi / 2


def test_angles_defaults_to_every_registered_angle() -> None:
    assert len(angles()) == len(NAMES)


def test_angles_can_be_narrowed_to_a_selection() -> None:
    assert tuple(framing.name for framing in angles(("mid",))) == ("mid",)


def test_an_unknown_angle_names_the_ones_that_exist() -> None:
    with pytest.raises(ValueError, match="no angle 'nope'"):
        angle("nope")
