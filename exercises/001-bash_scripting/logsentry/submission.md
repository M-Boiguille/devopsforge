# ADR 001: LogSentry — Parseur de logs robuste en Bash

- **Statut** : Accepté / Complété
- **Date** : 2026-09-27
- **Auteur** : SRE Team / Student
- **Emplacement** : `exercises/001-bash_scripting/logsentry/`

---

## 1. Contexte & Portée

Création de la première brique de l'outil CLI `LogSentry` pour analyser des logs d'accès HTTP (`text` et `JSONL`). L'objectif est d'extraire le volume de requêtes, le taux d'erreur 5xx, la latence moyenne, le nombre de requêtes lentes et le Top N des endpoints.

### Décisions de structure & correctifs
- **Arborescence** : Remplacement du chemin initial `~/fil-rouge/` par `exercises/001-bash_scripting/logsentry/` afin de centraliser l'ensemble des incréments dans un unique dépôt Git.
- **Correction d'exercice** : Mise à jour du fichier `exercice.md` pour corriger les erreurs dans les commandes de génération initiales.
- **Outillage** : Ajout d'un script dédié pour générer les faux jeux de données (`access.log` et `access.jsonl`).

---

## 2. Décisions d'Architecture Technique

| Sujet | Décision prise | Raison / Justification |
| :--- | :--- | :--- |
| **Parsing des arguments** | Boucle `while` + `case` + `shift` | `getopts` (builtin Bash) a été écarté car il ne supporte pas nativement les options longues (`--input`, `--format`). |
| **Parsing mode texte** | Single-pass `AWK` + `sort` | Respect de la contrainte d'un seul passage sur le fichier. Agrégation en mémoire et tri délégué via un pipe interne AWK vers `sort`. |
| **Parsing mode JSON** | `jq` (avec assistance IA) | Utilisation de `jq` avec `--slurp` (`-s`) et `--argjson`. La syntaxe avancée de `jq` pour le traitement JSONL a été accélérée via l'assistance d'une IA (notion complexe à ce stade). |
| **Gestion d'erreurs** | `set -euo pipefail` + exit codes stricts | Respect strict des codes de retour (`1`: usage, `2`: fichier illisible, `3`: format invalide, `4`: fichier vide). |

---

## 3. Rétrospective & Auto-évaluation

- **Temps passé** : > 1 h 30 min (reprise en main nécessaire due à un manque de pratique récent).
- **Points forts** :
  - Bonne aisance sur la **logique algorithmique** et le découpage fonctionnel (`parse_args`, `validate_args`, `analyze_text`, `analyze_json`).
  - Architecture propre avec entrée unique `main "$@"`.
- **Difficultés rencontrées** :
  - **Syntaxe Bash** : Réadaptation à l'écriture des conditions (`[[ ... ]]`), gestion des variables et pièges du typage implicite.
  - **Types dans `jq`** : Piège sur la comparaison chaînes/nombres (`duration_ms` vs `threshold`).

---

## 4. Statut des Livrables

- [x] Script executable `bin/logsentry.sh` fonctionnel.
- [x] Linting validé (`shellcheck -S warning` → 0 warning).
- [x] Respect des 4 exit codes imposés.
- [x] Equivalance stricte des métriques entre les modes `-f text` et `-f json`.
- [x] Validation de la sortie JSON via `jq -e .`.
