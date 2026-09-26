---
date: "2026-09-25"
exercise_file: "exercises/001-bash_scripting/exercise.md"
submission_file: "exercises/001-bash_scripting/submission.md"
notions:
  - notion: bash_scripting
    scores:
      connaissance: 0.85
      implementation: 0.80
      debug: 0.70
      explication: 0.90
      design: 0.60
      securite: 0.50
      performance: 0.55
    anti_patterns: ["hardcoded_secret"]
    strengths: ["bonne gestion d'erreurs avec set -euo pipefail"]
    weaknesses: ["pas de resource limits, secret en clair"]
  - notion: file_parsing
    scores:
      connaissance: 0.78
      implementation: 0.75
      debug: 0.60
      explication: 0.80
      design: 0.55
      securite: 0.70
      performance: 0.65
    anti_patterns: []
    strengths: ["usage correct de awk/sed"]
    weaknesses: ["regex fragile"]
calibration:
  overconfidence: true
  underconfidence: false
  notes: "L'apprenant se surévalue légèrement sur la dimension debug."
---
# Rapport d'analyse — bash_scripting & file_parsing

Scores détaillés, points forts/faibles et recommandations de lecture ciblée.
