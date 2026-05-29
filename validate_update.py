#!/usr/bin/env python3
"""Validate update.json against update.schema.json."""

import json
import sys
from pathlib import Path

try:
    from jsonschema import validate, ValidationError, FormatChecker
except ImportError:
    sys.exit("jsonschema is not installed. Run: pip install jsonschema")

REPO_ROOT = Path(__file__).resolve().parent
SCHEMA_PATH = REPO_ROOT / "update.schema.json"
DATA_PATH = REPO_ROOT / "update.json"


def main() -> int:
    schema = json.loads(SCHEMA_PATH.read_text())
    data = json.loads(DATA_PATH.read_text())

    try:
        validate(instance=data, schema=schema, format_checker=FormatChecker())
    except ValidationError as exc:
        print(f"VALIDATION FAILED: {exc.message}")
        return 1

    print("update.json is valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
