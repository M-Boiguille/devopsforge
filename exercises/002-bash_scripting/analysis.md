---
date: '2026-09-27'
notions:
- notion: bash_scripting
  scores:
    connaissance: 0.6
    implementation: 0.4
    debug: 0.4
    explication: 0.7
    design: 0.5
    securite: 0.5
    performance: 0.5
  anti_patterns:
  - ineffective_signal_handling
  - blocking_read_without_timeout
  strengths:
  - trap TERM/INT/EXIT mis en place
  - documentation du problème dans l'ADR
  weaknesses:
  - SIGTERM ne provoque pas l'arrêt propre (timeout 137 au lieu de 143)
  - lecture stdin bloquante non interrompue par les signaux
- notion: file_parsing
  scores:
    connaissance: 0.8
    implementation: 0.9
    debug: 0.8
    explication: 0.7
    design: 0.8
    securite: 0.7
    performance: 0.8
  anti_patterns: []
  strengths:
  - stdin == fichier prouvé (mêmes chiffres)
  - gestion du top_n clampé
  weaknesses:
  - pas de preuve explicite du test JSON streaming
- notion: images
  scores:
    connaissance: 0.7
    implementation: 0.8
    debug: 0.5
    explication: 0.6
    design: 0.6
    securite: 0.7
    performance: 0.6
  anti_patterns:
  - unoptimized_layer_order
  - unnecessary_package
  - apk_update_redundant
  - missing_labels
  strengths:
  - multi-stage réel avec stage lint
  - image finale < 30 MB (11.8 MB)
  weaknesses:
  - COPY avant RUN apk add invalide le cache des dépendances
  - installation de bash non justifiée
  - apk update superflu avec --no-cache
- notion: containers
  scores:
    connaissance: 0.7
    implementation: 0.7
    debug: 0.4
    explication: 0.4
    design: 0.7
    securite: 0.7
    performance: 0.4
  anti_patterns:
  - missing_resource_limits_documentation
  - no_resource_limit_test
  strengths:
  - ENTRYPOINT exec form correct
  - CMD par défaut --help
  - HEALTHCHECK présent
  weaknesses:
  - limites --memory et --cpus non documentées ni testées
  - pas de preuve de raisonnement sur les ressources
- notion: best_practices
  scores:
    connaissance: 0.9
    implementation: 0.9
    debug: 0.8
    explication: 0.7
    design: 0.9
    securite: 0.95
    performance: 0.9
  anti_patterns:
  - missing_dockerignore_evidence
  strengths:
  - utilisateur non-root uid 10001 effectif
  - COPY --chown au lieu de RUN chown
  - image minimale alpine, aucun secret détecté
  weaknesses:
  - preuve de .dockerignore non fournie
- notion: volumes
  scores:
    connaissance: 0.85
    implementation: 0.9
    debug: 0.8
    explication: 0.7
    design: 0.85
    securite: 0.9
    performance: 0.8
  anti_patterns: []
  strengths:
  - montage en lecture seule (:ro) fonctionnel
  - test --read-only passé
  - gestion du volume absent (exit 2)
  weaknesses: []
calibration:
  overconfidence: false
  underconfidence: false
  notes: L'auto-évaluation fournie est factuelle et honnête. L'étudiant reconnaît
    l'échec du test SIGTERM et documente les problèmes sans les masquer. Aucune surconfiance
    détectée. Cependant, plusieurs preuves exigées par l'énoncé ne sont pas fournies
    (test JSON validé, test avec limites mémoire/CPU, test de cache de build), ce
    qui pourrait indiquer une légère sous-déclaration. Globalement, calibration neutre.
---
# Rapport d'évaluation — LogSentry Incrément 2

## Scores globaux par dimension (moyenne sur les notions)

- Connaissance : 0.76
- Implémentation : 0.78
- Debug : 0.62
- Explication : 0.64
- Design : 0.74
- Sécurité : 0.79
- Performance : 0.67

## Analyse de calibration

L'auto-évaluation fournie est factuelle et honnête : elle reconnaît l'échec du test SIGTERM (timeout 137) et documente les problèmes rencontrés sans chercher à les masquer. Aucune surconfiance détectée ; l'étudiant ne revendique pas de succès non démontré. Cependant, certaines preuves demandées par l'énoncé ne sont pas fournies (test JSON validé, test avec limites mémoire/CPU, test de cache de build), ce qui suggère une légère sous-déclaration ou omission. Globalement, la calibration est neutre.

## Anti-patterns détectés

| Notion | Anti-pattern |
|---|---|
| bash_scripting | Gestion des signaux inefficace (SIGTERM ne termine pas le processus) |
| images | Ordre des couches non optimisé pour le cache (COPY avant installation des dépendances) |
| images | Installation de bash sans justification explicite |
| containers | Absence de documentation et de test des limites de ressources (--memory, --cpus) |
| best_practices | Preuve de .dockerignore non fournie |

## Points forts

- Image finale très petite (11.8 MB), respectant largement le seuil de 30 MB.
- Utilisateur non-root `sentry` avec uid 10001 effectif, confirmé.
- Multi-stage réel : le stage lint exécute shellcheck et fait échouer le build en cas de warning.
- ENTRYPOINT en exec form et CMD par défaut corrects ; HEALTHCHECK présent.
- Montage de volume en lecture seule (`:ro`) et test du mode `--read-only` fonctionnels.
- Gestion du stdin équivalente au mode fichier (chiffres identiques).
- Robustesse partielle : volume absent (exit 2), format invalide (exit 3), top_n > endpoints clampé.

## Points faibles

- **Échec du test SIGTERM** : le conteneur ne s'arrête pas proprement en moins de 2 s ; exit 137 au lieu de 143. Le trap est présent mais ne fonctionne pas en situation de blocage sur lecture stdin.
- **Cache de build sous-optimal** : l'ordre `COPY bin/` puis `RUN apk add` invalide le cache des dépendances à chaque modification du script.
- **Justification manquante pour bash** : l'énoncé demandait de justifier l'installation de bash ; aucune justification fournie.
- **Limites de ressources non documentées/testées** : l'énoncé exigeait de raisonner et documenter `--memory` et `--cpus`.
- **Preuves incomplètes** : pas de test JSON validé par `jq`, pas de test de build avec warning shellcheck volontaire, pas de test de cache de build, pas de test avec `--memory=64m`.

## Recommandations

1. **Résoudre le problème de signal** : investiguer pourquoi le trap SIGTERM ne fonctionne pas lorsque le script est bloqué sur `read`. Utiliser `read -t` ou `trap` avec gestion d'interruption, ou modifier l'ENTRYPOINT pour utiliser `exec` ou un wrapper qui gère les signaux.
2. **Optimiser l'ordre des couches** : placer l'installation des paquets avant la copie du code (`RUN apk add ...` puis `COPY --chown ...`), ou copier uniquement un fichier de dépendances factice avant.
3. **Justifier ou supprimer bash** : si le script nécessite bash, l'écrire en commentaire dans le Dockerfile ; sinon, tenter de le rendre compatible `sh` pour réduire la surface.
4. **Documenter et tester les limites** : exécuter `docker run --memory=64m --cpus=0.25` sur le fichier de log et noter le comportement ; expliquer le choix des limites.
5. **Compléter les preuves manquantes** : fournir le test JSON, le test de build avec échec volontaire de lint, et le test de cache de build (mesurer le temps du second build).
6. **Vérifier le `.dockerignore`** : s'assurer qu'il exclut bien `data/`, `.git/`, `tests/*.tmp`, `*.md`, `.gitignore` et le documenter.
