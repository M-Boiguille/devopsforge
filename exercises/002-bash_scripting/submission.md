# ADR — LogSentry - Incrément 2 : Dockerisation

## Décisions

* Déplacement de `logsentry` dans `fil-rouge/logsentry/` afin d'établir un projet fil rouge unique pour les prochains incréments.
* Création de `.repo_git_dummy/` comme **bare repository local** utilisé comme `origin`, afin de travailler avec un workflow Git proche d'un dépôt distant sans dépendance externe.
* Le `top_n` effectif est limité au nombre réel d'endpoints : `top_n = min(top_n, endpoints_count)`.
* Correction du découpage des arguments pour gérer correctement les espaces.
* Correction du format JSONL : `duration_ms` est explicitement sérialisé comme chaîne (`"806ms"`).
* Lors de la comparaison des sorties locale/Docker, le champ `file` est exclu du diff : son chemin dépend de l'environnement d'exécution et ne constitue pas une différence fonctionnelle.

## Problèmes rencontrés

* Le déplacement du projet nécessitait de conserver son historique Git tout en changeant sa localisation.
* Le dépôt de travail seul ne permettait pas de reproduire un workflow avec un remote : un bare repository local a donc été utilisé.
* Les chemins de fichiers diffèrent entre l'exécution locale et le conteneur, rendant un diff JSON brut incorrect.
* Le test de `SIGTERM` dans Docker a révélé un comportement différent de l'exécution locale : le processus local termine correctement sur `SIGTERM`, tandis que le test Docker atteint le timeout et termine en `137`. Le diagnostic de ce comportement reste à finaliser.

## Parcours technique

```text
Bash / Linux
    ↓
Parsing et traitement de logs
    ↓
Git / bare repository
    ↓
Docker / conteneurisation
    ↓
stdin, volumes, non-root, read-only
    ↓
signaux / PID 1
    ↓
Kubernetes
    ↓
Terraform / CI-CD
```

L'objectif du fil rouge est de faire évoluer **le même outil** à travers cette chaîne plutôt que d'enchaîner des exercices indépendants.
