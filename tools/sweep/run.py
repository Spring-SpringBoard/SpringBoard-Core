"""The sweep itself: angles x debug views, one engine session per angle.

Every command in `cli_sweep` is this function with different arguments. Nothing
about a sweep varies except which angles it visits and how many views it captures,
so there is one implementation and the commands only choose.
"""

from pathlib import Path

from control import Editor

from . import capture
from .framing import Framing

EDITOR = "assetShaderEditor"
DEBUG_FIELD = "debugView"

# The right-hand panel's fixed width, cropped away so a frame is about the asset.
_PANEL_WIDTH = 500

_SHEET_COLUMNS = 3


def sweep(
    angles: tuple[Framing, ...],
    out: Path,
    project: str = "6",
    scene: str = "gen_arch",
    view_limit: int | None = None,
) -> list[Path]:
    """Capture `angles`, each with up to `view_limit` debug views.

    Args:
        angles: Framings to visit, one engine session each.
        out: Directory for the captures and contact sheets.
        project: SpringBoard project holding the asset.
        scene: featureDef the dev scene places.
        view_limit: Stop after this many debug views. `None` captures all of them;
            `1` is the quick "does it render at all" check.

    Returns:
        Every cropped capture written, in order.
    """
    out = out.resolve()
    written: list[Path] = []
    for framing in angles:
        written.extend(_sweep_angle(project, scene, framing, out, view_limit))
    print(f"\n{out}")
    return written


def _sweep_angle(
    project: str,
    scene: str,
    framing: Framing,
    out: Path,
    view_limit: int | None,
) -> list[Path]:
    proc, _write_dir, control = capture.start_session(project, scene, framing.modoptions())
    try:
        # Declared before anything is captured, so an editor or field that no longer
        # exists costs a connect rather than a whole run.
        shader = control.editor(EDITOR)
        views = _debug_views(shader)[:view_limit]

        written: list[Path] = []
        region: str | None = None
        for view in views:
            shader.set(DEBUG_FIELD, view)
            slug = view.lower().replace(" ", "-")
            raw = control.capture(out / "raw" / f"{framing.name}-{slug}.png")
            if region is None:
                region = _crop_region(raw)
            written.append(capture.crop(raw, out / f"{framing.name}-{slug}.png", region))

        if len(written) > 1:
            capture.contact_sheet(written, out / f"sheet-{framing.name}.png", _SHEET_COLUMNS)
        print(f"{framing.name}: {len(written)} view(s) at distance {framing.distance:.0f}")
        return written
    finally:
        control.close()
        capture.stop_session(proc)


def sweep_field(
    field: str,
    values: tuple[float, ...],
    angles: tuple[Framing, ...],
    out: Path,
    project: str = "6",
    scene: str = "gen_arch",
) -> list[Path]:
    """Capture the final view once per value of a numeric shader field.

    For calibrating a uniform against something measurable rather than by eye. One engine
    session per angle covers every value, because the field is set over the control channel
    and needs no reload -- which is what makes a sweep of a dozen settings affordable.

    Args:
        field: Schema name of the field, e.g. ``detailStrength``.
        values: Settings to capture, in order.
        angles: Framings to visit, one engine session each.
        out: Directory for the captures.
        project: SpringBoard project holding the asset.
        scene: featureDef the dev scene places.

    Returns:
        Every cropped capture written, in order.
    """
    out = out.resolve()
    written: list[Path] = []
    for framing in angles:
        written.extend(_sweep_field_angle(project, scene, framing, out, field, values))
    print(f"\n{out}")
    return written


def _sweep_field_angle(
    project: str,
    scene: str,
    framing: Framing,
    out: Path,
    field: str,
    values: tuple[float, ...],
) -> list[Path]:
    proc, _write_dir, control = capture.start_session(project, scene, framing.modoptions())
    try:
        shader = control.editor(EDITOR)
        if field not in shader.fields:
            raise RuntimeError(f"{EDITOR} has no field {field!r}")

        written: list[Path] = []
        region: str | None = None
        for value in values:
            shader.set(field, value)
            slug = f"{field}-{value:g}".replace(".", "_")
            raw = control.capture(out / "raw" / f"{framing.name}-{slug}.png")
            if region is None:
                region = _crop_region(raw)
            written.append(capture.crop(raw, out / f"{framing.name}-{slug}.png", region))

        print(f"{framing.name}: {len(written)} value(s) of {field} at {framing.distance:.0f}")
        return written
    finally:
        control.close()
        capture.stop_session(proc)


def _debug_views(shader: Editor) -> tuple[str, ...]:
    """The debug views the editor actually offers.

    Read from the schema rather than duplicated here: a list in two places goes out
    of sync silently, and a stale copy mislabels every capture in a run.
    """
    options = shader.fields[DEBUG_FIELD].options
    if not options:
        raise RuntimeError(f"{EDITOR}.{DEBUG_FIELD} offers no options to sweep")
    return options


def _crop_region(sample: Path) -> str:
    """Crop away the right-hand panel and the status bar, keeping the subject.

    Measured from a captured frame rather than asked for: the control channel does
    not report the viewport, and the image is the authority on its own size anyway.

    Cropped rather than resized -- these frames are looked at, so native resolution
    is the point.
    """
    width, height = capture.image_size(sample)
    left = width - _PANEL_WIDTH
    return f"{int(left * 0.72)}x{int(height * 0.52)}+{int(left * 0.14)}+{int(height * 0.16)}"
