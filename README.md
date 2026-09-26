# DevOpsForge

Système d'apprentissage adaptatif pour une carrière DevOps (Linux → Docker → K8s → Terraform → Observabilité → DevSecOps).

DevOpsForge remplace les flashcards statiques par des **exercices de code multi-conceptuels** avec spaced repetition (courbe d'Ebbinghaus). L'**IA est un tuteur, pas une béquille** : elle génère les exercices et évalue les soumissions ; toi, tu résous, en mode environnement de travail (PR, lint, status checks, git propre).

## Architecture — deux repos

| Repo | Visibilité | Rôle |
|---|---|---|
| `devopsforge` (ce repo) | public | Processus complet : workflows, prompts, scripts, sessions (exercices/soumissions/analyses), specs. Transparence pour les recruteurs. |
| `devopsforge-profile` | privé | Uniquement les données de maîtrise : `profile/*.yaml`, `dues.yaml`, `errors.log`. |

Les workflows publics lisent/écrivent le profil privé via `GH_TOKEN` (cross-repo). Le rapport d'analyse par exercice (scores, anti-patterns) est public ; seul le profil cumulé reste privé.

## Cycle de fonctionnement

Tout changement arrive sur `main` via **PR** (branche protégée : PR + 1 approbation + status checks).

1. **Génération** — `generate-exercise.yml` (cron `0 6 * * 1-5` ou `workflow_dispatch`) lit `profile/`+`dues.yaml` du repo privé, produit `sessions/YYYY-MM-DD-exercise.md` via un LLM, puis ouvre une PR `bot/exercise-*`.
2. **Soumission** — tu résous l'exercice, remplis l'auto-évaluation dans `sessions/YYYY-MM-DD-submission.md`, puis ouvres une PR vers `main`.
3. **Analyse** — `analyze-session.yml` (`pull_request` sur `**-submission.md`) lance `flake8`/`shellcheck` + détection anti-patterns + évaluation LLM, committe `sessions/YYYY-MM-DD-analysis.md` sur ta branche et **approuve** la PR.
4. **Mise à jour** — au merge, `update-profile.yml` (`push` sur `main`) clone le repo privé, exécute `scripts/update_profile.py` (scores, `due_at`, `dues.yaml`) et pousse le résultat.
5. *(Différé)* **Oubli** — `scripts/apply_decay.py` décroîtra les scores (`score * exp(-rate * jours)`), nice-to-have non câblé.

## Structure (repo public)

```text
.github/workflows/  # génération, analyse, mise à jour (flux PR + cross-repo)
.github/prompts/    # prompts LLM (génération, évaluation)
scripts/            # update_profile.py, select_due_notions.py (+ apply_decay.py différé)
config/             # thresholds, grading_weights, forgetting, agent (routage LLM)
sessions/           # YYYY-MM-DD-{exercise,submission,analysis}.md (public)
specs/              # spécification SpecKit du MVP
tests/              # fixtures
journal.md          # journal de progression
```

## Configuration des secrets GitHub (repo public)

| Secret / Variable | Type | Rôle |
|---|---|---|
| `AI_GATEWAY_API_KEY` | secret | Clé de la passerelle IA OpenAI-compatible |
| `AI_GATEWAY_BASE_URL` | variable | URL de base (ex. `https://api.deepseek.com/v1`) |
| `GH_TOKEN` | secret | Token fine-grained sur **compte séparé**, accès aux 2 repos : `Contents: R/W` + `Pull requests: R/W` |
| `PROJECT_STATE` | variable | État du projet fil rouge (placeholder au MVP) |

Les modèles par tâche sont dans `config/agent.yaml`.

## Protection de la branche `main` (repo public)

Dans **Settings → Branches → Branch protection rules** (branche `main`) :

- « Require a pull request before merging » ✅
- « Require approvals » → `1`
- « Dismiss stale pull request approvals when new commits are pushed » ✅
- « Require status checks to pass before merging » → `lint`
- « Include administrators » → ❌ (pour merger les PR du bot sans auto-approbation)

Le repo privé `devopsforge-profile` n'a pas de protection : le bot pousse directement (data store).

## Déclencher le premier exercice

1. Configurer les secrets/variables ci-dessus + la protection de branche.
2. GitHub → Actions → `generate-exercise` → **Run workflow**.
3. Une PR `bot/exercise-*` s'ouvre ; relire et **merger**.

## Soumettre un exercice

1. Créer une branche, ajouter `sessions/YYYY-MM-DD-submission.md` (code + auto-évaluation), ouvrir une PR vers `main`.
2. Le bot lance lint + analyse, committe `analysis.md`, et approuve la PR.
3. **Merger** : le profil privé se met à jour automatiquement.

## Développement local

Cloner les deux repos, puis pointer le profil :

```bash
git clone git@github.com:M-Boiguille/devopsforge.git
git clone git@github.com:M-Boiguille/devopsforge-profile.git
cd devopsforge
export PROFILE_REPO_PATH=/chemin/vers/devopsforge-profile
pip install pyyaml
python3 scripts/update_profile.py --analysis tests/fixtures/analysis-sample.md
python3 scripts/select_due_notions.py --limit 3
```

## Ajouter une nouvelle notion

1. Dans `devopsforge-profile/profile/<domaine>.yaml`, ajouter une entrée (7 dimensions à `0.0`, `last_reviewed: null`, `due_at: null`).
2. Elle apparaîtra dans les exercices via `select_due_notions.py`.
