# Implementation Plan: DevOpsForge MVP

**Branch**: `001-devopsforge-mvp` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-devopsforge-mvp/spec.md`

## Summary

Construire le squelette fonctionnel de DevOpsForge : un cycle d'apprentissage adaptatif de bout en bout sur une
seule notion. Trois workflows GitHub Actions (génération, analyse, mise à jour) + trois scripts Python
(update_profile, apply_decay, select_due_notions) + un profil YAML multidimensionnel avec spaced repetition
(courbe d'Ebbinghaus).

## Technical Context

**Language/Version**: Python 3.11+

**Primary Dependencies**: `pyyaml`, `requests`, `python-dateutil` (uniquement)

**Storage**: YAML (aucune base de données)

**Testing**: Exécution locale des scripts sur des fixtures + validation `pyyaml` + `shellcheck`/`flake8` côté CI

**Target Platform**: GitHub Actions (Ubuntu runners), VPS OCI pour OpenClaw (différé)

**Project Type**: Repo de données + scripts CLI + workflows CI (pas de service web)

**Performance Goals**: Scripts exécutés en < 1s sur un profil de quelques dizaines de notions

**Constraints**: Aucun secret dans le repo ; scores clampés `[0,1]` ; idempotence des workflows

**Scale/Scope**: 2 notions au MVP (Linux), extensible à ~7 domaines

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] I. MVP-first : 2 notions max, une seule boucle de bout en bout.
- [x] II. YAML versionné, pas de SQLite.
- [x] III. GitHub Actions déterministes comme orchestrateur.
- [x] IV. Zéro donnée sensible dans le repo (tokens en secrets GitHub).
- [x] V. Séparation des rôles respectée (évaluation LLM dans l'Action au MVP, OpenClaw différé).
- [x] VI. Conventions `snake_case` / `kebab-case` / `YYYY-MM-DD` / conventional commits.

## Project Structure

### Documentation (this feature)

```text
specs/001-devopsforge-mvp/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── analysis-format.md
└── tasks.md
```

### Source Code (repository root)

```text
profile/
├── linux.yaml          # 2 notions actives
├── docker.yaml         # placeholder
├── kubernetes.yaml     # placeholder
├── terraform.yaml      # placeholder
├── python.yaml         # placeholder
├── git.yaml            # placeholder
└── transversal.yaml    # placeholder
dues.yaml
errors.log
exercises/.gitkeep
journal.md
config/
├── agent.yaml
├── thresholds.yaml
├── grading_weights.yaml
└── forgetting.yaml
scripts/
├── update_profile.py
├── apply_decay.py
└── select_due_notions.py
.github/
├── workflows/
│   ├── generate-exercise.yml
│   ├── analyze-session.yml
│   └── update-profile.yml
└── prompts/
    ├── generate-exercise.md
    └── evaluate-submission.md
AGENTS.md
README.md
```

**Structure Decision**: Single-project layout, racine du repo = données + scripts + CI. Les artefacts SpecKit
restent dans `specs/`.

## Complexity Tracking

> Aucune violation à justifier.
