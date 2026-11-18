import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
import pytest
from durations import parse_duration, format_duration


@pytest.mark.parametrize("text,expected", [
    ("90s", 90), ("1h30m", 5400), ("2d 4h", 187200), ("1w", 604800),
    ("12h", 43200), ("100s", 100), ("1d 2h 3m 4s", 93784), (" 45m ", 2700),
])
def test_parse(text, expected):
    assert parse_duration(text) == expected


@pytest.mark.parametrize("text", ["", "abc", "10", "5x", "1m1h", "1h 2h", "1h-30m", "h"])
def test_parse_rejects(text):
    with pytest.raises(ValueError):
        parse_duration(text)


@pytest.mark.parametrize("seconds", [0, 59, 61, 3600, 93784, 604800 + 3601, 10**7])
def test_roundtrip(seconds):
    assert parse_duration(format_duration(seconds)) == seconds
