import pathlib
import sys
from datetime import datetime

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
import pytest
from cronnext import next_run


@pytest.mark.parametrize("expr,after,expected", [
    ("*/15 * * * *", "2026-06-12T03:18:01", "2026-06-12T03:30:00"),
    ("0 9-17 * * 1-5", "2027-02-05T17:30:00", "2027-02-08T09:00:00"),
    ("30 2 1 * *", "2026-11-22T01:46:08", "2026-12-01T02:30:00"),
    ("0 12 * * 7", "2028-05-09T23:12:27", "2028-05-14T12:00:00"),
    ("0 0 * * *", "2026-01-01T00:00:00", "2026-01-02T00:00:00"),
])
def test_next_run(expr, after, expected):
    assert next_run(expr, datetime.fromisoformat(after)) == datetime.fromisoformat(expected)


@pytest.mark.parametrize("expr", ["* * * *", "60 * * * *", "* 24 * * *", "5-1 * * * *", "*/0 * * * *"])
def test_invalid(expr):
    with pytest.raises(ValueError):
        next_run(expr, datetime(2026, 1, 1))
