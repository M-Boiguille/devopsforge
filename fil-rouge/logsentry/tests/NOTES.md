## LOGSENTRY - NOTES.md

## Increment 1

### Notes ShellCheck — Anti-patterns fréquents

#### ShellCheck

* **SC2086 / SC2046** → toujours quoter : `"$var"`, `"$(cmd)"`.
* **SC2181** → tester directement : `if cmd; then`.
* **SC2002** → éviter `cat file | ...` → `... file`.
* **SC2164** → `cd dir || exit 1`.

#### Bash robuste

```bash
set -euo pipefail
```

* `-e` : stop sur erreur
* `-u` : variable non définie = erreur
* `pipefail` : erreur dans un pipeline = erreur

#### `awk`

`awk` permet une agrégation en **O(n)** en un seul passage, contrairement à plusieurs commandes + tri sur l'ensemble des données.
Si un tri final est nécessaire, il reste à faire sur les résultats agrégés.

#### Sécurité

`/api/foo; rm -rf /` reste une **donnée** tant qu'elle n'est pas passée à `eval` ou exécutée par un shell.
Le quoting (`"$var"`) évite également les problèmes de découpage/interprétation.

#### Production

À ajouter : environnement reproductible, fichiers/`stdin` correctement gérés, tests dans le conteneur et CI/build reproductible.

### Increment 2 — Docker

#### Étape 1 — Lecture guidée

**exec form vs shell form :**

* Shell form : `ENTRYPOINT logsentry.sh` → exécuté via `/bin/sh -c`, le shell devient PID 1, les signaux sont propagés au shell mais pas forcément au process enfant.
* Exec form : `ENTRYPOINT ["/app/bin/logsentry.sh"]` → le script devient directement PID 1, reçoit SIGTERM/SIGINT directement, permet un arrêt propre et rapide.

**PID 1 et propagation SIGTERM :**

* En Docker, le process avec PID 1 reçoit les signaux système (SIGTERM de `docker stop`). Si PID 1 est un shell (shell form), il transmet mal ou pas les signaux aux enfants. Avec exec form + trap TERM dans le script, `docker stop` déclenche le trap → cleanup → exit 143 propre.

**Pourquoi COPY avant RUN (cache de layers) :**

* Docker cache chaque layer. Si `COPY` est après `RUN apk install`, toute modification du code source invalide le cache et force la réinstallation des dépendances. En copiant d'abord le code source, les layers d'installation (lent, stable) sont seules invalidées quand les dépendances changent.

**Pourquoi `--chown` sur `COPY` plutôt qu'un `RUN chown` :**

* `COPY --chown=sentry:sentry` fait le changement de propriétaire dans une seule layer, atomique. Un `RUN chown` créerait une layer intermédiaire où les fichiers sont root avant le chown, et cette layer intermédiaire persiste dans l'historique (les fichiers root restent accessibles en inspectant les layers). `--chown` sur COPY est aussi plus lisible.

#### Étape 5 — Résultats des tests

| Test | Commande | Attendu | Obtenu |
| ------ | ---------- | --------- | -------- |
| Non-root effectif | `docker run --rm --entrypoint id logsentry:0.2.0` | `uid=10001(sentry)` | `uid=10001(sentry)` |
| Volume absent | `docker run --rm logsentry:0.2.0 -i /nope.log` | exit **2** | exit **2** |
| Format bidon | `docker run --rm logsentry:0.2.0 -f xml` | exit **3** | exit **3** |
| Stdin vs fichier | `cat data/access.log \| docker run --rm -i logsentry:0.2.0 -f text -i -` | mêmes chiffres | 500 req, 121 erreurs, 595 ms — identiques |
| Top > endpoints | `... -n 999` | pas de crash, moins de lignes | clampé automatiquement |
| Taille image | `docker images logsentry:0.2.0` | < 30 MB | **11.8 MB** |

## Increment 3 — Streaming & signaux

### Pipe + sous-shell

Avec :

```bash
count=0

command | while read -r line; do
    count=$((count + 1))
done

echo "$count"
```

Le `while` peut s'exécuter dans un **sous-shell**. La modification de `count` est donc perdue.

Préférer :

```bash
while read -r line; do
    count=$((count + 1))
done < <(command)
```

→ La boucle reste dans le shell courant.

---

### `set -u` vs `set -e`

#### `set -u`

Protège contre les **variables non définies** :

```bash
set -u
echo "$username"
```

→ erreur si `username` n'existe pas.

Ne détecte **pas** les commandes qui échouent.

#### `set -e`

Protège contre les **commandes qui échouent** :

```bash
set -e
cp fichier_inexistant /tmp/
```

→ le script s'arrête.

Ne détecte **pas** les variables non définies.

#### Les trois

```bash
set -euo pipefail
```

* `-e` → erreur d'une commande
* `-u` → variable inexistante
* `pipefail` → erreur dans un pipeline

### T1 - ./bin/logsentry.sh -i data/big.log

* Le compteur retourne 0.

Le compteur s'incrémentait dans un `while` exécuté dans le sous-shell du pipeline :

```bash
command | while read -r line; do
  COUNT=$((COUNT + 1))
done
```

La modification de `COUNT` était donc perdue à la fin du sous-shell.

Une première correction consiste à utiliser une process substitution :

```bash
while IFS= read -r line; do
  ...
done < <(command)
```

La boucle reste alors dans le shell courant.

La correction finale utilise directement une redirection :

```bash
while IFS= read -r line; do
  ...
done <"$STREAM"
```

### T2 - cat data/big.log | ./bin/logsentry.sh -

* Même problème que T1 : le `while` du pipeline pouvait s'exécuter dans un sous-shell.

### T3 - ./bin/logsentry.sh -i /nope.log; echo exit=$?

* Le fichier est inexistant, mais le script continue.

Je rajoute `set -e` pour que le script s'arrête dès qu'une commande échoue.

```bash
set -euo pipefail
```

* `-e` → arrêt sur erreur d'une commande
* `-u` → erreur lors de l'utilisation d'une variable non définie
* `pipefail` → un pipeline échoue si une de ses commandes échoue

### T4 - ./bin/logsentry.sh -i data/big.log | head -3

* Le programme ne produit qu'une seule ligne sur stdout :

```text
count=500000
```

`head -3` ne peut donc pas afficher plus que cette ligne.

Aucune sortie supplémentaire ne vient polluer stdout.

### T5 - /usr/bin/time -v ./bin/logsentry.sh -i data/big.log 2>&1 | grep 'Maximum resident'

* L'implémentation :

```bash
endpoint=$(printf '%s\n' "$line" | awk '{print $7}')
```

pose un gros problème de performances.

Pour chaque ligne, elle lance un nouveau processus `awk`, récupère sa sortie, puis recommence. Avec 500 000 lignes, cela représente environ 500 000 processus `awk`.

Ma correction extrait directement le 7e champ avec `read`, sans lancer de processus externe :

```bash
while read -r _ _ _ _ _ _ endpoint _; do
  COUNT=$((COUNT + 1))
  ENDPOINTS["$endpoint"]=$((${ENDPOINTS["$endpoint"]:-0} + 1))
done <"$STREAM"
```

`mapfile` a également été supprimé : le fichier est maintenant traité ligne par ligne, en streaming.

```bash
/usr/bin/time -v ./bin/logsentry.sh -i data/big.log 2>&1 | grep 'Maximum resident'

        Maximum resident set size (kbytes): 3608
```

Soit environ 3,5 MiB de mémoire maximale.

### T6 - docker stop

* Le premier test utilisait :

```bash
docker run -d --name ls logsentry:0.3.0 -i /dev/stdin
```

Il y avait une confusion entre les deux `-i`.

```text
docker run -i
           ↑
           option Docker : garder stdin ouvert

logsentry ... -i /dev/stdin
              ↑
              argument du script : lire depuis stdin
```

Sans `-i` côté Docker, stdin était fermé et le processus pouvait terminer immédiatement avec le code `0`.

Correction :

```bash
docker run -d -i --name ls logsentry:0.3.0 -i /dev/stdin
```

Le script gère également explicitement `SIGTERM` :

```bash
on_term() {
  exit 143
}

trap cleanup EXIT
trap on_term TERM
```

`143 = 128 + 15`, où `15` correspond à `SIGTERM`.

Test final :

```bash
docker build --tag logsentry:0.3.0 .
docker run --rm --read-only -v "$PWD/data:/data:ro" logsentry:0.3.0 -i /data/big.log -f text
docker run -d -i --name ls logsentry:0.3.0 -i /dev/stdin
time docker stop ls
docker inspect ls --format '{{.State.ExitCode}}'
docker rm ls
```

Résultat :

```text
count=500000
cleanup: terminaison propre
docker stop ls ... 0,132 total
143
```

Le conteneur reçoit correctement `SIGTERM`, exécute le nettoyage et termine avec le code `143`.
