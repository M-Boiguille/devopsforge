1. **`set -e` et `pipefail`**

`set -e` arrête le script lorsqu'une commande échoue, mais dans un pipeline :

```bash
cmd1 | cmd2 | cmd3
```

le statut retourné est normalement celui de **`cmd3`**.

Donc si `cmd1` échoue mais `cmd3` réussit, le pipeline peut être considéré comme réussi.

`set -o pipefail` fait retourner au pipeline le code d'erreur de la commande ayant échoué.

```bash
set -euo pipefail
```

→ `-e` : arrêt sur erreur
→ `-u` : variable non définie = erreur
→ `pipefail` : erreur d'une commande du pipeline = pipeline en erreur

---

1. **Pourquoi `awk` peut être plus rapide**

Avec :

```bash
grep ... | cut ... | sort | uniq
```

on enchaîne plusieurs processus et plusieurs traitements des données. `sort` nécessite en plus un tri global, donc typiquement `O(n log n)`.

Avec un seul `awk` :

```bash
awk '{ count[$X]++ } END { ... }'
```

on parcourt les 1 M lignes **une seule fois**, avec une agrégation en mémoire.

Le traitement principal est donc proche de :

```text
O(n)
```

au lieu de multiplier les passages et de terminer par un tri global.

**Nuance importante :** si on doit réellement produire un top trié, il faudra quand même trier les résultats agrégés. L'avantage de l'`awk` est surtout d'éviter de transporter et retraiter les 1 M lignes plusieurs fois.

---

1. **`/api/foo; rm -rf /`**

Le danger apparaît si une donnée provenant du log est réinjectée dans le shell comme du code, par exemple avec :

```bash
eval "$endpoint"
```

ou une construction équivalente.

Dans LogSentry, l'endpoint est traité comme **une donnée**, pas comme une commande :

```bash
awk '{ endpoints[$5]++ }'
```

et les variables shell sont systématiquement quotées :

```bash
"$endpoint"
```

Il n'y a pas de `eval`.

Donc :

```text
/api/foo; rm -rf /
```

reste une simple chaîne de caractères.

Le point important est que **le `;` n'est dangereux que lorsqu'il est interprété par un shell**.

---

1. **Ce qui manquerait pour la production**

Le script fonctionne localement, mais il lui manque principalement son **environnement d'exécution reproductible** :

* éventuellement `read-only` ;
* gestion propre de `stdin` et des fichiers montés ;
* tests exécutables dans le conteneur ;
* build reproductible et idéalement automatisé par CI.

---

## Increment 2 — Docker

### Étape 1 — Lecture guidée

**exec form vs shell form :**
- Shell form : `ENTRYPOINT logsentry.sh` → exécuté via `/bin/sh -c`, le shell devient PID 1, les signaux sont propagés au shell mais pas forcément au process enfant.
- Exec form : `ENTRYPOINT ["/app/bin/logsentry.sh"]` → le script devient directement PID 1, reçoit SIGTERM/SIGINT directement, permet un arrêt propre et rapide.

**PID 1 et propagation SIGTERM :**
- En Docker, le process avec PID 1 reçoit les signaux système (SIGTERM de `docker stop`). Si PID 1 est un shell (shell form), il transmet mal ou pas les signaux aux enfants. Avec exec form + trap TERM dans le script, `docker stop` déclenche le trap → cleanup → exit 143 propre.

**Pourquoi COPY avant RUN (cache de layers) :**
- Docker cache chaque layer. Si `COPY` est après `RUN apk install`, toute modification du code source invalide le cache et force la réinstallation des dépendances. En copiant d'abord le code source, les layers d'installation (lent, stable) sont seules invalidées quand les dépendances changent.

**Pourquoi `--chown` sur `COPY` plutôt qu'un `RUN chown` :**
- `COPY --chown=sentry:sentry` fait le changement de propriétaire dans une seule layer, atomique. Un `RUN chown` créerait une layer intermédiaire où les fichiers sont root avant le chown, et cette layer intermédiaire persiste dans l'historique (les fichiers root restent accessibles en inspectant les layers). `--chown` sur COPY est aussi plus lisible.

### Étape 5 — Résultats des tests

| Test | Commande | Attendu | Obtenu |
|------|----------|---------|--------|
| Non-root effectif | `docker run --rm --entrypoint id logsentry:0.2.0` | `uid=10001(sentry)` | `uid=10001(sentry)` |
| Volume absent | `docker run --rm logsentry:0.2.0 -i /nope.log` | exit **2** | exit **2** |
| Format bidon | `docker run --rm logsentry:0.2.0 -f xml` | exit **3** | exit **3** |
| Stdin vs fichier | `cat data/access.log \| docker run --rm -i logsentry:0.2.0 -f text -i -` | mêmes chiffres | 500 req, 121 erreurs, 595 ms — identiques |
| Top > endpoints | `... -n 999` | pas de crash, moins de lignes | clampé automatiquement |
| Taille image | `docker images logsentry:0.2.0` | < 30 MB | **11.8 MB** |
