import re

TOKEN = re.compile(r"\s*(?:(\d+\.\d*|\d+)|([A-Za-z_]\w*)|(==|!=|<=|>=|[-+*/^(),=<>;]))")
KEYWORDS = {"let", "fn", "if", "then", "else"}


def tokenize(src: str) -> list[tuple[str, str]]:
    pos, out = 0, []
    src = src.rstrip()
    while pos < len(src):
        m = TOKEN.match(src, pos)
        if not m:
            raise SyntaxError(f"bad character at {pos}: {src[pos]!r}")
        num, name, op = m.groups()
        if num is not None:
            out.append(("num", num))
        elif name is not None:
            out.append(("kw" if name in KEYWORDS else "name", name))
        else:
            out.append(("op", op))
        pos = m.end()
    out.append(("eof", ""))
    return out
