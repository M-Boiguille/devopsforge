---
date: '2026-09-27'
notions:
- notion: bash_scripting
  scores:
    connaissance: 0.75
    implementation: 0.85
    debug: 0.75
    explication: 0.6
    design: 0.85
    securite: 0.85
    performance: 0.7
  anti_patterns:
  - manual_arg_parsing_instead_of_getopts
  - use_of_echo_instead_of_printf
  strengths:
  - Fonctions bien décomposées (usage, parse_args, validate_args, analyze_*, main)
  - Validation stricte des entrées et des options
  - Quoting systématique des variables
  weaknesses:
  - getopts non utilisé malgré la notion cible
  - Echo au lieu de printf pour les messages d'erreur/debug
  - Pas de NOTES.md sur les codes ShellCheck
- notion: file_parsing
  scores:
    connaissance: 0.7
    implementation: 0.8
    debug: 0.7
    explication: 0.6
    design: 0.8
    securite: 0.75
    performance: 0.6
  anti_patterns:
  - jq_slurp_whole_file
  - no_memory_optimization_for_large_logs
  strengths:
  - Un seul passage awk pour l'agrégation texte (comptage, moyenne, top)
  - Validation de sortie JSON via jq -e
  - Utilisation correcte de sort et head pour le top N
  weaknesses:
  - jq -s charge tout le fichier JSONL en mémoire, non scalable
  - Pas de traitement streaming JSON pour les gros volumes
  - Script generate_dummy_logs.sh avec chemins absolus incohérents
- notion: bash_scripting_advanced
  scores:
    connaissance: 0.5
    implementation: 0.6
    debug: 0.5
    explication: 0.5
    design: 0.5
    securite: 0.6
    performance: 0.5
  anti_patterns:
  - no_trap_cleanup
  - missing_notes_shellcheck
  strengths:
  - shellcheck -S warning passe sans erreur
  - set -euo pipefail bien en place
  weaknesses:
  - Aucun trap de signaux ou de nettoyage
  - Pas de NOTES.md explicitant les codes ShellCheck demandés
  - Gestion des signaux non démontrée
calibration:
  overconfidence: true
  underconfidence: false
  notes: 'L''étudiant affiche une confiance modérée mais ne mentionne pas certaines
    lacunes : absence de NOTES.md, évitement de getopts, et utilisation de jq -s non
    scalable. Il reconnaît l''assistance IA pour jq mais n''identifie pas les limites
    de performance.'
---
# Évaluation LogSentry — Incrément 1

## Scores globaux par dimension

| Dimension | Score (0-1) | Justification |
|-----------|-------------|---------------|
| Connaissance | 0.70 | Bonne maîtrise globale de bash, awk, jq, mais des écarts sur getopts et la compréhension des limites de jq -s. |
| Implementation | 0.80 | Le script fonctionne, les exit codes sont respectés, la sortie est conforme. Quelques choix sous-optimaux (jq -s). |
| Debug | 0.70 | set -euo pipefail, validation des entrées, mais pas de trap ni de gestion fine des signaux. |
| Explication | 0.55 | ADR présent mais NOTES.md manquant, explications des choix techniques absentes. |
| Design | 0.80 | Découpage en fonctions clair, main() présent, séparation texte/json propre. |
| Sécurité | 0.80 | Quoting strict, pas d'eval, pas d'injection. Des améliorations possibles (printf, trap). |
| Performance | 0.60 | Un seul awk et LC_ALL=C pour le texte, mais jq -s lit tout le fichier en mémoire, non adapté à de gros volumes. |

## Analyse de calibration

**Overconfidence légère** : l'étudiant considère le travail comme complet et validé, mais ne mentionne pas :
- l'absence de NOTES.md sur les codes ShellCheck (livrable demandé),
- l'évitement de getopts alors que la notion cible est `arguments_getopts`,
- la non-scalabilité de `jq -s` pour un fichier de logs volumineux.

Il reconnaît une reprise en main difficile et l'aide de l'IA pour `jq`, ce qui montre une certaine lucidité, mais la confiance dans le résultat final masque ces manques.

## Anti-patterns détectés

1. **Évitement de `getopts`** : boucle `while` manuelle justifiée par le support des options longues, mais la notion cible n'est pas démontrée.
2. **`jq -s` (slurp)** : charge l'intégralité du fichier JSONL en mémoire, ce qui est inefficace pour de gros logs (contraire à l'esprit d'un parseur robuste).
3. **`echo` au lieu de `printf`** : dans `echo_err` et `log_verbose`, peut causer des problèmes de portabilité ou d'interprétation des backslashes.
4. **Script `generate_dummy_logs.sh` incohérent** : utilise des chemins absolus `/data/` au lieu de relatifs, et ne gère pas correctement le nom de fichier.
5. **Absence de `trap`** : même sans fichier temporaire, un trap de nettoyage/signal est attendu pour la robustesse.
6. **Pas de `NOTES.md`** : le livrable de lecture demandant 3 lignes sur les codes ShellCheck n'est pas fourni.

## Points forts

- Structure du script claire avec fonctions dédiées et `main "$@"`.
- Validation complète des arguments : existence, lisibilité, format, entiers positifs.
- Agrégation texte en un seul passage `awk` avec tableaux associatifs et `END`.
- Sortie JSON conforme, validée par `jq -e .`.
- Quoting systématique, pas d'`eval`, pas d'injection possible.
- `shellcheck -S warning` passe sans warning.

## Points faibles

- `getopts` non utilisé, ce qui affaiblit la conformité à la notion cible.
- `jq -s` non scalable, pas de traitement streaming.
- Absence de `trap` et de gestion des signaux.
- `echo` au lieu de `printf` pour les messages.
- `generate_dummy_logs.sh` défectueux (chemins absolus, redirections incorrectes).
- Livrable `tests/NOTES.md` manquant.

## Recommandations

1. **Lire et produire `tests/NOTES.md`** : résumer les codes ShellCheck SC2086, SC2046, SC2181, SC2002, SC2164.
2. **Implémenter `getopts`** pour les options courtes, éventuellement en complément d'un parsing manuel pour les longues.
3. **Remplacer `jq -s`** par un traitement streaming (`jq -c` avec `while read`) ou utiliser `awk` pour le JSONL si possible.
4. **Ajouter un `trap 'rm -f "$tmpfile"' EXIT INT TERM`** même si aucun fichier temporaire n'est utilisé, pour la robustesse.
5. **Remplacer `echo` par `printf`** dans les fonctions d'erreur et de debug.
6. **Corriger `generate_dummy_logs.sh`** : utiliser des chemins relatifs, valider les arguments, et assurer la cohérence des redirections.
7. **Passer en revue les bonnes pratiques ShellCheck** pour éviter les pièges classiques.
