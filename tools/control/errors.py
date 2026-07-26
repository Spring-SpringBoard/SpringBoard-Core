"""What a refused call raises. Shared by the transport and the handles."""

UNKNOWN_NAME_CODE = -32001
INVALID_PARAMS_CODE = -32602


class ControlError(RuntimeError):
    """The editor refused a call."""

    def __init__(self, code: int, message: str) -> None:
        super().__init__(message)
        self.code = code


class UnknownNameError(ControlError):
    """An editor, field, command or option that does not exist.

    Raised where the name is looked up, not where it is used, so a script that
    declares its handles at the top fails before it touches any state.
    """
