import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "src"))
from appcfg import deep_merge, load_config
from appcfg.defaults import DEFAULTS


def test_defaults_only():
    cfg = load_config(environ={})
    assert cfg["server"]["port"] == 8080
    assert cfg["logging"]["handlers"] == ["console"]


def test_file_override(tmp_path):
    p = tmp_path / "c.json"
    p.write_text(json.dumps({"server": {"port": 9000, "tls": {"enabled": True}}, "logging": {"handlers": ["file"]}}))
    cfg = load_config(str(p), environ={})
    assert cfg["server"] == {"host": "127.0.0.1", "port": 9000, "tls": {"enabled": True, "cert": None}}
    assert cfg["logging"]["handlers"] == ["file"]


def test_defaults_not_mutated(tmp_path):
    p = tmp_path / "c.json"
    p.write_text(json.dumps({"server": {"port": 1}, "features": {"beta": True}}))
    load_config(str(p), environ={"APP_LOGGING__LEVEL": "debug"})
    assert DEFAULTS["server"]["port"] == 8080
    assert DEFAULTS["features"] == {}
    assert DEFAULTS["logging"]["level"] == "info"
    assert load_config(environ={})["server"]["port"] == 8080


def test_env_double_underscore_nesting():
    cfg = load_config(environ={"APP_SERVER__TLS__ENABLED": "true", "APP_SERVER__PORT": "7000", "HOME": "/x"})
    assert cfg["server"]["tls"]["enabled"] is True
    assert cfg["server"]["port"] == 7000


def test_env_keys_with_single_underscore():
    cfg = load_config(environ={"APP_FEATURES__DARK_MODE": "1"})
    assert cfg["features"] == {"dark_mode": 1}


def test_none_removes_key():
    assert deep_merge({"a": 1, "b": {"c": 2}}, {"b": None}) == {"a": 1}


def test_merge_does_not_mutate_inputs():
    base = {"a": {"b": [1]}}
    override = {"a": {"c": 2}}
    merged = deep_merge(base, override)
    merged["a"]["b"].append(99)
    assert base == {"a": {"b": [1]}}
    assert override == {"a": {"c": 2}}
