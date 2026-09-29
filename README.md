# DevOpsForge

Système d'apprentissage adaptatif pour une carrière DevOps (Linux → Docker → K8s → Terraform → Observabilité → DevSecOps).

DevOpsForge remplace les flashcards statiques par des **exercices de code multi-conceptuels** avec spaced repetition (**SM-2** : intervalles 1, 6, puis × facteur de facilité). L'**IA est un tuteur, pas une béquille** : elle génère les exercices et évalue les soumissions ; toi, tu résous, en mode environnement de travail (PR, lint, status checks, git propre).

## Architecture — deux repos

| Repo | Visibilité | Rôle |
|---|---|---|
| `devopsforge` (ce repo) | public | Processus complet : workflows, prompts, scripts, exercices, specs. Transparence pour les recruteurs. |
| `devopsforge-profile` | privé | Données de maîtrise (`profile/*.yaml`, `dues.yaml`, `errors.log`) + `roadmap.yaml` (plan d'apprentissage). |

Les workflows publics lisent/écrivent le profil privé via `GH_TOKEN` (cross-repo). Le rapport d'analyse par exercice (scores, anti-patterns) est public ; seul le profil cumulé reste privé.

## Structure d'un exercice

```
fil-rouge/                     # TON code (projet fil rouge unique, évolue d'incrément en incrément)
└── logsentry/
    ├── bin/logsentry.sh       # le CLI (incrément 1)
    ├── Dockerfile             # la conteneurisation (incrément 2)
    └── tests/

exercises/
└── 001-bash_scripting/        # <NNN>-<notion principale>
    ├── exercise.md            # généré par le bot (l'énoncé)
    ├── submission.md          # TON auto-évaluation (déclenche l'analyse)
    └── analysis.md            # généré par le bot (scores + feedback)
```

Le code vit dans `fil-rouge/` (un seul projet qui grandit à chaque incrément). Chaque exercice est un dossier numéroté (`001`, `002`…) nommé d'après sa notion principale, contenant l'énoncé et l'auto-évaluation. Un recruteur voit d'un coup d'œil combien d'exercices tu as faits et sur quelles notions.

## Cycle de fonctionnement

Tout changement arrive sur `main` via **PR** (branche protégée : PR + 1 approbation + status checks).

1. **Génération** — `generate-exercise.yml` (cron `0 6 * * 1-5` ou `workflow_dispatch`) lit `profile/`+`dues.yaml` du repo privé, détermine le prochain `NNN` et la notion prioritaire, génère `exercises/NNN-notion/exercise.md`, puis ouvre une PR sur la branche `exoNNN/<notion>`.
2. **Soumission** — tu résous l'exercice dans `fil-rouge/`, remplis l'auto-évaluation dans `exercises/NNN-notion/submission.md`, et ouvres une PR vers `main`.
3. **Analyse** — `analyze-session.yml` (`push` sur `exercises/**/submission.md`) lance `shellcheck`/`flake8` sur `fil-rouge/`, évalue via LLM, committe `analysis.md`, puis **poste le rapport complet en commentaire de PR**.
4. **Mise à jour** — au merge, `update-profile.yml` (`push` sur `main`) clone le repo privé, exécute `scripts/update_profile.py` (scores, `due_at` **SM-2**, `dues.yaml`) et pousse le résultat.

## Structure (repo public)

```text
.github/workflows/  # génération, analyse, mise à jour (flux PR + cross-repo)
.github/prompts/    # prompts LLM (génération, évaluation)
scripts/            # update_profile.py, select_due_notions.py, _common.py (SM-2)
config/             # thresholds, grading_weights, forgetting, agent (routage LLM)
fil-rouge/          # TON code (projet fil rouge)
exercises/          # NNN-notion/{exercise,submission,analysis}.md
specs/              # spécification SpecKit du MVP
tests/              # fixtures
journal.md          # journal de progression
```

## Configuration des secrets GitHub (repo public)

| Secret / Variable | Type | Rôle |
|---|---|---|
| `AI_GATEWAY_API_KEY` | secret | Clé de la passerelle IA OpenAI-compatible |
| `AI_GATEWAY_BASE_URL` | variable | URL de base (ex. `https://api.deepseek.com/v1`) |
| `GH_TOKEN` | secret | Token (classic) sur **compte séparé**, accès aux 2 repos : `repo` (Contents + Pull requests) |
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
3. Une PR s'ouvre sur la branche `exoNNN/<notion>` ; relire et **merger**.

## Soumettre un exercice

1. Créer une branche.
2. Écrire ton code dans `fil-rouge/` (le projet fil rouge).
3. Remplir `exercises/NNN-notion/submission.md` (auto-évaluation : ce qui a été fait, difficultés, confiance par notion).
4. Ouvrir une PR vers `main` → le bot linte, analyse, committe `analysis.md` et **poste le rapport en commentaire**.
5. **Merger** : le profil privé se met à jour automatiquement.

## Développement local

Cloner les deux repos, puis pointer le profil :

```bash
git clone git@github.com:M-Boiguille/devopsforge.git
git clone git@github.com:M-Boiguille/devopsforge-profile.git
cd devopsforge
export PROFILE_REPO_PATH=/chemin/vers/devopsforge-profile
pip install pyyaml
python3 scripts/update_profile.py --analysis exercises/001-bash_scripting/analysis.md
python3 scripts/select_due_notions.py --limit 3
```

## Ajouter une nouvelle notion

1. Dans `devopsforge-profile/roadmap.yaml`, ajouter la notion dans le bon domaine (dans l'ordre souhaité).
2. Pour l'« activer » (la rendre enseignable), la copier dans `profile/<domaine>.yaml` (7 dimensions à `0.0`, `last_reviewed: null`, `due_at: null`).
3. Elle apparaîtra dans les exercices via `select_due_notions.py`.
