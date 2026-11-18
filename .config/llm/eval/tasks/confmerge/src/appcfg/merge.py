def deep_merge(base: dict, override: dict) -> dict:
    """Return base updated with override, recursing into nested dicts.

    Lists in override replace lists in base. A value of None in override
    removes the key.
    """
    result = base
    for key, value in override.items():
        if value is None:
            result.pop(key, None)
        elif isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result
