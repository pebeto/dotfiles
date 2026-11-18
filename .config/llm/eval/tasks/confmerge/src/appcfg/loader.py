import json
import os

from .defaults import DEFAULTS
from .merge import deep_merge

ENV_PREFIX = "APP_"


def _env_overrides(environ) -> dict:
    """APP_SERVER__PORT=9000 -> {"server": {"port": 9000}}. Values are JSON when they parse."""
    out: dict = {}
    for name, raw in environ.items():
        if not name.startswith(ENV_PREFIX):
            continue
        path = name[len(ENV_PREFIX):].lower().split("_")
        try:
            value = json.loads(raw)
        except json.JSONDecodeError:
            value = raw
        node = out
        for part in path[:-1]:
            node = node.setdefault(part, {})
        node[path[-1]] = value
    return out


def load_config(path: str | None = None, environ=None) -> dict:
    environ = os.environ if environ is None else environ
    cfg = DEFAULTS
    if path:
        with open(path) as fh:
            cfg = deep_merge(cfg, json.load(fh))
    return deep_merge(cfg, _env_overrides(environ))
