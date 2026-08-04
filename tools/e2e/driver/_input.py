import os
import subprocess
import sys
from collections.abc import Generator
from contextlib import contextmanager
from typing import override

from .state import RunState
from .timing import TEXT_INTERVAL_MS, Delay, Timeout, pause
from .utils.process import run
from .utils.run_env import MODIFIER_NAMES, MODIFIERS
from .utils.x11 import window_geometry_values


class InputMixin(RunState):
    """Synthesised keyboard and mouse input, plus the X clipboard.

    Everything here drives the engine window through `xdotool`. The recurring
    subtlety is that `xdotool --window` delivers an event with the modifier
    state cleared, so any chord (Ctrl-drag, Shift-wheel) has to go through the
    focused root window instead; the affected methods say so where it matters.
    """

    @override
    def focus(self) -> None:
        self.require_window()
        run("xdotool", "windowactivate", self.window, "windowfocus", self.window, check=False)
        pause(Delay.INPUT)
        self.release_modifiers()
        self.event("focus", window=self.window)

    def release_modifiers(self) -> None:
        self.require_window()
        args = ["xdotool"]
        for modifier in MODIFIERS:
            args += ["keyup", "--window", self.window, modifier]
        run(*args, check=False)
        pause(Delay.EVENT)

    @override
    def key(self, name: str, delay: Delay = Delay.INPUT) -> None:
        self.require_window()
        self.event("key", key=name)
        if "+" in name:
            # `xdotool key --window <win> ctrl+c` delivers the `c` press with the
            # modifier already cleared, so the engine reports ctrl=false. Send the
            # chord to the focused window instead, holding the modifiers down.
            self.focus()
            *modifiers, base = name.split("+")
            for modifier in modifiers:
                run("xdotool", "keydown", modifier)
            run("xdotool", "key", base)
            for modifier in reversed(modifiers):
                run("xdotool", "keyup", modifier)
        else:
            run("xdotool", "key", "--window", self.window, name)
        pause(delay)

    @contextmanager
    @override
    def modifier(self, name: str) -> Generator[None]:
        """Hold a modifier down across other input, for a chord like Ctrl-drag.

        Sent to the focused window rather than with `--window`: as with `key`,
        `xdotool --window` delivers the event with the modifier already cleared,
        and the engine then reports the modifier as up.
        """
        self.focus()
        self.event("modifier_down", modifier=name)
        run("xdotool", "keydown", name)
        try:
            yield
        finally:
            run("xdotool", "keyup", name)
            self.event("modifier_up", modifier=name)

    @override
    def key_chord(self, modifiers: tuple[str, ...], name: str, delay: Delay = Delay.INPUT) -> None:
        self.require_window()
        normalized = tuple(MODIFIER_NAMES.get(mod, mod) for mod in modifiers)
        chord = "+".join((*normalized, name))
        self.event("key_chord", chord=chord)
        run("xdotool", "key", "--window", self.window, chord)
        pause(delay)

    @override
    def type_text(self, text: str, delay_ms: int = TEXT_INTERVAL_MS) -> None:
        self.require_window()
        # A focused text field (notably Chonsole after Return) has to exist
        # before its characters arrive. This is a next-frame barrier for the
        # preceding click/key, not a fixed text-entry delay.
        self.sync_input()
        self.event("type", text=text)
        for index, fragment in enumerate(text.split("/")):
            if fragment:
                run(
                    "xdotool",
                    "type",
                    "--window",
                    self.window,
                    "--delay",
                    str(delay_ms),
                    "--",
                    fragment,
                )
            if index < text.count("/"):
                # Spring consumes physical scancodes while xdotool resolves a
                # keysym through the active X layout; keycode 61 is slash in
                # the engine's fixed layout even when that layout maps it to &.
                run("xdotool", "key", "--window", self.window, "keycode", "61")
        pause(Delay.INPUT)

    @override
    def fill_text(
        self,
        x: int,
        y: int,
        text: str,
        *,
        click_delay: Delay = Delay.CONTROL,
        commit_delay: Delay = Delay.SETTLE,
    ) -> None:
        self.click(x, y, delay=click_delay)
        self.key("ctrl+a", delay=Delay.INPUT)
        self.type_text(text)
        self.key("Return", delay=commit_delay)

    @override
    def click(self, x: int, y: int, button: int = 1, delay: Delay = Delay.INPUT) -> None:
        self.require_window()
        self.event("click", x=x, y=y, button=button)
        run(
            "xdotool",
            "mousemove",
            "--window",
            self.window,
            str(x),
            str(y),
            "click",
            str(button),
        )
        pause(delay)

    @override
    def click_settled(self, x: int, y: int, button: int = 1, delay: Delay = Delay.INPUT) -> None:
        """Click after one engine input tick at the target position.

        Most controls accept a compact ``click``. A toolbar action immediately
        after map editing can otherwise be hit-tested at the previous map
        position, so a scenario can opt into this precise move/press sequence
        instead of sleeping on a guessed UI transition.
        """
        self.require_window()
        self.event("click_settled", x=x, y=y, button=button)
        run("xdotool", "mousemove", "--window", self.window, str(x), str(y))
        pause(Delay.CONTROL)
        run("xdotool", "mousedown", str(button))
        pause(Delay.POLL)
        run("xdotool", "mouseup", str(button))
        pause(delay)

    @override
    def move(self, x: int, y: int, delay: Delay = Delay.INPUT) -> None:
        self.require_window()
        self.event("move", x=x, y=y)
        run("xdotool", "mousemove", "--window", self.window, str(x), str(y))
        pause(delay)

    @override
    def move_relative(self, dx: int, dy: int = 0, steps: int = 6, delay: Delay = Delay.INPUT) -> None:
        """Move the mouse *by* an offset, the way a real mouse reports motion.

        A field drag pins the pointer and warps it back after every move, so what
        it consumes is relative motion. Absolute `mousemove` fights that: the
        pointer is put back on its anchor and the next absolute move re-applies
        the whole offset from it.
        """
        self.require_window()
        self.event("move_relative", dx=dx, dy=dy, steps=steps)
        for _ in range(steps):
            run(
                "xdotool",
                "mousemove_relative",
                "--sync",
                "--",
                str(round(dx / steps)),
                str(round(dy / steps)),
            )
            pause(delay)

    @override
    def wheel(self, x: int, y: int, clicks: int = 1, up: bool = True, delay: Delay = Delay.FRAME) -> None:
        """Scroll the wheel over a point for a UI interaction under test.

        Domain scenarios frame the map through ``control.camera.zoom``; this
        remains for genuine wheel contracts such as Chonsole suggestion scroll.
        """
        self.require_window()
        self.event("wheel", x=x, y=y, clicks=clicks, up=up)
        button = "4" if up else "5"
        run("xdotool", "mousemove", "--window", self.window, str(x), str(y))
        for _ in range(clicks):
            run("xdotool", "click", "--window", self.window, button)
            pause(Delay.EVENT)
        pause(delay)

    @override
    def wheel_root(self, x: int, y: int, clicks: int = 1, up: bool = True, delay: Delay = Delay.FRAME) -> None:
        """Scroll the wheel with the real pointer, so a held modifier applies.

        `xdotool click --window` synthesises the event with the modifier state
        cleared -- the engine then reports shift as up -- so a Shift+wheel chord
        has to go through the root window, as `key` does for the same reason.
        """
        self.event("wheel_root", x=x, y=y, clicks=clicks, up=up)
        button = "4" if up else "5"
        root_x, root_y = self._root_point(x, y)
        run("xdotool", "mousemove", str(root_x), str(root_y))
        for _ in range(clicks):
            run("xdotool", "click", button)
            pause(Delay.EVENT)
        pause(delay)

    @override
    def click_root(self, x: int, y: int, button: int = 1, delay: Delay = Delay.INPUT) -> None:
        self.event("click_root", x=x, y=y, button=button)
        root_x, root_y = self._root_point(x, y)
        run("xdotool", "mousemove", str(root_x), str(root_y), "click", str(button))
        pause(delay)

    def drag_root(
        self,
        x1: int,
        y1: int,
        x2: int,
        y2: int,
        button: int = 1,
        steps: int = 12,
        step_delay: Delay = Delay.EVENT,
    ) -> None:
        # Modal dialogs sometimes need the real pointer rather than an SDL
        # window-targeted click. Establish the start in client coordinates,
        # though: borderless SDL windows can report a decorated X11 origin even
        # when SDL delivers motion coordinates relative to the client. Adding
        # that origin here would shift the press outside the intended control.
        self.event("drag_root", x1=x1, y1=y1, x2=x2, y2=y2, button=button, steps=steps)
        run("xdotool", "mousemove", "--window", self.window, str(x1), str(y1))
        pause(Delay.CONTROL)
        run("xdotool", "mousedown", "--window", self.window, str(button))
        pause(step_delay)
        for i in range(1, steps + 1):
            xi = round(x1 + (x2 - x1) * i / steps)
            yi = round(y1 + (y2 - y1) * i / steps)
            run("xdotool", "mousemove", "--window", self.window, str(xi), str(yi))
            pause(step_delay)
        run("xdotool", "mouseup", "--window", self.window, str(button))
        pause(Delay.CONTROL)

    @override
    def press(self, x: int, y: int, button: int = 1, delay: Delay = Delay.CONTROL) -> None:
        """Hold the button down. Pair with `move` + `release` when the scenario
        has to capture something that only exists *during* the drag, like the
        selection rectangle."""
        self.require_window()
        self.event("press", x=x, y=y, button=button)
        run("xdotool", "mousemove", "--window", self.window, str(x), str(y))
        pause(Delay.CONTROL)
        run("xdotool", "mousedown", "--window", self.window, str(button))
        pause(delay)

    @override
    def release(self, x: int, y: int, button: int = 1, delay: Delay = Delay.FRAME) -> None:
        self.require_window()
        self.event("release", x=x, y=y, button=button)
        run("xdotool", "mousemove", "--window", self.window, str(x), str(y))
        run("xdotool", "mouseup", "--window", self.window, str(button))
        pause(delay)

    @override
    def drag(
        self,
        x1: int,
        y1: int,
        x2: int,
        y2: int,
        button: int = 1,
        steps: int = 12,
        step_delay: Delay = Delay.EVENT,
    ) -> None:
        # Move in increments rather than one jump: widgets that track drags
        # per mouse-move (or per frame) never see an instantaneous warp, so a
        # single-step drag reads as a plain click.
        self.require_window()
        self.event("drag", x1=x1, y1=y1, x2=x2, y2=y2, button=button, steps=steps)
        run("xdotool", "mousemove", "--window", self.window, str(x1), str(y1))
        # Let the move land before the press. The editor traces the ground from
        # where it last saw the pointer, so a press that overtakes its own move
        # traces from the *previous* spot -- off the map, if that was a parked
        # screenshot -- and the brush refuses to paint.
        pause(Delay.CONTROL)
        run("xdotool", "mousedown", "--window", self.window, str(button))
        pause(step_delay)
        for i in range(1, steps + 1):
            xi = round(x1 + (x2 - x1) * i / steps)
            yi = round(y1 + (y2 - y1) * i / steps)
            run("xdotool", "mousemove", "--window", self.window, str(xi), str(yi))
            pause(step_delay)
        run("xdotool", "mouseup", "--window", self.window, str(button))
        pause(Delay.CONTROL)

    @override
    def set_clipboard(self, text: str) -> None:
        """Put text on the clipboard, so a copy assertion cannot pass on what a
        previous run left there."""
        self.event("set_clipboard", text=text)
        self.stop_clipboard_owner()
        env = {**os.environ, "SBC_E2E_CLIPBOARD": text}
        # X11 text ownership is live: destroying the Tk process immediately
        # after `clipboard_append` makes the selection disappear before the
        # engine's next key event can request it. Keep one tiny owner alive and
        # replace it on the next set; this works without xclip/xsel and makes
        # the paste path deterministic.
        self._clipboard_owner = subprocess.Popen(
            [
                sys.executable,
                "-c",
                "import os,tkinter;r=tkinter.Tk();r.withdraw();r.clipboard_clear();"
                "r.clipboard_append(os.environ['SBC_E2E_CLIPBOARD']);r.update();r.after(60000,r.destroy);"
                "r.mainloop()",
            ],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def stop_clipboard_owner(self) -> None:
        owner = getattr(self, "_clipboard_owner", None)
        if owner is None:
            return
        if owner.poll() is None:
            owner.terminate()
            try:
                owner.wait(timeout=Timeout.SHUTDOWN)
            except subprocess.TimeoutExpired:
                owner.kill()
                owner.wait(timeout=Timeout.SHUTDOWN)
        self._clipboard_owner = None

    @override
    def clipboard(self) -> str:
        """The X clipboard's text. No xclip/xsel here, so Tk reads it."""
        result = subprocess.run(
            [
                sys.executable,
                "-c",
                "import tkinter;r=tkinter.Tk();r.withdraw();print(r.clipboard_get(), end='')",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            return ""
        self.event("clipboard", length=len(result.stdout))
        return result.stdout

    def _root_point(self, x: int, y: int) -> tuple[int, int]:
        """Convert a window-local point for xdotool's root-window input."""
        self.require_window()
        geometry = window_geometry_values(self.window)
        return x + geometry.get("X", 0), y + geometry.get("Y", 0)
