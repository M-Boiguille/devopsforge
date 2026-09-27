---
date: '2026-09-27'
notions:
- notion: bash_scripting
  scores:
    connaissance: 0.5
    implementation: 0.7
    debug: 0.6
    explication: 0.3
    design: 0.7
    securite: 0.7
    performance: 0.8
  anti_patterns:
  - manual_option_parsing_instead_of_getopts
  - missing_option_argument_value_check
  strengths:
  - Fonctions bien séparées (usage, parse_args, validate_args, analyze_text, analyze_json,
    main)
  - set -euo pipefail et validation des entiers
  weaknesses:
  - N'utilise pas getopts comme demandé
  - Ne gère pas les options longues de forme --opt=valeur
  - Pas de vérification que la valeur d'option ne commence pas par un tiret
- notion: file_parsing
  scores:
    connaissance: 0.6
    implementation: 0.5
    debug: 0.6
    explication: 0.3
    design: 0.7
    securite: 0.7
    performance: 0.8
  anti_patterns:
  - output_text_format_missing_ranking_numbers
  - no_demonstration_of_cut_sort_uniq_or_grep
  strengths:
  - Utilisation d'un seul awk avec tableaux et END
  - jq pour JSON avec sort_by, group_by
  weaknesses:
  - Sortie texte non conforme (pas de numérotation des endpoints)
  - Pas d'utilisation de cut/sort/uniq/grep pour l'extraction, contrairement aux objectifs
- notion: bash_scripting_advanced
  scores:
    connaissance: 0.2
    implementation: 0.4
    debug: 0.4
    explication: 0.3
    design: 0.7
    securite: 0.6
    performance: 0.8
  anti_patterns:
  - no_trap_for_cleanup
  - shellcheck_result_not_included_in_submission
  strengths:
  - Script linté sans warning (selon l'auto-évaluation)
  - Pas d'utilisation de eval ou de commandes dangereuses
  weaknesses:
  - Aucun trap de nettoyage
  - Pas de fichier temporaire ni gestion des signaux
  - NOTES.md manquant pour expliquer les codes ShellCheck
calibration:
  overconfidence: true
  underconfidence: false
  notes: L'auto-évaluation coche toutes les cases de réussite, mais la sortie texte
    ne respecte pas exactement le format demandé (numérotation manquante), NOTES.md
    est absent, et getopts n'est pas utilisé. L'étudiant reconnaît des difficultés
    mais surestime la conformité globale.
---
# Évaluation LogSentry — Incrément 1

## Scores par dimension (moyenne sur les notions)
- Connaissance : 0.43 (bash_scripting 0.5, file_parsing 0.6, bash_scripting_advanced 0.2)
- Implémentation : 0.53 (0.7, 0.5, 0.4)
- Debug : 0.53 (0.6, 0.6, 0.4)
- Explication : 0.30 (0.3, 0.3, 0.3)
- Design : 0.70 (0.7, 0.7, 0.7)
- Sécurité : 0.67 (0.7, 0.7, 0.6)
- Performance : 0.80 (0.8, 0.8, 0.8)

## Calibration
L'auto-évaluation surestime la conformité : elle affirme que tous les critères sont remplis, mais la sortie texte ne respecte pas exactement la forme (numéros manquants), le fichier tests/NOTES.md est absent, et getopts n'est pas utilisé. Des difficultés sont mentionnées (jq, syntaxe Bash), mais l'étudiant ne les relie pas aux écarts constatés.

## Anti-patterns détectés
- Parsing manuel des options au lieu de getopts ; risque de confusion si une valeur d'option commence par '-'.
- Sortie texte non conforme : pas de numérotation des endpoints.
- Absence de trap de nettoyage (non critique car pas de fichier temporaire, mais objectif non démontré).
- Pas de démonstration des outils cut/sort/uniq/grep.
- Pas de NOTES.md avec les explications ShellCheck.

## Points forts
- Architecture propre avec fonctions (usage, parse_args, validate_args, analyze_text, analyze_json, main).
- set -euo pipefail et validation des entiers.
- Un seul passage awk pour le mode texte, LC_ALL=C, pas de fork inutile.
- Sortie JSON valide et structurée.
- Quoting globalement correct, pas d'eval.

## Points faibles
- Non-respect du format de sortie texte (numéros).
- Utilisation de la boucle while/case au lieu de getopts comme demandé.
- Pas de trap ni gestion des signaux.
- Manque NOTES.md et explications des choix.
- Pas de tests automatisés (bats) ni de preuve des 4 exit codes.

## Recommandations
1. Revoir le format de sortie attendu et ajouter la numérotation `1.`, `2.`, etc.
2. Implémenter getopts pour les options courtes, et éventuellement une extension pour les options longues (ou utiliser un parseur externe si getopts est insuffisant, mais justifier).
3. Ajouter un trap `trap 'rm -f "$tmpfile"' EXIT INT TERM` même sans fichier temporaire pour la forme, ou créer un fichier temporaire pour la sortie.
4. Fournir tests/NOTES.md avec les explications demandées sur les codes ShellCheck et getopts.
5. Ajouter des tests automatisés (bats) pour valider les exit codes et les sorties.
6. Pour file_parsing, démontrer l'usage de grep/cut/sort/uniq dans des fonctions auxiliaires si besoin.
7. Améliorer la robustesse du parsing des options (vérifier que les valeurs ne commencent pas par un tiret, supporter `--opt=value`).

## Note globale indicative
La soumission est fonctionnelle mais incomplète par rapport aux exigences. Des correctifs sont nécessaires pour valider les notions cibles.
