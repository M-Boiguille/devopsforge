"""Helpers partagés des scripts DevOpsForge.

Ce module est interne (`_` préfixe) : il n'est pas destiné à être importé
en dehors du dossier `scripts/`. Il centralise les constantes et fonctions
utilisées par update_profile.py, apply_decay.py et select_due_notions.py.
"""

from __future__ import annotations

import math
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


def load_forgetting() -> tuple[float, float]:
    """Renvoie (rate, review_threshold) depuis config/forgetting.yaml."""
    data = load_yaml(FORGETTING_FILE) or {}
    decay = data.get("decay", {})
    rate = float(decay.get("rate", 0.30))
    threshold = float(decay.get("review_threshold", 0.80))
    return rate, threshold


def ebbinghaus_days(score: float, rate: float, threshold: float) -> int:
    """Nombre de jours avant que `score` retombe sous `threshold`.

    Dérivé de `score * exp(-rate * jours) = threshold`, donc
    `jours = ln(score / threshold) / rate`. Borné à [1, 30].
    """
    if score <= threshold:
        return 1
    days = math.log(score / threshold) / rate
    return int(max(1, min(30, round(days))))


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
