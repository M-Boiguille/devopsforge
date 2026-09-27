---
date: '2026-09-27'
notions:
- notion: bash_scripting
  scores:
    connaissance: 0.7
    implementation: 0.8
    debug: 0.7
    explication: 0.5
    design: 0.7
    securite: 0.8
    performance: 0.7
  anti_patterns:
  - getopts_not_used
  - manual_arg_parsing_with_shift
  - no_trap_cleanup
  strengths:
  - Fonctions découpées (parse_args, validate_args, analyze_*)
  - Gestion des options courtes et longues avec exit codes
  - Validation des entrées (fichier, format, entiers)
  weaknesses:
  - N'utilise pas getopts malgré la lecture obligatoire
  - Parsing manuel avec shift 2 peut provoquer des sorties non contrôlées
  - Pas de trap pour le nettoyage (même sans fichier temporaire)
- notion: file_parsing
  scores:
    connaissance: 0.7
    implementation: 0.8
    debug: 0.6
    explication: 0.5
    design: 0.6
    securite: 0.8
    performance: 0.6
  anti_patterns:
  - jq_slurp_entire_file
  - awk_pipe_to_sort_head
  - no_malformed_line_handling
  strengths:
  - Agrégation en un seul passage awk avec tableaux associatifs
  - Utilisation de jq pour le format JSONL
  - Tri du top endpoints via sort -k2,2nr
  weaknesses:
  - jq -s charge tout le fichier en mémoire (problème pour gros volumes)
  - Pas de gestion des lignes JSON invalides ou malformées
  - Le tri interne à awk fork sort et head à chaque exécution
- notion: bash_scripting_advanced
  scores:
    connaissance: 0.6
    implementation: 0.7
    debug: 0.5
    explication: 0.5
    design: 0.6
    securite: 0.7
    performance: 0.6
  anti_patterns:
  - no_trap_signal_handling
  - missing_shellcheck_ci
  strengths:
  - shellcheck -S warning passe sans erreur
  - set -euo pipefail présent
  weaknesses:
  - Pas de trap pour signaux EXIT/INT/TERM
  - Pas de test automatisé (bats) pour les cas limites
  - Shellcheck validé mais non intégré dans un workflow
calibration:
  overconfidence: true
  underconfidence: false
  notes: L'auto-évaluation revendique tous les livrables validés (équivalence stricte,
    exit codes, shellcheck) mais omet de mentionner l'absence du fichier tests/NOTES.md
    pourtant demandé. De plus, tests/text_ouput_test.txt montre une sortie incohérente
    pour -f text sur un fichier JSONL, ce qui jette un doute sur la vérification réelle
    de l'équivalence. La sur-confiance est modérée car l'ADR reconnaît des difficultés
    et un temps > 1h30.
---
# Rapport d'évaluation LogSentry — Incrément 1

## Scores par dimension

| Dimension | Score (0-1) | Justification |
|---|---|---|
| Connaissance | 0.7 | Bonne maîtrise globale de bash, awk, jq, sort. Mais absence d'utilisation de `getopts` malgré la lecture imposée, et recours à l'IA pour la syntaxe jq avancée. |
| Implementation | 0.8 | Le script principal tourne et respecte les options et exit codes principaux. Quelques faiblesses : pas de gestion des fichiers JSONL invalides, générateur de données avec chemin absolu `/data` cassé. |
| Debug | 0.65 | `set -euo pipefail` présent, validation des entrées correcte. Mais pas de `trap` pour le nettoyage, pas de gestion des lignes malformées, et le cas d'option sans argument peut provoquer une sortie non maîtrisée. |
| Explication | 0.5 | L'ADR est de bonne qualité mais le fichier `tests/NOTES.md` demandé (livrable de lecture) est absent. L'explication orale supposée ne peut être évaluée ici. |
| Design | 0.65 | Fonctions bien découpées, `main "$@"` présent. Cependant l'analyse JSON est un bloc `jq` monolithique difficile à relire, et le parsing manuel des arguments est moins idiomatique que `getopts`. |
| Securite | 0.8 | Quoting systématique, aucun `eval`, pas de fichier temporaire exposé. Le générateur utilise un chemin absolu mais pas de risque d'injection dans le script principal. |
| Performance | 0.6 | Un seul passage `awk` en mode texte, `LC_ALL=C` appliqué. Mais `jq -s` charge tout le fichier en mémoire, et le tri interne à `awk` fork `sort`/`head` à chaque exécution. |

## Analyse de calibration

L'auto-évaluation se dit complète sur tous les points, mais l'absence de `tests/NOTES.md` et la présence d'un test textuel incohérent (`text_ouput_test.txt` sur un JSONL) indiquent une sur-confiance modérée. Les difficultés mentionnées (syntaxe Bash, types jq) montrent une honnêteté partielle.

## Anti-patterns détectés

- **Absence de `getopts`** : le parsing manuel avec `shift` fonctionne mais ne suit pas la notion ciblée `arguments_getopts`.
- **`jq -s` (slurp)** : charge tout le fichier JSONL en mémoire, non scalable.
- **Pas de `trap`** : aucun nettoyage de fichiers temporaires ni gestion des signaux, alors que l'objectif le mentionnait.
- **Chemin absolu `/data`** dans `generate_dummy_logs.sh` : rend le script non portable et casse la génération si on n'est pas à la racine.
- **Tri interne à `awk`** : le `cmd = "sort ... | head ..."` fork des processus pour chaque exécution, alors qu'un tri externe après `awk` serait plus propre.

## Points forts

- Respect des exit codes imposés pour les cas testés (1, 2, 3, 4).
- Découpage fonctionnel clair (`usage`, `parse_args`, `validate_args`, `analyze_text`, `analyze_json`, `main`).
- `set -euo pipefail` et validation des entrées présentes.
- Quoting systématique et aucune injection `eval`.
- Un seul passage `awk` pour l'agrégation en mode texte.

## Points faibles

- Livrable de lecture `tests/NOTES.md` manquant.
- Pas de gestion des lignes malformées ou JSON invalides.
- `analyze_json` en `jq -s` est fragile et difficile à maintenir.
- Générateur de données défectueux (chemin absolu).
- Pas de tests automatisés (bats) ni d'intégration continue shellcheck.

## Recommandations

1. **Revoir le parsing des arguments** : utiliser `getopts` pour les options courtes et une boucle séparée pour les longues, ou au minimum justifier le choix en connaissance de cause.
2. **Ajouter un `trap`** : même sans fichier temporaire, un `trap` de nettoyage est recommandé pour la robustesse et l'objectif `trappage_signaux`.
3. **Remplacer `jq -s`** par un traitement streaming (`jq -c` ou `jq --stream`) pour éviter de charger tout le fichier.
4. **Corriger `generate_dummy_logs.sh`** : utiliser des chemins relatifs cohérents avec l'arborescence (`./data/...`).
5. **Créer `tests/NOTES.md`** avec les explications ShellCheck demandées.
6. **Ajouter des tests unitaires** (bats) pour les cas limites : fichier vide, option sans argument, ligne malformée, N > nb endpoints.
7. **Intégrer shellcheck** dans un hook ou CI pour garantir 0 warning.

## Exercices futurs suggérés

- Écrire un script équivalent en utilisant `getopts` + support long manuel.
- Implémenter un mode streaming pour JSONL avec `jq` sans slurp.
- Ajouter un fichier temporaire avec `mktemp` et `trap` pour illustrer la gestion des signaux.
- Étendre les tests avec `bats` pour couvrir les cas limites.
