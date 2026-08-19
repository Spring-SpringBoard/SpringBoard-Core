import os
import subprocess
import sys
from collections.abc import Generator
from contextlib import contextmanager
from typing import override

from .state import RunState
from .timing import TEXT_INTERVAL_MS, Delay, Timeout, pause
from .utils.run_env import MODIFIER_NAMES, MODIFIERS
from .utils.x11 import window_geometry_values

KEYCODES = {
    "BackSpace": 8,
    "Backspace": 8,
    "Tab": 9,
    "Return": 13,
    "Escape": 27,
    "Space": 32,
    "Delete": 127,
    "Up": 273,
    "Down": 274,
    "Right": 275,
    "Left": 276,
    "Insert": 277,
    "Home": 278,
    "End": 279,
    "Page_Up": 280,
    "Page_Down": 281,
    "Control_L": 306,
    "Control_R": 305,
    "Shift_L": 304,
    "Shift_R": 303,
    "Alt_L": 308,
    "Alt_R": 307,
    "Super_L": 310,
    "Super_R": 309,
    "F1": 282,
    "F2": 283,
    "F3": 284,
    "F4": 285,
    "F5": 286,
    "F6": 287,
    "F7": 288,
    "F8": 289,
    "F9": 290,
    "F10": 291,
    "F11": 292,
    "F12": 293,
    "F13": 294,
    "F14": 295,
    "F15": 296,
}


class InputMixin(RunState):
    """Synthesised keyboard and mouse input, plus the X clipboard.

    Input is routed through the engine's debug emulation API. Coordinates stay
    in the same top-left, window-relative space used by the scenarios.
    """

    @override
    def focus(self) -> None:
        self.require_window()
        pause(Delay.INPUT)
        self.release_modifiers()
        self.event("focus", window=self.window)

    def release_modifiers(self) -> None:
        self.require_window()
        for modifier in MODIFIERS:
            self._input("key_release", keycode=self._keycode(modifier))
        pause(Delay.EVENT)

    def _input(self, kind: str, **data: object) -> None:
        self.control.call("runtime.emulate_input", kind=kind, **data)

    @staticmethod
    def _keycode(name: str) -> int:
        if name in KEYCODES:
            return KEYCODES[name]
        if len(name) == 1:
            return ord(name.lower())
        raise ValueError(f"no emulated keycode for {name!r}")

    def _key_down(self, name: str) -> None:
        self._input("key_press", keycode=self._keycode(name))

    def _key_up(self, name: str) -> None:
        self._input("key_release", keycode=self._keycode(name))

    @override
    def key(self, name: str, delay: Delay = Delay.INPUT) -> None:
        self.require_window()
        self.event("key", key=name)
        if "+" in name:
            parts = name.split("+")
            modifiers, base = parts[:-1], parts[-1]
            for modifier in modifiers:
                self._key_down(MODIFIER_NAMES.get(modifier, modifier))
            self._key_down(base)
            self._key_up(base)
            for modifier in reversed(modifiers):
                self._key_up(MODIFIER_NAMES.get(modifier, modifier))
        else:
            self._key_down(name)
            self._key_up(name)
        pause(delay)

    @contextmanager
    @override
    def modifier(self, name: str) -> Generator[None]:
        """Hold a modifier across pointer input."""
        self.event("modifier_down", modifier=name)
        normalized = MODIFIER_NAMES.get(name, name)
        self._key_down(normalized)
        try:
            yield
        finally:
            self._key_up(normalized)
            self.event("modifier_up", modifier=name)

    @override
    def key_chord(self, modifiers: tuple[str, ...], name: str, delay: Delay = Delay.INPUT) -> None:
        self.require_window()
        normalized = tuple(MODIFIER_NAMES.get(mod, mod) for mod in modifiers)
        chord = "+".join((*normalized, name))
        self.event("key_chord", chord=chord)
        for modifier in normalized:
            self._key_down(modifier)
        self._key_down(name)
        self._key_up(name)
        for modifier in reversed(normalized):
            self._key_up(modifier)
        pause(delay)

    @override
    def type_text(self, text: str, delay_ms: int = TEXT_INTERVAL_MS) -> None:
        self.require_window()
        # A focused text field (notably Chonsole after Return) has to exist
        # before its characters arrive. This is a next-frame barrier for the
        # preceding click/key, not a fixed text-entry delay.
        self.sync_input()
        self.event("type", text=text)
        self._input("text_input", text=text)
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
        self._input("mouse_move", x=x, y=y)
        self._input("mouse_press", button=button)
        self._input("mouse_release", button=button)
        self._emulated_pointer = (x, y)
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
        self._input("mouse_move", x=x, y=y)
        pause(Delay.CONTROL)
        self._input("mouse_press", button=button)
        pause(Delay.POLL)
        self._input("mouse_release", button=button)
        self._emulated_pointer = (x, y)
        pause(delay)

    @override
    def move(self, x: int, y: int, delay: Delay = Delay.INPUT) -> None:
        self.require_window()
        self.event("move", x=x, y=y)
        self._input("mouse_move", x=x, y=y)
        self._emulated_pointer = (x, y)
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
        pointer = getattr(self, "_emulated_pointer", None)
        if pointer is None:
            geometry = window_geometry_values(self.window)
            pointer = (geometry["WIDTH"] // 2, geometry["HEIGHT"] // 2)
        x, y = pointer
        for _ in range(steps):
            x += round(dx / steps)
            y += round(dy / steps)
            self._input("mouse_move", x=x, y=y)
            self._emulated_pointer = (x, y)
            pause(delay)

    @override
    def wheel(self, x: int, y: int, clicks: int = 1, up: bool = True, delay: Delay = Delay.FRAME) -> None:
        """Scroll the wheel over a point for a UI interaction under test.

        Domain scenarios frame the map through ``control.camera.zoom``; this
        remains for genuine wheel contracts such as Chonsole suggestion scroll.
        """
        self.require_window()
        self.event("wheel", x=x, y=y, clicks=clicks, up=up)
        self._input("mouse_move", x=x, y=y)
        self._input("mouse_wheel", delta=clicks if up else -clicks)
        self._emulated_pointer = (x, y)
        pause(delay)

    @override
    def wheel_root(self, x: int, y: int, clicks: int = 1, up: bool = True, delay: Delay = Delay.FRAME) -> None:
        """Scroll with the real pointer so held modifiers apply."""
        self.event("wheel_root", x=x, y=y, clicks=clicks, up=up)
        self._input("mouse_move", x=x, y=y)
        self._input("mouse_wheel", delta=clicks if up else -clicks)
        self._emulated_pointer = (x, y)
        pause(delay)

    @override
    def click_root(self, x: int, y: int, button: int = 1, delay: Delay = Delay.INPUT) -> None:
        self.event("click_root", x=x, y=y, button=button)
        self._input("mouse_move", x=x, y=y)
        self._input("mouse_press", button=button)
        self._input("mouse_release", button=button)
        self._emulated_pointer = (x, y)
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
        self._input("mouse_move", x=x1, y=y1)
        pause(Delay.CONTROL)
        self._input("mouse_press", button=button)
        pause(step_delay)
        for i in range(1, steps + 1):
            xi = round(x1 + (x2 - x1) * i / steps)
            yi = round(y1 + (y2 - y1) * i / steps)
            self._input("mouse_move", x=xi, y=yi)
            pause(step_delay)
        self._input("mouse_release", button=button)
        self._emulated_pointer = (x2, y2)
        pause(Delay.CONTROL)

    @override
    def press(self, x: int, y: int, button: int = 1, delay: Delay = Delay.CONTROL) -> None:
        """Hold the button down. Pair with `move` + `release` when the scenario
        has to capture something that only exists *during* the drag, like the
        selection rectangle."""
        self.require_window()
        self.event("press", x=x, y=y, button=button)
        self._input("mouse_move", x=x, y=y)
        pause(Delay.CONTROL)
        self._input("mouse_press", button=button)
        self._emulated_pointer = (x, y)
        pause(delay)

    @override
    def release(self, x: int, y: int, button: int = 1, delay: Delay = Delay.FRAME) -> None:
        self.require_window()
        self.event("release", x=x, y=y, button=button)
        self._input("mouse_move", x=x, y=y)
        self._input("mouse_release", button=button)
        self._emulated_pointer = (x, y)
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
        self._input("mouse_move", x=x1, y=y1)
        # Let the move land before the press. The editor traces the ground from
        # where it last saw the pointer, so a press that overtakes its own move
        # traces from the *previous* spot -- off the map, if that was a parked
        # screenshot -- and the brush refuses to paint.
        pause(Delay.CONTROL)
        self._input("mouse_press", button=button)
        pause(step_delay)
        for i in range(1, steps + 1):
            xi = round(x1 + (x2 - x1) * i / steps)
            yi = round(y1 + (y2 - y1) * i / steps)
            self._input("mouse_move", x=xi, y=yi)
            pause(step_delay)
        self._input("mouse_release", button=button)
        self._emulated_pointer = (x2, y2)
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
        # Give Tk time to claim the selection.
        pause(Delay.CONTROL)

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
