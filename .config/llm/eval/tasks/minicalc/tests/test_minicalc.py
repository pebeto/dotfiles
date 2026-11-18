import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
import pytest
from minicalc import EvalError, run


@pytest.mark.parametrize("src,expected", [
    ("1 + 2 * 3", 7), ("(1 + 2) * 3", 9), ("2 ^ 3 ^ 2", 512), ("-2 ^ 2", -4),
    ("7 / 2", 3.5), ("let x = 4; x * x", 16), ("if 2 > 1 then 10 else 20", 10),
    ("fn sq(n) = n * n; sq(5)", 25),
    ("fn fact(n) = if n <= 1 then 1 else n * fact(n - 1); fact(6)", 720),
])
def test_eval(src, expected):
    assert run(src) == expected


def test_lexical_scope():
    src = "let k = 10; fn addk(n) = n + k; fn f(k) = addk(1); f(100)"
    assert run(src) == 11


def test_division_by_zero():
    with pytest.raises(EvalError):
        run("1 / 0")
