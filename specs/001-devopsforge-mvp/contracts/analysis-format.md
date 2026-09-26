# Contract: Format du rapport d'analyse (`sessions/YYYY-MM-DD-analysis.md`)

Le rapport est un fichier Markdown dont le **front-matter YAML** (entre `---`) est machine-readable et consommé
par `scripts/update_profile.py`. Le corps (après le second `---`) est libre, destiné à la lecture humaine et à
OpenClaw (différé).

## Schéma du front-matter

```yaml
---
date: "2026-09-25"                 # date de l'analyse, YYYY-MM-DD
exercise_file: "sessions/2026-09-25-exercise.md"
submission_file: "sessions/2026-09-25-submission.md"
notions:                           # liste des notions évaluées
  - notion: bash_scripting
    scores:                        # bornés [0,1]
      connaissance: 0.85
      implementation: 0.80
      debug: 0.70
      explication: 0.90
      design: 0.60
      securite: 0.50
      performance: 0.55
    anti_patterns: ["hardcoded_secret"]   # motifs de thresholds.yaml
    strengths: ["bonne gestion d'erreurs"]
    weaknesses: ["pas de resource limits"]
calibration:                       # analyse de calibration (facultatif)
  overconfidence: false
  underconfidence: false
  notes: "Auto-évaluation proche de la performance réelle"
---
# Rapport d'analyse — bash_scripting

… corps Markdown libre (tableau des scores, points forts/faibles, recommandations) …
```

## Règles

- Chaque clé de `scores` DOIT appartenir aux 7 dimensions canoniques.
- Les scores hors `[0,1]` sont clampés par `update_profile.py`.
- Une notion absente de `profile/*.yaml` est ignorée et tracée dans `errors.log`.
- Une dimension absente de `scores` conserve l'ancien score du profil.
- Le front-matter YAML invalide provoque une erreur tracée dans `errors.log` (pas de mutation du profil).
