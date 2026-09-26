"""Sélectionne les N notions dues les plus prioritaires.

Usage:
    python3 scripts/select_due_notions.py [--limit N] [--json]

Tri par priorité (high > medium > low) puis par ancienneté (due_since croissant).
Sortie par défaut en YAML sur stdout, utilisable par generate-exercise.yml.
"""

from __future__ import annotations

import argparse
import json
import sys

import yaml

import _common as c


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=None, help="Nombre maximal de notions (défaut: toutes).")
    parser.add_argument("--json", action="store_true", help="Sortie JSON au lieu de YAML.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    dues_data = c.load_yaml(c.DUES_FILE) or {}
    dues = dues_data.get("dues") or []

    ordered = sorted(
        dues,
        key=lambda d: (c.PRIORITY_ORDER.get(d.get("priority", "low"), 2), d.get("due_since", "")),
    )

    if args.limit is not None:
        ordered = ordered[: args.limit]

    if args.json:
        print(json.dumps(ordered, ensure_ascii=False, indent=2))
    else:
        yaml.safe_dump(ordered, sys.stdout, sort_keys=False, allow_unicode=True, default_flow_style=False)

    return 0


if __name__ == "__main__":
    sys.exit(main())
