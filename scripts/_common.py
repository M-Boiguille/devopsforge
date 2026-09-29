"""Helpers partagés des scripts DevOpsForge.

Ce module est interne (`_` préfixe) : il n'est pas destiné à être importé
en dehors du dossier `scripts/`. Il centralise les constantes et fonctions
utilisées par update_profile.py et select_due_notions.py.
"""

from __future__ import annotations

import os
import sys
from datetime import date, datetime
from pathlib import Path

import yaml

DIMENSIONS: tuple[str, ...] = (
    "connaissance",
    "implementation",
    "debug",
    "explication",
    "design",
    "securite",
    "performance",
)

PRIORITY_ORDER: dict[str, int] = {"high": 0, "medium": 1, "low": 2}

REPO_ROOT: Path = Path(__file__).resolve().parent.parent
# Le profil de maîtrise (profile/, dues.yaml, errors.log) vit dans le repo privé
# `devopsforge-profile`. Les workflows publics clonent ce repo et passent son chemin
# via la variable d'environnement PROFILE_REPO_PATH. En local, défaut = REPO_ROOT.
PROFILE_REPO_PATH: Path = (
    Path(os.environ["PROFILE_REPO_PATH"]) if os.environ.get("PROFILE_REPO_PATH") else REPO_ROOT
)

PROFILE_DIR: Path = PROFILE_REPO_PATH / "profile"
CONFIG_DIR: Path = REPO_ROOT / "config"
DUES_FILE: Path = PROFILE_REPO_PATH / "dues.yaml"
ERRORS_LOG: Path = PROFILE_REPO_PATH / "errors.log"
ROADMAP_FILE: Path = PROFILE_REPO_PATH / "roadmap.yaml"
FORGETTING_FILE: Path = CONFIG_DIR / "forgetting.yaml"
THRESHOLDS_FILE: Path = CONFIG_DIR / "thresholds.yaml"


def clamp(value: float) -> float:
    """Borne une valeur dans l'intervalle [0.0, 1.0] et arrondit à 4 décimales."""
    return round(max(0.0, min(1.0, float(value))), 4)


def load_yaml(path: Path):
    """Charge un fichier YAML, renvoie un conteneur vide en cas d'absence."""
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def save_yaml(path: Path, data) -> None:
    """Écrit un conteneur en YAML lisible et trié dans l'ordre d'insertion."""
    with path.open("w", encoding="utf-8") as fh:
        yaml.safe_dump(data, fh, sort_keys=False, allow_unicode=True, default_flow_style=False)


def log_error(message: str) -> None:
    """Ajoute une ligne horodatée à errors.log."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with ERRORS_LOG.open("a", encoding="utf-8") as fh:
        fh.write(f"{timestamp} | ERROR | {message}\n")
    print(f"[error] {message}", file=sys.stderr)


def today_iso() -> str:
    return date.today().isoformat()


SR_DEFAULTS: dict = {
    "min_score_per_dimension": 0.85,
    "min_dimensions_required": 4,
    "review_threshold": 0.80,
    "ease_default": 2.5,
    "ease_min": 1.3,
    "first_intervals": [1, 6],
    "max_interval_days": 180,
}


def load_sr_config() -> dict:
    """Charge la config de répétition espacée (SM-2), avec valeurs par défaut."""
    data = load_yaml(FORGETTING_FILE) or {}
    config = dict(SR_DEFAULTS)
    config.update(data.get("spaced_repetition") or {})
    return config


def quality_from_scores(scores: dict, config: dict) -> int:
    """Qualité de récupération SM-2 (0..5) déduite de la maîtrise multidimensionnelle.

    Une notion est « maîtrisée » lorsqu'au moins `min_dimensions_required`
    dimensions atteignent `min_score_per_dimension`. La qualité combine ce
    nombre et la moyenne des 7 dimensions.
    """
    min_score = float(config["min_score_per_dimension"])
    min_dims = int(config["min_dimensions_required"])
    values = [float(scores.get(dim, 0.0)) for dim in DIMENSIONS]
    mastered = sum(1 for value in values if value >= min_score)
    average = sum(values) / len(values)
    if mastered >= min_dims and average >= 0.90:
        return 5
    if mastered >= min_dims and average >= 0.85:
        return 4
    if mastered >= 3 and average >= 0.75:
        return 3
    if average >= 0.60:
        return 2
    if average >= 0.40:
        return 1
    return 0


def sm2_next_interval(
    quality: int, streak: int, ease: float, previous_interval: int, config: dict
) -> tuple[int, int, float]:
    """SM-2 : renvoie (interval_days, nouveau_streak, nouvel_ease).

    Échec (quality < 3) → intervalle 1 jour, streak remis à 0.
    Sinon : 1er succès = first_intervals[0], 2e = first_intervals[1],
    ensuite intervalle précédent × ease (facteur de facilité).
    """
    first = list(config["first_intervals"])
    ease = max(float(config["ease_min"]), float(ease))
    if quality < 3:
        return 1, 0, ease
    streak += 1
    if streak == 1:
        interval = int(first[0])
    elif streak == 2:
        interval = int(first[1])
    else:
        base = int(previous_interval) if previous_interval > 0 else int(first[-1])
        interval = round(base * ease)
    interval = max(1, min(int(config["max_interval_days"]), interval))
    ease = ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    ease = max(float(config["ease_min"]), ease)
    return interval, streak, ease


def load_known_notions() -> set[str]:
    """Identifiants de notions déclarés dans roadmap.yaml (repo privé).

    Ensemble vide si la roadmap est absente (le filtrage est alors désactivé).
    """
    data = load_yaml(ROADMAP_FILE) or {}
    known: set[str] = set()
    for domain in data.get("domains", []) or []:
        for notion in domain.get("notions", []) or []:
            notion_id = notion.get("id")
            if notion_id:
                known.add(notion_id)
    return known


def find_notion_location(notion: str) -> tuple[Path, str] | tuple[None, None]:
    """Localise le fichier profile/<domaine>.yaml contenant une notion."""
    for path in sorted(PROFILE_DIR.glob("*.yaml")):
        data = load_yaml(path) or {}
        notions = data.get("notions", {}) or {}
        if notion in notions:
            return path, data.get("domain", path.stem)
    return None, None


def priority_from_score(score: float, demote_threshold: float = 0.5) -> str:
    """Déduit la priorité d'un score faible."""
    if score < demote_threshold:
        return "high"
    if score < 0.65:
        return "medium"
    return "low"
