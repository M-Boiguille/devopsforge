---
date: '2026-09-27'
notions:
- notion: bash_scripting
  scores:
    connaissance: 0.4
    implementation: 0.7
    debug: 0.7
    explication: 0.2
    design: 0.8
    securite: 0.8
    performance: 0.7
  anti_patterns:
  - manual_option_parsing_instead_of_getopts
  strengths:
  - Bonne structure fonctionnelle avec parse_args, validate_args, analyze_text, analyze_json
    et main
  - set -euo pipefail correctement utilisé
  - Validation des entrées (fichier, format, entiers positifs)
  weaknesses:
  - getopts non utilisé malgré l'objectif explicite
  - Absence du livrable tests/NOTES.md
  - Parsing manuel des options longues sans gestion robuste des arguments manquants
- notion: file_parsing
  scores:
    connaissance: 0.6
    implementation: 0.7
    debug: 0.7
    explication: 0.2
    design: 0.8
    securite: 0.8
    performance: 0.8
  anti_patterns:
  - awk_pipe_to_sort_inside_awk
  strengths:
  - Single-pass awk avec tableaux associatifs et bloc END
  - Utilisation correcte de jq pour le mode JSON
  - Tri du top avec sort -k2,2nr | head, et LC_ALL=C pour la performance
  weaknesses:
  - Pas d'utilisation de grep/cut/sort/uniq direct comme demandé
  - Ordre des IPs en erreur non déterministe (for ip in ip_err sans tri)
  - Le pipe sort à l'intérieur de awk est fonctionnel mais moins lisible qu'un tri
    externe
- notion: bash_scripting_advanced
  scores:
    connaissance: 0.4
    implementation: 0.7
    debug: 0.7
    explication: 0.2
    design: 0.8
    securite: 0.8
    performance: 0.7
  anti_patterns:
  - no_trap_for_signal_handling
  strengths:
  - shellcheck -S warning ne remonte aucun warning
  - Quoting systématique des variables
  weaknesses:
  - Pas de trap de signaux (EXIT/INT/TERM) même si aucun fichier temporaire n'est
    utilisé
  - Aucune gestion explicite des interruptions
calibration:
  overconfidence: true
  underconfidence: false
  notes: L'auto-évaluation est globalement confiante mais omet des livrables (tests/NOTES.md
    absent) et présente un test de sortie texte sur un fichier JSONL incohérent (text_ouput_test.txt
    montre des métriques fausses). Le choix d'écarter getopts n'est pas suffisamment
    justifié par rapport à l'objectif pédagogique. L'étudiant admet une difficulté
    avec jq, ce qui nuance la sous-confiance, mais l'ensemble reflète une surestimation
    de la conformité.
---
# Rapport d'évaluation — LogSentry Incrément 1

## Scores par dimension (moyenne sur les notions)

| Dimension | Score | Justification |
|-----------|-------|---------------|
| Connaissance | 0.47 | getopts non utilisé, pas de démonstration de grep/cut/sort, mais awk et jq maîtrisés. |
| Implementation | 0.70 | Le script tourne et respecte les exit codes imposés, mais des cas limites de parsing d'options ne sont pas gérés. |
| Debug / robustesse | 0.70 | set -euo pipefail et validation présents, mais pas de trap ni de gestion des interruptions. |
| Explication | 0.20 | Le fichier tests/NOTES.md est absent, l'auto-évaluation ne contient pas les notes demandées. |
| Design / lisibilité | 0.80 | Bon découpage en fonctions, main() clair, nommage correct. |
| Sécurité | 0.80 | Quoting systématique, aucun eval, pas d'injection possible. |
| Performance | 0.73 | Un seul passage awk, LC_ALL=C, mais jq -s charge tout en mémoire. |

## Analyse de calibration

**Overconfidence : Oui**  
L'auto-évaluation affirme une "équivalence stricte des métriques" et une conformité globale, mais omet le livrable NOTES.md et fournit un test de sortie texte incohérent (exécution du mode text sur un fichier JSONL). Le choix d'écarter getopts est présenté comme une décision d'architecture, sans reconnaissance du fait que l'objectif pédagogique demandait explicitement getopts.

**Underconfidence : Non**  
L'étudiant admet une difficulté avec jq et une reprise en main, mais cela ne suffit pas à compenser les manquements détectés.

## Anti-patterns détectés

1. **Parsing manuel des options au lieu de getopts** : L'objectif `arguments_getopts` n'est pas démontré. La boucle while/case/shift est fonctionnelle mais ne satisfait pas la notion ciblée.
2. **Pipe sort à l'intérieur de awk** : Le tri du top est effectué via un pipe interne dans awk (`print ... | cmd`). Cela fonctionne mais complique la lisibilité et le debug.
3. **Absence de trap de signaux** : Même sans fichier temporaire, un trap EXIT/INT/TERM aurait démontré la maîtrise de la gestion des interruptions.
4. **Ordre non déterministe des IPs en erreur** : La boucle `for (ip in ip_err)` produit un ordre aléatoire, ce qui nuit à la reproductibilité.

## Points forts

- Structure fonctionnelle claire (parse_args, validate_args, analyze_text, analyze_json, main).
- Respect des contraintes de base : un seul awk, un seul passage, LC_ALL=C pour sort.
- Validation des entrées (fichier, format, entiers) et exit codes distincts.
- Quoting systématique et aucune utilisation d'eval.
- shellcheck sans warning.

## Points faibles

- Non-utilisation de getopts malgré l'objectif explicite.
- Absence du livrable tests/NOTES.md.
- Le mode text sur un fichier JSONL produit des résultats faux (cf. test fourni), ce qui montre que la distinction format d'entrée n'est pas correctement testée.
- Pas de gestion des signaux ni de trap.
- L'ordre des IPs en erreur n'est pas trié.
- Le jq -s charge tout le fichier en mémoire, ce qui peut poser problème pour de gros logs.

## Recommandations

1. **Revoir getopts** : Implémenter le parsing avec getopts pour les options courtes, en combinant éventuellement avec une boucle pour les options longues (ou utiliser getopt externe). Justifier le choix au débrief.
2. **Rédiger tests/NOTES.md** : Y inclure les 5 codes ShellCheck demandés et leur explication.
3. **Tester les formats séparément** : Vérifier que `-f text` est utilisé sur `access.log` et `-f json` sur `access.jsonl`, et que les métriques correspondent.
4. **Ajouter un trap** : Même minimal (`trap 'echo Interrupted >&2; exit 130' INT TERM`) pour démontrer la gestion des signaux.
5. **Trier les IPs en erreur** : Utiliser `asort` en awk ou un tri externe pour un ordre déterministe.
6. **Éviter le pipe interne awk** : Sortir les données du top dans un fichier temporaire ou utiliser un pipe externe après l'exécution awk.
7. **Considérer une approche streaming pour jq** : Pour les gros fichiers, éviter `-s` et traiter ligne par ligne si possible.

## Conclusion

Le script est fonctionnel et respecte les contraintes de base, mais ne démontre pas toutes les notions ciblées, notamment `arguments_getopts` et `explication`. La robustesse est bonne mais perfectible. Avec les corrections ci-dessus, l'exercice pourrait être validé.
