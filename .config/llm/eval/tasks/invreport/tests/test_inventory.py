import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
import pytest
from inventory import main

CSV = str(ROOT / "stock.csv")


def run(capsys, *args):
    code = main(["report", CSV, *args])
    return code, capsys.readouterr().out


def test_text_default(capsys):
    code, out = run(capsys)
    assert code == 0
    assert out.splitlines()[0] == "Total value: 113.20"
    assert "Low stock: A-101, B-201, C-300" in out


def test_json_format(capsys):
    code, out = run(capsys, "--format", "json")
    assert code == 0
    data = json.loads(out)
    assert data["total_value"] == 113.2
    assert data["low_stock"] == ["A-101", "B-201", "C-300"]
    assert data["categories"]["stationery"] == {"items": 2, "units": 44, "value": 53.2}
    assert list(data["categories"]) == sorted(data["categories"])


def test_json_values_rounded(capsys):
    code, out = run(capsys, "--format", "json")
    data = json.loads(out)
    for cat in data["categories"].values():
        assert cat["value"] == round(cat["value"], 2)


def test_category_filter(capsys):
    code, out = run(capsys, "--category", "hardware", "--format", "json")
    data = json.loads(out)
    assert list(data["categories"]) == ["hardware"]
    assert data["total_value"] == 60.0
    assert data["low_stock"] == ["A-101"]


def test_unknown_category_exits_nonzero(capsys):
    code = main(["report", CSV, "--category", "food"])
    err = capsys.readouterr().err
    assert code == 2
    assert "unknown category: food" in err


def test_bad_format_rejected():
    with pytest.raises(SystemExit):
        main(["report", CSV, "--format", "xml"])
