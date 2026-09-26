# Feature Specification: DevOpsForge MVP

**Feature Branch**: `001-devopsforge-mvp`

**Created**: 2026-09-25

**Status**: Draft

**Input**: User description: "Construire le squelette initial fonctionnel de DevOpsForge, un système d'apprentissage adaptatif DevOps (Linux → Docker → K8s → Terraform → Observabilité → DevSecOps). MVP de bout en bout sur UNE seule notion, scalables ensuite."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Générer un exercice ciblé (Priority: P1)

L'apprenant déclenche (manuellement ou par cron) la génération d'un exercice de 30-60 minutes qui intègre
les notions fragiles détectées dans son profil, sous forme d'un fichier `exercises/NNN-notion/exercise.md`.

**Why this priority**: C'est le point d'entrée du cycle. Sans exercice généré, rien d'autre ne peut se produire.

**Independent Test**: Lancer le workflow `generate-exercise` produit un fichier `exercise.md` committé contenant
titre, contexte, objectifs, instructions, ressource, grille de notation et critères de réussite.

**Acceptance Scenarios**:

1. **Given** un profil avec des notions dues, **When** le workflow `generate-exercise` est déclenché, **Then** un fichier `exercises/NNN-notion/exercise.md` est créé et committé, intégrant au moins 2 notions dues.
2. **Given** aucun `dues.yaml` renseigné, **When** le workflow est déclenché, **Then** un exercice sur une notion existante du profil est généré (pas de crash).

---

### User Story 2 - Analyser une soumission (Priority: P1)

L'apprenant résout l'exercice, remplit une fiche d'auto-évaluation, puis pousse `exercises/NNN-notion/submission.md`.
Le système analyse la soumission (lint, tests, anti-patterns) et écrit un rapport structuré `exercises/NNN-notion/analysis.md`.

**Why this priority**: L'analyse produit la matière première (scores par dimension) qui alimente le profil.

**Independent Test**: Pousser un `submission.md` déclenche `analyze-session`, qui produit un `analysis.md`
avec un front-matter YAML machine-readable (scores par notion et dimension, anti-patterns, calibration).

**Acceptance Scenarios**:

1. **Given** un `submission.md` poussé, **When** le workflow `analyze-session` s'exécute, **Then** un `analysis.md` est écrit et committé avec des scores bornés `[0,1]` par dimension.
2. **Given** une soumission contenant un secret hardcodé, **When** l'analyse s'exécute, **Then** l'anti-pattern `hardcoded_secret` est détecté et reporté.

---

### User Story 3 - Mettre à jour le profil multidimensionnel (Priority: P1)

À partir d'un `analysis.md`, le profil `profile/*.yaml` est mis à jour (7 dimensions par notion), les échéances
de révision (`due_at`) sont recalculées avec la courbe d'Ebbinghaus, et `dues.yaml` reflète les notions fragiles.

**Why this priority**: C'est la boucle de rétroaction qui rend le système « adaptatif ».

**Independent Test**: Exécuter `scripts/update_profile.py` sur un `analysis.md` factice met à jour
`profile/linux.yaml`, calcule `last_reviewed`/`due_at`, et met à jour `dues.yaml`.

**Acceptance Scenarios**:

1. **Given** un `analysis.md` avec des scores, **When** `update_profile.py` s'exécute, **Then** les scores de la notion cible sont mis à jour, `last_reviewed` = date du jour, `due_at` = date future.
2. **Given** une dimension sous le seuil de révision (0.80), **When** le profil est mis à jour, **Then** la notion apparaît dans `dues.yaml` avec ses dimensions fragiles.

---

### User Story 4 - Appliquer l'oubli programmé (Différé — hors MVP)

> **Différé** : la décroissance quotidienne des scores (courbe d'Ebbinghaus) est un nice-to-have, non inclus
> dans le MVP. Le script `apply_decay.py` est fourni et testé, mais n'est câblé à aucun workflow.

---



### Edge Cases

- Notion absente du profil mais présente dans l'analyse → ignorée avec un log dans `errors.log`.
- Dimension absente d'une notion dans l'analyse → le score existant est conservé.
- Score hors bornes (négatif ou > 1) → clampé à `[0,1]`.
- `dues.yaml` vide ou absent → les scripts ne plantent pas.
- Fichier d'analyse mal formé (front-matter YAML invalide) → erreur tracée dans `errors.log`, pas de crash silencieux.
- Deux analyses le même jour → la dernière écrase (idempotent), `last_reviewed` mis à jour.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT stocker le profil de maîtrise en YAML, une notion par entrée sous `profile/*.yaml`, avec 7 dimensions (connaissance, implementation, debug, explication, design, securite, performance) bornées `[0,1]`.
- **FR-002**: Le système DOIT générer un exercice de 30-60 min intégrant 3 à 8 notions (cible à ajuster selon la granularité des ressources), via un workflow GitHub Actions appelant une passerelle IA OpenAI-compatible.
- **FR-003**: Le système DOIT analyser une soumission (lint `flake8`/`shellcheck` sur les blocs de code extraits + détection anti-patterns + évaluation LLM) et produire un rapport structuré avec scores par dimension.
- **FR-004**: Le système DOIT mettre à jour le profil à partir du rapport d'analyse, recalculer `due_at` via la courbe d'Ebbinghaus, et maintenir `dues.yaml`.
- **FR-005**: *(Différé — hors MVP)* Le système POURRA appliquer une décroissance quotidienne des scores selon `score * exp(-rate * jours_ecoules)`.
- **FR-006**: Le système DOIT sélectionner les N notions dues prioritaires (priorité + ancienneté) pour la génération d'exercice.
- **FR-007**: Le système NE DOIT contenir aucun secret ni donnée sensible ; les tokens vivent exclusivement dans les secrets GitHub Actions.
- **FR-008**: Le système DOIT être déterministe et versionné : toute mutation du profil passe par un script Python ou un workflow commité. Les changements arrivent sur `main` via PR (branche protégée).

### Key Entities *(include if feature involves data)*

- **Notion**: Unité d'apprentissage (`bash_scripting`, `file_parsing`) avec définition, sous-notions, scores par dimension, `last_reviewed`, `due_at`, liens de PR.
- **Due**: Entrée de révision en attente (notion + dimensions fragiles + priorité + ancienneté).
- **Session**: Un exercice (`YYYY-MM-DD-exercise.md`), sa soumission (`YYYY-MM-DD-submission.md`) et son analyse (`YYYY-MM-DD-analysis.md`).
- **Configuration**: Seuils (`thresholds.yaml`), poids de notation (`grading_weights.yaml`), oubli (`forgetting.yaml`), routage LLM (`agent.yaml`).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Un exercice factice sur `bash_scripting` peut être généré via une PR du bot, committé, et une soumission déclenche une analyse sans intervention manuelle.
- **SC-002**: `update_profile.py` et `select_due_notions.py` s'exécutent sur des fixtures et produisent des YAML valides (parsés par `pyyaml` sans erreur).
- **SC-003**: Après exécution de `update_profile.py`, chaque score mis à jour est borné `[0,1]` et `due_at` est une date future.
- **SC-004**: Aucune donnée sensible n'est présente dans le repo (vérifiable par revue de diff).

## Assumptions

- Le MVP couvre uniquement le domaine Linux avec 2 notions (`bash_scripting`, `file_parsing`) ; les exercices visent 3 à 8 notions à terme (granularité des ressources à définir).
- Le projet est réparti sur deux repos : `devopsforge` (public, processus complet) et `devopsforge-profile` (privé, uniquement `profile/` + `dues.yaml` + `errors.log`). Les workflows publics accèdent au profil privé via `GH_TOKEN` + la variable `PROFILE_REPO_PATH`.
- L'évaluation multidimensionnelle est réalisée par `analyze-session.yml` (DeepSeek Pro) au MVP ; OpenClaw (socratique/Feynman, entretien simulé) est différé.
- La décroissance quotidienne (Ebbinghaus) est différée hors MVP (nice-to-have).
- La branche `main` est protégée : PR obligatoire + 1 approbation + status checks requis. Le bot ouvre des PR et approuve les soumissions ; l'humain merge.
- La passerelle IA est OpenAI-compatible ; `base_url` et identifiants de modèles sont configurés via secrets/variables GitHub.
- `{project_state}`, `{last_exercise}` et `{errors_log}` sont des placeholders vides au MVP (le projet fil rouge public n'existe pas encore).
- Le format du rapport d'analyse utilise un front-matter YAML machine-readable suivi d'un corps Markdown lisible.
