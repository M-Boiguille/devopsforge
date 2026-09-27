---
date: '2026-09-27'
notions:
- notion: bash_scripting
  scores:
    connaissance: 0.5
    implementation: 0.3
    debug: 0.2
    explication: 0.5
    design: 0.4
    securite: 0.5
    performance: 0.5
  anti_patterns:
  - signal_handling_failure
  strengths:
  - Tentative de gestion des signaux avec trap
  weaknesses:
  - Le SIGTERM sous Docker conduit à un exit 137 au lieu de 143, preuve que le signal
    n'est pas traité correctement en PID 1
- notion: file_parsing
  scores:
    connaissance: 0.6
    implementation: 0.7
    debug: 0.6
    explication: 0.6
    design: 0.6
    securite: 0.5
    performance: 0.5
  anti_patterns: []
  strengths:
  - Mode stdin implémenté et testé (comparaison locale/Docker)
  - Gestion des chemins différenciés (exclusion du champ file)
  weaknesses:
  - Pas de preuve explicite de robustesse sur entrées malformées
- notion: images
  scores:
    connaissance: 0.5
    implementation: 0.5
    debug: 0.4
    explication: 0.4
    design: 0.5
    securite: 0.5
    performance: 0.5
  anti_patterns: []
  strengths:
  - Utilisation d'un Dockerfile multi-stage probable (non documenté en détail)
  weaknesses:
  - Taille d'image non mentionnée, pas de preuve de cache de layers exploité
- notion: containers
  scores:
    connaissance: 0.5
    implementation: 0.4
    debug: 0.3
    explication: 0.4
    design: 0.4
    securite: 0.5
    performance: 0.4
  anti_patterns:
  - missing_healthcheck
  - missing_resource_limits
  strengths:
  - ENTRYPOINT/CMD respecté (implicite)
  - Read-only et non-root mentionnés
  weaknesses:
  - Healthcheck non documenté
  - Resource limits (--memory, --cpus) non démontrés
  - Problème de signalement sous Docker
- notion: best_practices
  scores:
    connaissance: 0.6
    implementation: 0.6
    debug: 0.5
    explication: 0.5
    design: 0.6
    securite: 0.7
    performance: 0.5
  anti_patterns: []
  strengths:
  - Utilisateur non-root, volumes read-only, pas de secrets en dur (supposé)
  weaknesses:
  - Pas de preuve de .dockerignore minimal
  - Base image pas spécifiée précisément
- notion: volumes
  scores:
    connaissance: 0.6
    implementation: 0.7
    debug: 0.6
    explication: 0.5
    design: 0.6
    securite: 0.6
    performance: 0.5
  anti_patterns: []
  strengths:
  - Utilisation de bind mounts en lecture seule
  - Preuve d'immutabilité via --read-only
  weaknesses:
  - Pas de démonstration explicite de l'échec si volume absent
calibration:
  overconfidence: false
  underconfidence: false
  notes: L'auto-évaluation (ADR) documente honnêtement les problèmes rencontrés, notamment
    l'échec du SIGTERM sous Docker (exit 137 au lieu de 143). Aucune sur-confiance
    détectée. Légère sous-confiance possible car les réussites ne sont pas toutes
    mises en avant (par exemple, la conformité aux bonnes pratiques Docker n'est pas
    détaillée). L'étudiant semble avoir une vision réaliste de son travail.
---
# Rapport d'évaluation — LogSentry Incrément 2 : Dockerisation

## Synthèse globale

L'étudiant a réalisé une grande partie du travail demandé : déplacement du projet, mise en place d'un dépôt Git distant local, Dockerisation avec une image non-root et volumes read-only. Cependant, certains points critiques restent non résolus, notamment la gestion des signaux sous Docker (problème de PID 1) et l'absence de preuves documentées pour plusieurs critères (healthcheck, resource limits, taille d'image, .dockerignore).

## Scores par dimension (moyenne des notions)

| Dimension | Score moyen | Commentaire |
|-----------|-------------|-------------|
| Connaissance | 0.55 | Compréhension partielle des concepts, mais des lacunes sur la gestion des signaux en conteneur. |
| Implémentation | 0.52 | Le Dockerfile et les scripts existent, mais des éléments essentiels manquent ou ne sont pas documentés. |
| Debug | 0.43 | Problème de SIGTERM non résolu, pas de preuve de tests de cas limites. |
| Explication | 0.48 | L'ADR est succinct, les notes de lecture ne sont pas fournies. |
| Design | 0.52 | Structure probablement correcte, mais pas de démonstration de lisibilité ou de .dockerignore. |
| Sécurité | 0.57 | Bonnes pratiques partielles (non-root, read-only), mais non exhaustives. |
| Performance | 0.48 | Taille d'image non vérifiée, pas de cache démontré, limites de ressources non testées. |

## Analyse de calibration

L'auto-évaluation est factuelle et reconnaît les échecs (SIGTERM). Pas de sur-confiance, l'étudiant semble conscient de ses lacunes. Une légère sous-confiance pourrait exister car les acquis ne sont pas mis en avant. Globalement, la calibration est bonne.

## Anti-patterns détectés

- **Signal handling failure** : Le script ne gère pas correctement SIGTERM en tant que PID 1, ce qui provoque un arrêt forcé (exit 137) au lieu d'un arrêt propre (exit 143).
- **Missing healthcheck** : Aucune instruction HEALTHCHECK n'est documentée dans le Dockerfile, contrairement à l'exigence.
- **Missing resource limits** : Aucune démonstration de `--memory` ou `--cpus`, ni de raisonnement sur leur valeur.
- **Absence de preuve de .dockerignore** : le fichier n'est pas mentionné, ce qui peut laisser filtrer des secrets ou des fichiers inutiles.
- **Taille d'image non vérifiée** : le critère < 30 MB n'est pas confirmé.

## Points forts

- Utilisation d'un dépôt Git local pour simuler un workflow distant.
- Correction de bugs de parsing (espaces, JSONL).
- Comparaison des sorties locale/Docker avec exclusion intelligente du champ `file`.
- Mise en place d'un utilisateur non-root et de volumes read-only.

## Points faibles

- Échec de la gestion des signaux sous Docker (problème PID 1 non résolu).
- Documentation insuffisante : pas de NOTES.md fourni, pas de détails sur le Dockerfile.
- Manque de preuves pour plusieurs critères (healthcheck, resource limits, taille, .dockerignore).
- Aucune mention du stage de lint dans le Dockerfile, ce qui est un objectif majeur.

## Recommandations

### Lecture ciblée
- **Docker documentation : PID 1 et gestion des signaux** — pour résoudre le problème de SIGTERM.
- **Dockerfile best practices : HEALTHCHECK et resource limits** — pour compléter la configuration.
- **Hadolint** — pour analyser le Dockerfile et détecter les anti-patterns.

### Exercices futurs
- Implémenter un gestionnaire de signaux correct pour le PID 1 (par exemple, utiliser `exec` dans le script ou un init léger).
- Ajouter un HEALTHCHECK conforme et le tester avec `docker inspect`.
- Documenter la taille de l'image et optimiser si nécessaire avec `dive`.
- Fournir un `docker-compose.yml` avec `read_only`, `cap_drop`, `security_opt` pour renforcer la sécurité.
- Tester explicitement les cas limites (volume absent, format bidon, top > endpoints) et noter les codes de sortie.
- Rédiger un NOTES.md complet avec les résultats demandés.

## Conclusion

L'incrément 2 est partiellement réussi : la conteneurisation de base est en place, mais des points critiques (signaux, healthcheck, preuves) restent à finaliser. L'étudiant doit consolider ses connaissances sur la gestion des processus dans les conteneurs et fournir une documentation plus rigoureuse. La note globale se situerait autour de **55-65/100**, nécessitant une consolidation ciblée avant de passer à l'incrément 3.
