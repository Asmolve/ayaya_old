from pathlib import Path
from typing import Any

import yaml


def load_manifest(path: str) -> dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as file:
        loaded = yaml.safe_load(file)
    if not isinstance(loaded, dict):
        raise ValueError("module.yml must contain a mapping")
    return loaded
