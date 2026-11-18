"""Pratt parser producing tuples: ("num", v), ("var", n), ("bin", op, a, b), ("neg", a),
("call", name, args), ("if", c, a, b), ("let", n, e), ("fn", name, params, body)."""
from .lexer import tokenize

BINARY = {"==": 10, "!=": 10, "<": 10, ">": 10, "<=": 10, ">=": 10,
          "+": 20, "-": 20, "*": 30, "/": 30, "^": 40}
RIGHT_ASSOC: set[str] = set()
UNARY_MINUS = 50


class Parser:
    def __init__(self, src: str):
        self.toks = tokenize(src)
        self.i = 0

    def peek(self):
        return self.toks[self.i]

    def take(self, kind=None, value=None):
        tok = self.toks[self.i]
        if (kind and tok[0] != kind) or (value and tok[1] != value):
            raise SyntaxError(f"expected {value or kind}, got {tok[1] or tok[0]!r}")
        self.i += 1
        return tok

    def program(self):
        stmts = [self.statement()]
        while self.peek() == ("op", ";"):
            self.take()
            if self.peek()[0] == "eof":
                break
            stmts.append(self.statement())
        self.take("eof")
        return stmts

    def statement(self):
        if self.peek() == ("kw", "let"):
            self.take()
            name = self.take("name")[1]
            self.take("op", "=")
            return ("let", name, self.expr(0))
        if self.peek() == ("kw", "fn"):
            self.take()
            name = self.take("name")[1]
            self.take("op", "(")
            params = []
            if self.peek() != ("op", ")"):
                params.append(self.take("name")[1])
                while self.peek() == ("op", ","):
                    self.take()
                    params.append(self.take("name")[1])
            self.take("op", ")")
            self.take("op", "=")
            return ("fn", name, params, self.expr(0))
        return self.expr(0)

    def expr(self, min_bp):
        left = self.prefix()
        while True:
            kind, op = self.peek()
            if kind != "op" or op not in BINARY or BINARY[op] < min_bp + (0 if op in RIGHT_ASSOC else 1):
                break
            self.take()
            right = self.expr(BINARY[op])
            left = ("bin", op, left, right)
        return left

    def prefix(self):
        kind, val = self.take()
        if kind == "num":
            return ("num", float(val) if "." in val else int(val))
        if kind == "op" and val == "-":
            return ("neg", self.expr(UNARY_MINUS))
        if kind == "op" and val == "(":
            e = self.expr(0)
            self.take("op", ")")
            return e
        if kind == "kw" and val == "if":
            c = self.expr(0)
            self.take("kw", "then")
            a = self.expr(0)
            self.take("kw", "else")
            return ("if", c, a, self.expr(0))
        if kind == "name":
            if self.peek() == ("op", "("):
                self.take()
                args = []
                if self.peek() != ("op", ")"):
                    args.append(self.expr(0))
                    while self.peek() == ("op", ","):
                        self.take()
                        args.append(self.expr(0))
                self.take("op", ")")
                return ("call", val, args)
            return ("var", val)
        raise SyntaxError(f"unexpected {val or kind!r}")
