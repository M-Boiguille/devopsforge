# AGENTS.md — DevOpsForge

Conventions pour tout agent travaillant sur ce dépôt.

## Ce qu'est DevOpsForge

Système d'apprentissage adaptatif DevOps (Linux → Docker → K8s → Terraform → Observabilité → DevSecOps).
Le MVP couvre UNE seule boucle de bout en bout sur le domaine Linux (2 notions).

## Règles non négociables (constitution)

- Données en YAML versionné, jamais en base (pas de SQLite).
- Aucun secret ni donnée sensible dans le repo. Tokens uniquement dans les secrets GitHub Actions.
- GitHub Actions = orchestrateur déterministe. Les scripts Python mutent le profil de façon traçable.
- MVP-first : ne pas anticiper. 2 notions max au MVP.
- Scores bornés `[0.0, 1.0]`, clampés à l'écriture.

## Conventions de nommage

- Python : `snake_case` (`update_profile.py`, `apply_decay.py`)
- Workflows : `kebab-case` (`generate-exercise.yml`)
- Sessions : `YYYY-MM-DD-<type>.md` (exercise, submission, analysis)
- Notions : `snake_case` (`bash_scripting`, `file_parsing`)
- Commits : conventional commits (`feat:`, `fix:`, `chore:`, `docs:`)

## Deux repos

- `devopsforge` (public) : processus complet (workflows, prompts, scripts, config, exercises, specs).
- `devopsforge-profile` (privé) : données de maîtrise uniquement (`profile/`, `dues.yaml`, `errors.log`) + backup `.specify/`.

## Structure des données

- `profile/<domaine>.yaml` (repo privé) → `notions.<nom>.scores.{connaissance,implementation,debug,explication,design,securite,performance}`
- `dues.yaml` (repo privé) → `dues[]` : `{notion, dimensions[], priority, due_since}`
- `exercises/NNN-notion/` (repo public) → `exercise.md` (énoncé), `code/` (ton travail), `submission.md` (auto-éval), `analysis.md` (front-matter YAML machine-readable + corps Markdown ; contrat : `specs/001-devopsforge-mvp/contracts/analysis-format.md`)

Le chemin du repo privé est passé aux scripts via la variable d'env `PROFILE_REPO_PATH` (défaut : racine locale).

## Scripts (Python 3.11+, deps : pyyaml, requests, python-dateutil)

- `scripts/update_profile.py` : lit l'analyse, met à jour le profil, calcule `due_at` (Ebbinghaus), met à jour `dues.yaml`.
- `scripts/select_due_notions.py` : retourne les notions dues prioritaires (YAML/JSON sur stdout).
- `scripts/apply_decay.py` : décroissance quotidienne `score * exp(-rate * jours)` — **nice-to-have différé, non câblé**.
- `scripts/_common.py` : helpers internes (dimensions, clamp, Ebbinghaus, localisation de notion).

## Workflows

Tout changement arrive sur `main` via PR (branche protégée : PR + 1 approbation + status checks).

- `generate-exercise.yml` : `workflow_dispatch` + cron `0 6 * * 1-5` → clone le repo privé, détermine `NNN` + notion prioritaire, génère `exercises/NNN-notion/exercise.md` → ouvre une PR `bot/exercise-*`.
- `analyze-session.yml` : `pull_request` sur `exercises/**/submission.md` → lint (`shellcheck`/`flake8` sur les fichiers de `code/`) + anti-patterns + LLM → commit `exercises/NNN-notion/analysis.md` + approbation.
- `update-profile.yml` : `push` sur `main` (`exercises/**/analysis.md`) + `workflow_dispatch` → clone le repo privé → `scripts/update_profile.py` (via `PROFILE_REPO_PATH`) → push direct sur le repo privé.

## Tests

Exécuter localement (avec `PROFILE_REPO_PATH` pointant sur le repo privé) :
`python3 scripts/update_profile.py --analysis <fixture>`, puis `select_due_notions.py`.
Valider : `python3 -c "import yaml; yaml.safe_load(open('<PROFILE_REPO_PATH>/profile/linux.yaml'))"`.

## Ne pas faire

- Ne pas ajouter de dépendance exotique.
- Ne pas intégrer OpenClaw / WakaTime / NotebookLM (différés, hors MVP).
- Ne pas dépasser 2 notions dans le profil au MVP.
