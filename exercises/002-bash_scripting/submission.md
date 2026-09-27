# ADR — LogSentry - Incrément 2 : Dockerisation

## Décisions

* Déplacement de `logsentry` dans `fil-rouge/logsentry/` afin d'établir un projet fil rouge unique pour les prochains incréments.
* Création de `.repo_git_dummy/` comme **bare repository local** utilisé comme `origin`, afin de travailler avec un workflow Git proche d'un dépôt distant sans dépendance externe.
* Le `top_n` effectif est limité au nombre réel d'endpoints : `top_n = min(top_n, endpoints_count)`.
* Correction du découpage des arguments pour gérer correctement les espaces.
* Correction du format JSONL : `duration_ms` est explicitement sérialisé comme chaîne (`"806ms"`).
* Lors de la comparaison des sorties locale/Docker, le champ `file` est exclu du diff : son chemin dépend de l'environnement d'exécution et ne constitue pas une différence fonctionnelle.
* Absence de `docker-compose.yml` justifiée : CLI one-shot sans orchestration multi-services nécessaire à ce stade.

## Problèmes rencontrés

* Le déplacement du projet nécessitait de conserver son historique Git tout en changeant sa localisation.
* Le dépôt de travail seul ne permettait pas de reproduire un workflow avec un remote : un bare repository local a donc été utilisé.
* Les chemins de fichiers diffèrent entre l'exécution locale et le conteneur, rendant un diff JSON brut incorrect.
* Le test de `SIGTERM` dans Docker a révélé un comportement différent de l'exécution locale : le processus local termine correctement sur `SIGTERM`, tandis que le test Docker atteint le timeout et termine en `137`. Le diagnostic de ce comportement reste à finaliser.
* Le script est un CLI one-shot (traite et sort immédiatement) : le cas `docker stop` n'est pas applicable en conditions réelles car le process a déjà terminé avant tout signal. Le trap TERM (`logsentry.sh:10`) est en place pour les cas où le process serait bloqué sur un fichier volumineux ou un pipe lent.

## Dockerfile (résumé)

```dockerfile
FROM koalaman/shellcheck-alpine
WORKDIR /app
COPY logsentry/ .
RUN shellcheck bin/logsentry.sh

FROM alpine:3.20
WORKDIR /app
COPY --chown=sentry:sentry bin/ bin/
RUN apk update && apk add --no-cache bash jq gawk && rm -rf /var/cache/apk/*
RUN adduser -D -u 10001 sentry
USER sentry
ENTRYPOINT [ "/app/bin/logsentry.sh" ]
HEALTHCHECK --interval=30s --timeout=3s --start-period=2s --retries=3 CMD [ "/app/bin/logsentry.sh", "--help" ]
CMD [ "--help" ]
```

## Preuves de tests (exécutés le 28/09/2026)

| Test | Commande | Résultat |
|---|---|---|
| Non-root effectif | `docker run --rm --entrypoint id logsentry:0.2.0` | `uid=10001(sentry)` |
| Volume absent | `docker run --rm logsentry:0.2.0 -i /nope.log` | exit **2** |
| Format bidon | `docker run --rm logsentry:0.2.0 -f xml -i /etc/hostname` | exit **3** |
| Stdin vs fichier | `docker run --rm -i logsentry:0.2.0 -f text -i - < data/access.log` | mêmes chiffres (500 req, 121 erreurs, 595 ms, top identique) |
| Top > endpoints | `docker run --rm -v data:/data:ro logsentry:0.2.0 -i /data/access.log -n 999` | clampé, pas de crash |
| Taille image | `docker images logsentry:0.2.0` | **11.8 MB** (< 30 MB) |

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
