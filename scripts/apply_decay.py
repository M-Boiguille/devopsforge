"""Applique la décroissance d'Ebbinghaus aux scores du profil.

NICE-TO-HAVE DIFFÉRÉ — non câblé à aucun workflow au MVP. Utilisable en local :

    python3 scripts/apply_decay.py

Formule: score_actuel = score_initial * exp(-rate * jours_ecoules)
Les notions dont un score passe sous review_threshold sont marquées « dues ».
"""

from __future__ import annotations

import math
import sys
from datetime import date

import _common as c


def apply_decay_to_notion(notion_data: dict, rate: float, threshold: float, today: date) -> bool:
    """Décroît les scores d'une notion. Renvoie True si elle devient due."""
    last_reviewed = notion_data.get("last_reviewed")
    if not last_reviewed:
        return False

    try:
        reviewed = date.fromisoformat(str(last_reviewed))
    except ValueError:
        c.log_error(f"last_reviewed invalide ignoré: {last_reviewed}")
        return False

    days_elapsed = (today - reviewed).days
    if days_elapsed <= 0:
        return False

    scores = notion_data.get("scores") or {}
    factor = math.exp(-rate * days_elapsed)
    for dim in c.DIMENSIONS:
        if dim in scores:
            scores[dim] = c.clamp(float(scores[dim]) * factor)

    notion_data["scores"] = scores
    weak_dims = [d for d in c.DIMENSIONS if scores.get(d, 1.0) < threshold]
    return bool(weak_dims)


def main() -> int:
    rate, threshold = c.load_forgetting()
    today = date.today()
    newly_due: dict[str, dict] = {}

    for path in sorted(c.PROFILE_DIR.glob("*.yaml")):
        data = c.load_yaml(path) or {}
        notions = data.get("notions", {}) or {}
        changed = False
        for name, notion_data in notions.items():
            if apply_decay_to_notion(notion_data, rate, threshold, today):
                scores = notion_data.get("scores") or {}
                weak_dims = [d for d in c.DIMENSIONS if scores.get(d, 1.0) < threshold]
                min_weak = min(scores[d] for d in weak_dims)
                newly_due[name] = {
                    "notion": name,
                    "dimensions": weak_dims,
                    "priority": c.priority_from_score(min_weak),
                    "due_since": today.isoformat(),
                }
                print(f"[decay] {name} passe sous seuil → due")
                changed = True
        if changed:
            c.save_yaml(path, data)

    if newly_due:
        merge_dues(newly_due)

    print(f"[decay] terminé — {len(newly_due)} notion(s) marquée(s) due")
    return 0


def merge_dues(newly_due: dict[str, dict]) -> None:
    """Ajoute les notions dues sans dupliquer, triées par priorité + ancienneté."""
    dues_data = c.load_yaml(c.DUES_FILE) or {}
    existing = dues_data.get("dues") or []
    by_notion = {d.get("notion"): d for d in existing}
    for name, entry in newly_due.items():
        by_notion[name] = entry
    merged = sorted(
        by_notion.values(),
        key=lambda d: (c.PRIORITY_ORDER.get(d.get("priority", "low"), 2), d.get("due_since", "")),
    )
    dues_data["dues"] = merged
    c.save_yaml(c.DUES_FILE, dues_data)


if __name__ == "__main__":
    sys.exit(main())
