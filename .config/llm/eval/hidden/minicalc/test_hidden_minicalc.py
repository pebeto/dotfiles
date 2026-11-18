import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
import pytest
from minicalc import EvalError, run


@pytest.mark.parametrize("src,expected", [
    ("2 ^ -1", 0.5), ("-2 ^ -2", -0.25), ("2 * -3", -6), ("-2 ^ 2 * 3", -12),
    ("2 ^ 2 ^ 3", 256), ("(2 ^ 3) ^ 2", 64), ("6 / 4", 1.5), ("10 - 2 - 3", 5),
    ("100 / 10 / 5", 2), ("-(2 + 3) * 2", -10), ("--3", 3), ("3 - -2 ^ 2", 7),
    ("fn fib(n) = if n < 2 then n else fib(n - 1) + fib(n - 2); fib(15)", 610),
    ("let a = 2; fn p(b) = a ^ b; fn q(a) = p(3); q(5)", 8),
])
def test_hidden(src, expected):
    assert run(src) == pytest.approx(expected)


def test_no_dynamic_scope_leak():
    with pytest.raises(EvalError):
        run("fn f(x) = g(); fn g() = x; f(1)")


def test_right_assoc_float():
    assert run("2 ^ 0.5 ^ 2") == pytest.approx(2 ** 0.25)


def test_zero_division_float():
    with pytest.raises(EvalError):
        run("1 / (2 - 2.0)")
