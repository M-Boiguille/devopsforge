"""Met à jour le profil multidimensionnel à partir d'un rapport d'analyse.

Usage:
    python3 scripts/update_profile.py [--analysis exercises/NNN-notion/analysis.md]

Si `--analysis` n'est pas fourni, le rapport de l'exercice au numéro le plus élevé
de `exercises/` est utilisé.

Le rapport d'analyse est un fichier Markdown avec un front-matter YAML (voir
`specs/001-devopsforge-mvp/contracts/analysis-format.md`).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

import _common as c

WEIGHT_NEW = 0.7  # poids du score d'analyse dans la moyenne mobile


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--analysis",
        type=Path,
        default=None,
        help="Chemin du rapport d'analyse (défaut: le plus récent de exercises/).",
    )
    return parser.parse_args()


def read_front_matter(path: Path) -> dict:
    """Extrait le front-matter YAML d'un fichier Markdown."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        raise ValueError(f"Pas de front-matter YAML dans {path}")
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise ValueError(f"Front-matter YAML mal formé dans {path}")
    return yaml.safe_load(parts[1]) or {}


def find_latest_analysis() -> Path:
    exercises_dir = c.REPO_ROOT / "exercises"
    candidates = sorted(exercises_dir.glob("*/analysis.md"))
    if not candidates:
        raise FileNotFoundError("Aucun fichier exercises/*/analysis.md trouvé")
    return candidates[-1]


def update_profile(front_matter: dict, sr_config: dict) -> None:
    notions = front_matter.get("notions") or []
    analysis_date = front_matter.get("date") or c.today_iso()
    known = c.load_known_notions()
    newly_due: dict[str, dict] = {}

    for entry in notions:
        notion = entry.get("notion")
        scores = entry.get("scores") or {}
        if not notion:
            continue

        # Whitelist : la roadmap est la seule source d'identifiants de notions.
        # Le LLM peut en inventer : on les rejette avant toute écriture.
        if known and notion not in known:
            c.log_error(f"Notion hors roadmap (whitelist) ignorée: {notion}")
            continue

        path, _domain = c.find_notion_location(notion)
        if path is None:
            c.log_error(f"Notion inconnue ignorée: {notion}")
            continue

        data = c.load_yaml(path) or {}
        notion_data = (data.get("notions", {}) or {}).get(notion)
        if notion_data is None:
            c.log_error(f"Notion absente du profil, ignorée: {notion}")
            continue

        existing = notion_data.get("scores") or {}
        first_review = not notion_data.get("last_reviewed")
        updated_scores = {}
        for dim in c.DIMENSIONS:
            if dim in scores:
                new_val = c.clamp(float(scores[dim]))
                if first_review or dim not in existing:
                    updated_scores[dim] = new_val
                else:
                    updated_scores[dim] = c.clamp(WEIGHT_NEW * new_val + (1 - WEIGHT_NEW) * float(existing[dim]))
            elif dim in existing:
                updated_scores[dim] = c.clamp(float(existing[dim]))

        notion_data["scores"] = updated_scores
        notion_data["last_reviewed"] = analysis_date

        # Répétition espacée SM-2 : la qualité est déduite de la maîtrise réelle,
        # puis l'intervalle suit SM-2 (1, 6, puis × EF).
        previous_interval = int(notion_data.get("interval_days") or 0)
        streak = int(notion_data.get("streak") or 0)
        ease = float(notion_data.get("ease") or sr_config["ease_default"])
        quality = c.quality_from_scores(updated_scores, sr_config)
        interval, streak, ease = c.sm2_next_interval(
            quality, streak, ease, previous_interval, sr_config
        )
        notion_data["interval_days"] = int(interval)
        notion_data["streak"] = int(streak)
        notion_data["ease"] = round(float(ease), 4)

        from datetime import date as _date, timedelta

        due_date = (_date.fromisoformat(analysis_date) + timedelta(days=interval)).isoformat()
        notion_data["due_at"] = due_date

        threshold = float(sr_config["review_threshold"])
        weak_dims = [d for d in c.DIMENSIONS if updated_scores.get(d, 1.0) < threshold]
        if weak_dims:
            min_weak = min(updated_scores[d] for d in weak_dims)
            newly_due[notion] = {
                "notion": notion,
                "dimensions": weak_dims,
                "priority": c.priority_from_score(min_weak),
                "due_since": analysis_date,
            }

        c.save_yaml(path, data)
        print(f"[update] {notion} → q={quality} interval={interval}j due_at={due_date}")

    if newly_due:
        sync_dues(newly_due)


def sync_dues(newly_due: dict[str, dict]) -> None:
    """Met à jour dues.yaml : retire les notions revues, ajoute les fragiles."""
    dues_data = c.load_yaml(c.DUES_FILE) or {}
    existing = dues_data.get("dues") or []
    reviewed = set(newly_due.keys())
    kept = [d for d in existing if d.get("notion") not in reviewed]
    merged = kept + list(newly_due.values())
    merged.sort(key=lambda d: (c.PRIORITY_ORDER.get(d.get("priority", "low"), 2), d.get("due_since", "")))
    dues_data["dues"] = merged
    c.save_yaml(c.DUES_FILE, dues_data)


def main() -> int:
    args = parse_args()
    try:
        analysis_path = args.analysis or find_latest_analysis()
        front_matter = read_front_matter(analysis_path)
    except (FileNotFoundError, ValueError) as exc:
        c.log_error(str(exc))
        return 1

    sr_config = c.load_sr_config()
    update_profile(front_matter, sr_config)
    return 0


if __name__ == "__main__":
    sys.exit(main())
