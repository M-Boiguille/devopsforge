# Data Model: DevOpsForge MVP

## Entity: Notion

Stockée dans `profile/<domaine>.yaml` sous la clé `notions`.

| Champ | Type | Requis | Règle |
|---|---|---|---|
| `definition` | string | oui | Description courte |
| `sub_notions` | list[string] | non | Sous-notions de base |
| `sub_notions_advanced` | list[string] | non | Sous-notions avancées |
| `scores.*` | float | oui | 7 dimensions, clamp `[0,1]` |
| `last_reviewed` | date | non | `YYYY-MM-DD` |
| `due_at` | date | non | `YYYY-MM-DD` |
| `pr_links` | list[string] | non | Références de PR |

Dimensions : `connaissance`, `implementation`, `debug`, `explication`, `design`, `securite`, `performance`.

## Entity: Due

Stockée dans `dues.yaml` sous la clé `dues`.

| Champ | Type | Requis | Règle |
|---|---|---|---|
| `notion` | string | oui | Identifiant de notion |
| `dimensions` | list[string] | oui | Sous-ensemble des 7 dimensions |
| `priority` | enum | oui | `low` / `medium` / `high` |
| `due_since` | date | oui | `YYYY-MM-DD` |

## Entity: Session

Fichiers sous `exercises/` au format `YYYY-MM-DD-<type>.md`.

- `YYYY-MM-DD-exercise.md` : exercice généré.
- `YYYY-MM-DD-submission.md` : soumission + auto-évaluation de l'apprenant.
- `YYYY-MM-DD-analysis.md` : rapport structuré (contrat en `contracts/analysis-format.md`).

## Entity: Configuration

- `config/thresholds.yaml` : seuils de difficulté, maîtrise, revue, entretien.
- `config/grading_weights.yaml` : poids de notation par type d'exercice.
- `config/forgetting.yaml` : paramètres de répétition espacée (**SM-2** : seuils de maîtrise, facteur de facilité, intervalles).
- `config/agent.yaml` : routage des modèles LLM par tâche.

## State transitions (Notion)

```
[0.0 initial] → review → scores mis à jour + last_reviewed/due_at (SM-2) → notion due quand une dimension < review_threshold → review …
```

`due_at` est recalculé à chaque revue via **SM-2** (intervalle = 1, 6, puis × facteur de facilité) ; une notion est marquée due
lorsqu'une de ses dimensions passe sous `review_threshold` (0.80). Il n'existe **aucune décroissance destructive** des scores.
