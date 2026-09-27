---
date: '2026-09-27'
notions:
- notion: bash_scripting
  scores:
    connaissance: 0.4
    implementation: 0.5
    debug: 0.5
    explication: 0.4
    design: 0.7
    securite: 0.8
    performance: 0.7
  anti_patterns:
  - parsing_manuel_arguments
  - non_conformite_format_sortie
  - absence_validation_ligne
  strengths:
  - decoupage_fonctions
  - utilisation_set_euo_pipefail
  - quoting_systematique
  weaknesses:
  - pas_de_getopts
  - sortie_texte_non_conforme
  - pas_de_gestion_ligne_malformee
- notion: file_parsing
  scores:
    connaissance: 0.4
    implementation: 0.5
    debug: 0.3
    explication: 0.3
    design: 0.6
    securite: 0.7
    performance: 0.5
  anti_patterns:
  - pas_de_grep
  - pas_de_cut_sort_uniq
  - jq_slurp_chargement_complet
  strengths:
  - utilisation_awk_un_seul_passage
  - json_valide_avec_jq
  - pas_d_injection_shell
  weaknesses:
  - non_utilisation_grep
  - non_gestion_entrees_invalides
  - performance_json_mediocre
- notion: bash_scripting_advanced
  scores:
    connaissance: 0.3
    implementation: 0.4
    debug: 0.4
    explication: 0.2
    design: 0.6
    securite: 0.7
    performance: 0.5
  anti_patterns:
  - absence_trap
  - absence_gestion_signaux
  - absence_notes_shellcheck
  strengths:
  - shellcheck_propre
  - code_lisible
  weaknesses:
  - pas_de_trap
  - pas_de_notes_explicatives
  - pas_de_gestion_cas_limites_avancee
calibration:
  overconfidence: true
  underconfidence: false
  notes: L'auto-évaluation qualitative surestime la conformité (getopts, grep, format
    exact) et la robustesse (cas limites). L'étudiant mentionne des points forts mais
    ne démontre pas toutes les exigences.
---
# Rapport d'évaluation LogSentry Incrément 1

## Scores par dimension (moyenne sur les notions)

| Dimension | Score moyen | Commentaire |
|-----------|-------------|-------------|
| Connaissance | 0.37 | Comprend les outils mais ne démontre pas getopts ni grep. |
| Implémentation | 0.47 | Script fonctionnel mais sortie non conforme, exit codes partiels. |
| Debug / Robustesse | 0.40 | Gère les cas de base, ignore lignes malformées et JSONL invalide. |
| Explication | 0.30 | ADR présent mais pas de NOTES.md, explications limitées. |
| Design / Lisibilité | 0.63 | Bon découpage en fonctions, main() clair. |
| Sécurité | 0.73 | Quoting systématique, pas d'eval, pas d'injection. |
| Performance | 0.57 | awk unique et LC_ALL=C, mais jq -s charge tout en mémoire. |

## Analyse de calibration

**Overconfidence détectée** : L'auto-évaluation indique « Bonne aisance », « Respect strict des codes de retour » et « Equivalance stricte des métriques ». Or le code ne respecte pas l'utilisation imposée de `getopts`, n'utilise pas `grep`, et la sortie texte ne correspond pas au format demandé (numérotation absente, espacements différents). De plus, la gestion des cas limites (ligne malformée, entrée JSONL invalide) est absente. L'étudiant surestime sa conformité aux exigences.

## Anti-patterns détectés

- **Parsing manuel des arguments** : la boucle `while` + `case` remplace `getopts`, pourtant l'objectif 1 demandait spécifiquement cette notion.
- **Non-conformité du format de sortie texte** : absence de numérotation des endpoints, espacements non conformes.
- **Absence de validation des lignes d'entrée** : aucun contrôle du nombre de champs ou de la validité JSONL, ce qui peut produire des résultats erronés silencieusement.
- **Jq en mode slurp** : `jq -s` charge tout le fichier en mémoire, ce qui nuit à la performance pour de gros volumes.
- **Absence de grep** : l'objectif 5 exigeait l'utilisation de `grep` et d'expressions régulières pour extraction/validation ; aucun `grep` n'est présent.
- **Pas de cut/sort/uniq** : l'objectif 7 demandait l'utilisation de ces outils pour le top endpoints et le dédoublonnage IP ; tout est fait en awk, ce qui est acceptable mais ne démontre pas la compétence.

## Points forts

- Script structuré avec des fonctions dédiées (`parse_args`, `validate_args`, `analyze_text`, `analyze_json`, `main`).
- Utilisation correcte de `set -euo pipefail` et de `IFS=$'\n\t'`.
- Quoting systématique des variables, aucun `eval`.
- Mode JSON produit un JSON valide avec les clés demandées.
- Un seul passage awk pour le mode texte.
- Shellcheck sans warning (présumé).

## Points faibles

- Non-respect de `getopts` pour le parsing des arguments.
- Sortie texte non conforme au modèle attendu.
- Pas de gestion des lignes malformées (texte ou JSONL).
- Pas de `grep` ni de `cut/sort/uniq`.
- Pas de fichier NOTES.md expliquant les codes ShellCheck.
- Utilisation de `jq -s` au lieu d'un streaming, impact performance.
- Pas de trap ni de gestion de signaux (même si pas de fichier temporaire).

## Recommandations

1. **Lecture ciblée** : Revoir le manuel Bash sur `getopts` et implémenter les options longues avec `getopts` (via astuce `-` ou `getopt` externe) pour valider la notion.
2. **Corriger la sortie texte** : respecter scrupuleusement le format demandé (numérotation, espacements) en utilisant `printf` avec padding.
3. **Ajouter la validation des lignes** : en mode texte, vérifier le nombre de champs avec `NF == 6` ; en mode JSONL, utiliser `jq -e 'type == "object"'` ou équivalent pour rejeter les lignes invalides.
4. **Utiliser grep** : pour la détection des erreurs 5xx ou pour valider le format des lignes avant awk, afin de démontrer la compétence.
5. **Remplacer `jq -s`** : utiliser `jq -c '.'` en streaming avec agrégation, ou passer par un script awk si possible, pour améliorer la performance.
6. **Créer NOTES.md** : expliquer les codes ShellCheck demandés (SC2086, SC2046, SC2181, SC2002, SC2164).
7. **Gérer les signaux** : ajouter un `trap` de nettoyage même si pas de fichier temporaire, pour la robustesse.
8. **Revoir l'auto-évaluation** : être plus objectif sur les écarts entre les exigences et la réalisation.

## Conclusion

Le script est une base fonctionnelle mais ne répond que partiellement aux objectifs pédagogiques. Les notions `bash_scripting_advanced` et `file_parsing` sont à consolider, notamment sur l'utilisation idiomatique des outils imposés. Une itération est nécessaire pour valider l'incrément.
