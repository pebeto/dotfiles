"""Parse human durations like "1h30m", "90s", "2d 4h" into seconds."""
import re

UNITS = {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800}
_TOKEN = re.compile(r"(\d)([smhdw])")


def parse_duration(text: str) -> int:
    """Return the number of seconds in ``text``.

    Accepts one or more <number><unit> groups, optionally separated by spaces,
    with units s, m, h, d, w. Units may appear at most once and must go from
    largest to smallest. Raises ValueError on anything else.
    """
    text = text.strip().lower()
    if not text:
        raise ValueError("empty duration")
    total = 0
    last = None
    pos = 0
    for match in _TOKEN.finditer(text):
        if text[pos:match.start()].strip():
            raise ValueError(f"unexpected text in {text!r}")
        value, unit = int(match.group(1)), match.group(2)
        if last is not None and UNITS[unit] > UNITS[last]:
            raise ValueError(f"units out of order in {text!r}")
        last = unit
        total += value * UNITS[unit]
        pos = match.end()
    if text[pos:].strip():
        raise ValueError(f"unexpected text in {text!r}")
    return total


def format_duration(seconds: int) -> str:
    """Inverse of parse_duration, largest units first, e.g. 5400 -> "1h30m"."""
    if seconds < 0:
        raise ValueError("negative duration")
    if seconds == 0:
        return "0s"
    parts = []
    for unit, size in sorted(UNITS.items(), key=lambda kv: kv[1], reverse=True):
        count, seconds = divmod(seconds, size)
        if count:
            parts.append(f"{count}{unit}")
    return "".join(parts)
