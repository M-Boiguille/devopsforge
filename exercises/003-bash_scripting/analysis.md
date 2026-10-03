---
date: '2026-10-03'
notions:
- notion: bash_scripting
  scores:
    connaissance: 0.6
    implementation: 0.5
    debug: 0.5
    explication: 0.3
    design: 0.6
    securite: 0.5
    performance: 0.9
  anti_patterns:
  - unused_variable
  - no_input_validation
  - no_format_validation
  - stdout_pollution
  - shellcheck_warnings
  strengths:
  - Correction du piège du sous-shell (pipe vers while)
  - Utilisation de set -euo pipefail
  weaknesses:
  - Validation du fichier d'entrée absente
  - Message de cleanup sur stdout
- notion: file_parsing
  scores:
    connaissance: 0.6
    implementation: 0.5
    debug: 0.5
    explication: 0.3
    design: 0.6
    securite: 0.5
    performance: 0.9
  anti_patterns:
  - unused_variable
  - no_input_validation
  - no_format_validation
  - stdout_pollution
  - shellcheck_warnings
  strengths:
  - 'Suppression de mapfile : lecture ligne par ligne'
  - Extraction du champ endpoint sans awk externe
  weaknesses:
  - Aucune vérification de format du flux d'entrée
  - Tableau associatif ENDPOINTS non exploité
- notion: process_management
  scores:
    connaissance: 0.6
    implementation: 0.5
    debug: 0.5
    explication: 0.3
    design: 0.6
    securite: 0.5
    performance: 0.9
  anti_patterns:
  - unused_variable
  - no_input_validation
  - no_format_validation
  - stdout_pollution
  - shellcheck_warnings
  strengths:
  - Ajout d'un trap TERM avec sortie code 143
  - Gestion de la réception du signal pour docker stop
  weaknesses:
  - Le cleanup s'exécute aussi sur EXIT et pollue stdout
  - Pas de vérification que le signal est bien reçu pendant getopts
- notion: debugging_methodology
  scores:
    connaissance: 0.6
    implementation: 0.5
    debug: 0.5
    explication: 0.3
    design: 0.6
    securite: 0.5
    performance: 0.9
  anti_patterns:
  - unused_variable
  - no_input_validation
  - no_format_validation
  - stdout_pollution
  - shellcheck_warnings
  strengths:
  - Identification du problème de sous-shell
  - Utilisation de tests T1-T6 pour reproduire les symptômes
  weaknesses:
  - Absence de NOTES.md conforme (5 lignes, méthode RIHV)
  - 'Diagnostic incomplet : bugs de validation non traités'
calibration:
  overconfidence: true
  underconfidence: false
  notes: L'auto-évaluation affirme que tous les contrats sont remplis, mais le script
    final ne valide pas les fichiers inexistants (exit 2 attendu), ni les formats
    inconnus (exit 3 attendu), et le message de cleanup pollue stdout. L'apprenant
    surestime la complétude de sa solution.
---
# Rapport LogSentry Incrément 3

## Scores par dimension
- Connaissance : 0.6/1
- Implémentation : 0.5/1
- Debug : 0.5/1
- Explication : 0.3/1
- Design : 0.6/1
- Sécurité : 0.5/1
- Performance : 0.9/1

**Total pondéré : ~52% (0.52)** — en dessous du seuil de 60, consolidation ciblée requise.

## Calibration
Overconfidence : oui. L'auto-évaluation décrit des corrections comme complètes alors que des contrats essentiels échouent (fichier inexistant, format inconnu, stdout pollué). Aucune sous-confiance détectée.

## Anti-patterns détectés
- Variable TOP_N inutilisée (SC2034)
- Absence de validation du fichier d'entrée
- Absence de validation du format de sortie
- Message de cleanup écrit sur stdout
- Warnings ShellCheck dans tests.sh (SC2027, SC2086)
- Pas de limites de ressources explicites dans Dockerfile

## Points forts
- Suppression de `mapfile` : traitement ligne par ligne en mémoire constante.
- Correction du piège du sous-shell : boucle `while` dans le processus principal.
- Suppression des appels `awk` par ligne : performance améliorée.
- Ajout du trap TERM pour une sortie rapide avec code 143.
- Utilisation de `set -euo pipefail`.

## Points faibles
- `set -e` seul ne garantit pas un exit code 2 pour un fichier invalide (nécessite une vérification explicite).
- Aucune validation du format `FORMAT` : `-f xml` sort du texte sans erreur.
- Le message `cleanup: terminaison propre` est envoyé sur stdout, ce qui casse `jq` en mode JSON.
- `TOP_N` est assigné mais jamais utilisé, ce qui indique une fonctionnalité non implémentée.
- Absence de `tests/NOTES.md` conforme (5 lignes max, une ligne par bug) ; l'explication fournie est longue et jargonante.

## Recommandations
1. Ajouter une vérification d'existence et de lisibilité du fichier d'entrée, avec `exit 2`.
2. Valider `FORMAT` contre une liste (`text`, `json`) et sortir avec `exit 3` sinon.
3. Rediriger le message de cleanup vers stderr (`>&2`).
4. Supprimer la variable `TOP_N` si non utilisée ou implémenter le top endpoints.
5. Corriger les warnings ShellCheck dans `tests.sh` (quotes autour de `$IMAGE`).
6. Rédiger un `tests/NOTES.md` respectant la consigne (5 lignes maximum, une ligne par bug, avec ses mots).
7. Ajouter éventuellement des limites de ressources Docker (`--memory`, `--cpus`) lors des tests de performance.
