---
date: '2026-09-27'
notions:
- notion: bash_scripting
  scores:
    connaissance: 0.7
    implementation: 0.6
    debug: 0.7
    explication: 0.4
    design: 0.8
    securite: 0.8
    performance: 0.8
  anti_patterns:
  - manual_arg_parsing_instead_of_getopts
  - missing_required_documentation
  strengths:
  - Bon découpage fonctionnel avec parse_args, validate_args, analyze_text, analyze_json
    et main.
  - Usage correct de set -euo pipefail et validation stricte des entrées avec codes
    de sortie distincts.
  weaknesses:
  - N'utilise pas getopts malgré l'objectif pédagogique ; l'argumentaire est recevable
    mais s'écarte de la consigne.
  - Pas de trap de nettoyage ni de gestion des signaux, même sans fichier temporaire,
    ce qui est attendu dans la notion.
- notion: file_parsing
  scores:
    connaissance: 0.8
    implementation: 0.6
    debug: 0.6
    explication: 0.4
    design: 0.7
    securite: 0.8
    performance: 0.8
  anti_patterns:
  - nondeterministic_output_order
  - format_mismatch
  strengths:
  - Awk en un seul passage avec tableaux associatifs, END et pipe interne vers sort.
  - Utilisation avancée de jq (slurp, group_by, sort_by, halt_error) pour le mode
    JSON.
  - LC_ALL=C appliqué pour les tris.
  weaknesses:
  - 'La sortie texte ne respecte pas exactement le format demandé : numérotation manquante,
    espacement divergent, ordre des IP non déterministe.'
  - Le fichier tests/text_ouput_test.txt est incohérent avec le comportement attendu
    (résultat d'un mauvais usage), ce qui traduit un manque de tests de non-régression.
- notion: bash_scripting_advanced
  scores:
    connaissance: 0.5
    implementation: 0.5
    debug: 0.5
    explication: 0.3
    design: 0.5
    securite: 0.7
    performance: 0.7
  anti_patterns:
  - missing_trap_cleanup
  - no_signal_handling
  strengths:
  - Shellcheck sans warning confirmé.
  - Pas de fichier temporaire donc pas de risque de résidu, mais l'absence de trap
    est non conforme à l'objectif.
  weaknesses:
  - Aucun trap EXIT/INT/TERM n'est mis en place, même pour un éventuel nettoyage futur.
  - Pas de documentation des codes shellcheck comme demandé dans tests/NOTES.md.
calibration:
  overconfidence: true
  underconfidence: false
  notes: 'Auto-évaluation très optimiste : tous les critères de réussite sont cochés
    alors que la sortie texte ne respecte pas le format exact (numérotation absente,
    espacements différents), que tests/NOTES.md n''est pas fourni, et que le script
    auxiliaire a un bug de chemin absolu. L''étudiant reconnaît néanmoins ses difficultés
    de reprise en main et l''aide de l''IA pour jq, ce qui atténue la surconfiance
    globale.'
---
# Rapport d'évaluation LogSentry — Incrément 1

## Scores par dimension

| Dimension | Score | Justification |
|-----------|-------|---------------|
| Connaissance | 0.65 | Bon usage d'awk, jq et sort. Le choix de ne pas utiliser getopts est défendable mais s'écarte de l'objectif pédagogique. |
| Implémentation | 0.60 | Le script tourne et les codes de sortie sont probablement corrects, mais la sortie texte ne correspond pas au format exact exigé (numérotation manquante, espaces, ordre des IP non stable). |
| Debug | 0.60 | set -euo pipefail et validation des entrées sont présents. Manque de gestion explicite des lignes malformées et de trap de nettoyage. |
| Explication | 0.35 | Aucun tests/NOTES.md fourni malgré la consigne. L'ADR est présent mais ne remplace pas le livrable demandé. |
| Design | 0.70 | Bon découpage en fonctions et séparation des responsabilités. Améliorable sur la gestion des signaux et l'utilisation de getopts. |
| Sécurité | 0.75 | Quoting systématique, pas d'eval, pas de secret hardcodé. Le script auxiliaire contient un chemin absolu dangereux (/data/). |
| Performance | 0.80 | Un seul passage awk, LC_ALL=C, pas de fork inutile. jq lit tout en mémoire (slurp), ce qui est acceptable pour 500 lignes mais à surveiller. |

## Analyse de calibration

Overconfidence détectée : l'auto-évaluation coche tous les critères de réussite alors que plusieurs ne sont pas atteints (format exact, NOTES.md, absence de trap). L'étudiant fait preuve de lucidité sur le temps passé et l'aide de l'IA, mais sous-estime l'impact des écarts de forme.

## Anti-patterns détectés

1. **manual_arg_parsing_instead_of_getopts** : boucle while/case au lieu du builtin getopts, malgré l'objectif explicite.
2. **hardcoded_absolute_path** : dans generate_dummy_logs.sh, l'écriture se fait vers /data/ au lieu d'un chemin relatif, ce qui casse le script.
3. **missing_required_documentation** : tests/NOTES.md absent.
4. **missing_trap_cleanup** : aucun trap mis en place, contrairement à l'objectif de trappage des signaux.
5. **nondeterministic_output_order** : l'ordre des IP dans le rapport texte dépend de l'implémentation de awk.
6. **format_mismatch** : la sortie texte ne respecte pas le format imposé.

## Points forts

- Architecture claire avec main, parse_args, validate_args, analyze_text, analyze_json.
- Single-pass awk pour le mode texte, conforme à la contrainte.
- Mode JSON valide et composable avec jq.
- Quoting correct et pas d'eval.

## Points faibles

- Format de sortie texte non conforme (numérotation absente, espacements).
- Absence de tests/NOTES.md et de tests automatisés (bats).
- Script auxiliaire défectueux.
- Pas de gestion des signaux ni trap.
- Utilisation de jq --slurp charge tout le fichier en mémoire, risque sur de gros volumes.

## Recommandations

1. **Corriger immédiatement** le format de sortie texte pour respecter l'exemple : ajouter la numérotation et aligner les libellés.
2. **Rédiger tests/NOTES.md** avec les 5 codes shellcheck demandés.
3. **Revoir la gestion des options** : soit utiliser getopts pour les options courtes et une extension pour les longues, soit justifier plus solidement le choix manuel.
4. **Ajouter un trap** (EXIT, INT, TERM) même sans fichier temporaire, pour se préparer aux incréments futurs (Docker, etc.).
5. **Corriger generate_dummy_logs.sh** en utilisant des chemins relatifs et en ajoutant des garde-fous.
6. **Envisager un streaming jq** (jq -n) pour les gros fichiers JSONL afin d'éviter le slurp intégral.
7. **Mettre en place des tests de non-régression** (par exemple bats) couvrant les cas limites et les formats.
