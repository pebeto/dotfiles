from .parser import Parser


class EvalError(Exception):
    pass


class Env:
    def __init__(self, parent=None):
        self.vars: dict = {}
        self.parent = parent

    def get(self, name):
        env = self
        while env is not None:
            if name in env.vars:
                return env.vars[name]
            env = env.parent
        raise EvalError(f"undefined: {name}")


class Function:
    def __init__(self, params, body, env):
        self.params, self.body, self.env = params, body, env


def evaluate(node, env: Env):
    tag = node[0]
    if tag == "num":
        return node[1]
    if tag == "var":
        value = env.get(node[1])
        if isinstance(value, Function):
            raise EvalError(f"{node[1]} is a function")
        return value
    if tag == "neg":
        return -evaluate(node[1], env)
    if tag == "bin":
        op, a, b = node[1], evaluate(node[2], env), evaluate(node[3], env)
        if op == "+": return a + b
        if op == "-": return a - b
        if op == "*": return a * b
        if op == "/":
            if b == 0:
                raise EvalError("division by zero")
            return a // b
        if op == "^": return a ** b
        return int({"==": a == b, "!=": a != b, "<": a < b, ">": a > b, "<=": a <= b, ">=": a >= b}[op])
    if tag == "if":
        return evaluate(node[2], env) if evaluate(node[1], env) else evaluate(node[3], env)
    if tag == "call":
        fn = env.get(node[1])
        if not isinstance(fn, Function):
            raise EvalError(f"{node[1]} is not a function")
        if len(node[2]) != len(fn.params):
            raise EvalError(f"{node[1]} expects {len(fn.params)} arguments")
        local = Env(env)
        for p, arg in zip(fn.params, node[2]):
            local.vars[p] = evaluate(arg, env)
        return evaluate(fn.body, local)
    if tag == "let":
        env.vars[node[1]] = evaluate(node[2], env)
        return env.vars[node[1]]
    if tag == "fn":
        env.vars[node[1]] = Function(node[2], node[3], env)
        return None
    raise EvalError(f"bad node {tag}")


def run(src: str, env: Env | None = None):
    """Run a program; returns the value of the last statement."""
    env = env or Env()
    result = None
    for stmt in Parser(src).program():
        result = evaluate(stmt, env)
    return result
