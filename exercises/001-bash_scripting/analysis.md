---
date: '2026-09-27'
notions:
- notion: bash_scripting
  scores:
    connaissance: 0.4
    implementation: 0.5
    debug: 0.4
    explication: 0.2
    design: 0.7
    securite: 0.6
    performance: 0.5
  anti_patterns:
  - manual_option_parsing_instead_of_getopts
  - missing_argument_validation
  strengths:
  - Fonctions bien séparées
  - set -euo pipefail
  weaknesses:
  - Pas de getopts
  - Pas de gestion des arguments manquants
  - Pas de NOTES.md
- notion: file_parsing
  scores:
    connaissance: 0.7
    implementation: 0.7
    debug: 0.5
    explication: 0.3
    design: 0.6
    securite: 0.6
    performance: 0.8
  anti_patterns:
  - command_construction_in_awk
  - no_validation_of_line_format
  strengths:
  - Single-pass AWK
  - Tri délégué à sort
  - Usage de jq
  weaknesses:
  - Pas de test automatisé
  - jq -s charge tout en mémoire
- notion: bash_scripting_advanced
  scores:
    connaissance: 0.2
    implementation: 0.2
    debug: 0.2
    explication: 0.2
    design: 0.3
    securite: 0.3
    performance: 0.2
  anti_patterns:
  - no_trap
  - no_shellcheck_output
  strengths: []
  weaknesses:
  - Aucun trap implémenté
  - Pas de preuve de lint
  - Pas de fichier NOTES.md
calibration:
  overconfidence: true
  underconfidence: false
  notes: Auto-évaluation considère tous les livrables complétés alors que NOTES.md
    est absent, getopts non utilisé, trap non implémenté. Légère sur-confiance.
---
# Évaluation LogSentry — Incrément 1

## Synthèse
Le script `bin/logsentry.sh` est fonctionnel et respecte les exit codes imposés. Cependant, des manquements importants sont relevés : le livrable `tests/NOTES.md` est absent, l'utilisation de `getopts` (notion cible) n'est pas démontrée, aucun `trap` n'est mis en place, et la robustesse face aux lignes malformées est insuffisante. La note globale pondérée est estimée à 0.45/1, ce qui correspond à un niveau « à consolider » (seuil < 0.60).

## Scores par dimension (moyenne toutes notions)
- Implémentation : 0.55 — Fonctionne, mais pas de getopts, validation des arguments partielle.
- Connaissance : 0.40 — Usage correct d'awk, jq correct mais aide IA, pas getopts.
- Debug : 0.35 — set -euo pipefail, mais pas de trap, pas de gestion des lignes malformées.
- Explication : 0.20 — ADR présent mais NOTES.md absent, explications sommaires.
- Design : 0.60 — Découpage en fonctions, main propre.
- Sécurité : 0.55 — Quoting majoritairement correct, pas d'eval, mais construction de commande dans awk.
- Performance : 0.60 — Un seul passage awk, LC_ALL=C, mais jq -s charge tout.

## Analyse de calibration
L'auto-évaluation est légèrement sur-confiente : elle coche tous les critères de réussite alors que `tests/NOTES.md` n'est pas fourni, que `getopts` est remplacé par une boucle `while/case`, et qu'aucun `trap` n'est implémenté. Les difficultés mentionnées (syntaxe Bash, types jq) sont réelles mais sous-estiment les lacunes opérationnelles.

## Anti-patterns détectés
- **Parsing manuel des options** : non-utilisation de `getopts` malgré l'objectif pédagogique ; risque de régression.
- **Validation insuffisante des arguments** : `parse_args` n'accepte pas les erreurs d'argument manquant de façon propre (ex. `-i` seul -> fichier "-i").
- **Construction de commande dans awk** : `cmd = "sort ... | head -n " top_n` ; sûre ici car top_n validé, mais anti-pattern de sécurité.
- **Absence de trap** : objectif `bash_scripting_advanced` non couvert.
- **Pas de validation du format des lignes** : une ligne texte malformée sera comptée avec des champs vides, faussant les métriques.
- **Script générateur défectueux** : `generate_dummy_logs.sh` utilise un chemin absolu `/data/` inexistant et ne supprime pas le suffixe `ms` correctement.

## Points forts
- Structure claire avec fonctions dédiées (`usage`, `parse_args`, `validate_args`, `analyze_text`, `analyze_json`, `main`).
- `set -euo pipefail` et `IFS` corrects.
- Analyse texte en un seul passage awk avec tri délégué à `sort`, conforme à la contrainte.
- Sortie JSON valide et composable via jq.

## Points faibles
- Livrable `tests/NOTES.md` manquant.
- Non-utilisation de `getopts`.
- Aucun `trap`.
- Pas de tests automatisés ni de rapport shellcheck inclus.
- Gestion des cas limites incomplète (lignes malformées, N > nb endpoints non testé).

## Recommandations
1. **Lecture ciblée** : revoir le builtin `getopts` et l'utiliser pour les options courtes, en complétant avec une boucle pour les options longues si nécessaire (ou utiliser `getopt` externe). Rédiger `tests/NOTES.md` avec les 5 codes ShellCheck demandés.
2. **Robustesse** : ajouter un `trap` de nettoyage même sans fichier temporaire (ex. signal), valider la présence de l'argument pour chaque option, et filtrer les lignes malformées en awk (vérifier NF >= 6).
3. **Sécurité** : éviter toute construction de commande dynamique ; utiliser `printf` + pipe avec des variables d'environnement awk si possible.
4. **Tests** : créer un script de test automatisé (bats ou simple bash) couvrant les exit codes, la sortie JSON, l'équivalence text/json, et les cas limites.
5. **Exercices futurs** : intégrer `getopts`, `trap`, et des tests dès l'incrément 2 (Docker) pour consolider les notions avancées.
