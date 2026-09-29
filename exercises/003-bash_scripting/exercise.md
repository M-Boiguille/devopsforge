# 🕵️ LogSentry — Incrément 3 : le pipeline « streaming » qui cache 5 bugs

> **Note du formateur (transparence)**
> 1. Incrément **3 = exercice de debug** (règle « 1 sur 3 »). Tu vas donc recevoir un script **cassé** — je te décris des **symptômes**, jamais les causes. Attends-toi à devoir lire du code, pas à le réécrire.
> 2. Les notions dues `linux.bash_scripting` (priorité **haute**) et `linux.file_parsing` (priorité moyenne) sont au cœur de l'exercice : `pipes_subshells`, `trappage_signaux`, `gestion_erreurs_set_e` d'un côté ; `parsing_streaming` + `awk` de l'autre.
> 3. Je prolonge le fil rouge **LogSentry** (`fil-rouge/logsentry/`). On repart de l'image Docker de l'incrément 2 : elle est censée encaisser des logs de plusieurs centaines de Mo en flux. Elle ne le fait pas.
> 4. Je touche aussi — légèrement — `process_management` (`kill_signals`) et `transversal.debugging_methodology` (reproduire → isoler → hypothèses → corriger).

---

## 📌 Contexte

Ton image `logsentry:0.2.0` tourne. Un SRE l'a branchée sur un fichier de **500 Mo** : le conteneur s'est fait OOM-killer en 3 s, `docker stop` met **10 secondes** au lieu de 2, et quand il pipe la sortie vers `jq`, celui-ci râle. Le `bin/logsentry.sh` a été étendu (branche `fix/streaming`) pour attaquer ce cas — **la version actuelle contient 5 défauts**. Ta mission : **diagnostiquer et réparer sans réécrire from scratch**.

---

## 🎯 Objectifs (identifiants exacts de la roadmap)

| Domaine | Notion | Sous-notions visées | Ce que tu dois démontrer |
| --- | --- | --- | --- |
| linux | `bash_scripting` *(due, high)* | `pipes_subshells`, `trappage_signaux`, `gestion_erreurs_set_e`, `lint_shellcheck` | Tu sais reconnaître un état de variable perdu dans un pipe, ajouter un trap `TERM`, et durcir un script avec `set` |
| linux | `file_parsing` *(due, medium)* | `parsing_streaming`, `awk` | Tu sais traiter un gros fichier **ligne par ligne** sans le charger en RAM |
| linux | `process_management` | `kill_signals` | Tu sais relier le comportement de `docker stop` au trap de signal dans PID 1 |
| transversal | `debugging_methodology` | `reproduire`, `isoler`, `hypotheses`, `post_mortem` | Tu produis un raisonnement reproductible, pas du tâtonnement |

---

## ⚙️ Instructions

### Étape 0 — Setup (3 min)

```bash
cd ~/fil-rouge/logsentry
git checkout -b fix/streaming
git status                          # l'incrément 2 (v0.2.0) doit être commité
docker images logsentry:0.2.0       # l'image doit exister
```

Génère un gros log de test (500 000 lignes, ~50 Mo — suffisant pour révéler le symptôme mémoire) :

```bash
mkdir -p data tests
for i in $(seq 1 500000); do
  echo "10.0.0.$((RANDOM%255)) - - [27/Sep/2026:10:00:00 +0000] \"GET /api/articles/$((RANDOM%500)) HTTP/1.1\" 200 $((RANDOM%9000))"
done > data/big.log
wc -c data/big.log
```

---

### Étape 1 — Lecture ciblée (10 min) — *les 20% théoriques*

Lis **uniquement** ces deux sources, puis reviens coder :

1. **Bash Pitfalls — mywiki.wooledge.org/BashPitfalls** : les entrées **#24 (pipe → sous-shell)** et **#26/Trap**. Note en une ligne chacune.
2. **ShellCheck doc** : <https://www.shellcheck.net/wiki/SC2030> et <https://www.shellcheck.net/wiki/SC2031> — c'est exactement le piège que tu vas rencontrer.

👉 **Livrable de lecture** : dans `tests/NOTES.md` (existant depuis l'incrément 1), ajoute :

```
### Increment 3 — Streaming & signaux
- Pipe + sous-shell, pourquoi la variable est perdue :
- set -u vs set -e : ce que chacun protège (et ne protège pas) :
```

---

### Étape 2 — Le script cassé (fourni)

Remplace `bin/logsentry.sh` par **exactement** ceci (branche `fix/streaming`) :

```bash
#!/usr/bin/env bash
# fil-rouge/logsentry/bin/logsentry.sh — v0.3.0 (mode streaming)
# ⚠️  VERSION DÉFECTUEUSE — ne pas réécrire, diagnostiquer puis réparer.

set -uo pipefail

INPUT=""
FORMAT="text"
TOP_N=10
COUNT=0
declare -A ENDPOINTS
declare -a LINES=()

usage() {
  cat >&2 <<EOF
usage: $0 -i <fichier|-> [-f text|json] [-n N]
  -i   fichier d'entrée, ou '-' pour stdin
  -f   format de sortie : text (défaut) | json
  -n   nombre de top endpoints (défaut 10)
EOF
}

cleanup() {
  echo "cleanup: terminaison propre"
  rm -f "/tmp/logsentry.$$"
}

trap cleanup EXIT

while getopts "i:f:n:h" opt; do
  case "$opt" in
    i) INPUT="$OPTARG" ;;
    f) FORMAT="$OPTARG" ;;
    n) TOP_N="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

if [[ -z "$INPUT" || "$INPUT" == "-" ]]; then
  STREAM="/dev/stdin"
else
  STREAM="$INPUT"
fi

mapfile -t LINES < "$STREAM"

printf '%s\n' "${LINES[@]}" \
  | while IFS= read -r line; do
      COUNT=$((COUNT + 1))
      endpoint=$(printf '%s\n' "$line" | awk '{print $7}')
      ENDPOINTS["$endpoint"]=$(( ${ENDPOINTS["$endpoint"]:-0} + 1 ))
    done

if [[ "$FORMAT" == "json" ]]; then
  printf '{"count": %s}\n' "$COUNT"
else
  printf 'count=%s\n' "$COUNT"
fi
```

```bash
chmod +x bin/logsentry.sh
```

---

### Étape 3 — Reproduire les 5 symptômes (8 min)

**Ne modifie rien encore.** Exécute, note les sorties **brutes** (avec `$?`) dans un carnet :

| # | Commande | Contrat attendu | Ce que tu observes ? |
| --- | --- | --- | --- |
| T1 | `./bin/logsentry.sh -i data/big.log` | `count=500000` sur **stdout seul** | ? |
| T2 | `cat data/big.log \| ./bin/logsentry.sh -` | `count=500000` | ? |
| T3 | `./bin/logsentry.sh -i /nope.log; echo exit=$?` | `exit=2` + message sur stderr | ? |
| T4 | `./bin/logsentry.sh -i data/big.log \| head -3` | seul un `count=…` sur stdout | ? |
| T5 | `/usr/bin/time -v ./bin/logsentry.sh -i data/big.log 2>&1 \| grep 'Maximum resident'` | RSS < 100 Mo | ? |
| T6 | (après rebuild image — voir étape 5) `docker stop` | arrêt < 2 s, exit 143 | ? |

> 🚫 **Interdit** : ouvrir un éditeur et « réécrire le script en mieux ». Ici on **patche** : `git diff` final doit rester petit (`< 40 lignes modifiées`).

---

### Étape 4 — Diagnostic écrit (5 min)

Avant de corriger, **écris dans `tests/NOTES.md`** (voir étape 6 pour la contrainte 5 lignes) ta démarche en 4 étapes :

```
1. Reproduire : quelle commande reproduit le symptôme ? (T1..T6)
2. Isoler     : quelle sous-partie du script est incriminée ? (numéro de ligne + hypothèse)
3. Hypothèse  : quelle modification la ferait disparaître ? (sans coder)
4. Vérifier   : quelle commande prouve que la correction marche ?
```

Outils autorisés (et à utiliser) :
```bash
bash -x ./bin/logsentry.sh -i data/access.log 2>&1 | head -40
shellcheck -S warning bin/logsentry.sh
```

---

### Étape 5 — Réparer (15 min)

Applique **5 corrections minimales**. Contrat à respecter :

| Contrat | Commande de preuve |
| --- | --- |
| `count=500000` pour le fichier **et** pour stdin | `diff <(./bin/logsentry.sh -i data/big.log) <(./bin/logsentry.sh - < data/big.log)` → vide |
| Aucun parasite sur stdout (les messages d'info vont sur **stderr**) | `./bin/logsentry.sh -i data/big.log \| jq -e .` en mode `json` |
| Fichier d'entrée invalide → `exit 2`, format inconnu → `exit 3` | `./bin/logsentry.sh -i /nope.log; echo $?` puis `./bin/logsentry.sh -i data/big.log -f xml; echo $?` |
| `SIGTERM` → sortie rapide, code `143` | `docker stop ls` < 2 s, `docker inspect ls --format '{{.State.ExitCode}}'` |
| RSS **< 100 Mo** sur un fichier de 50 Mo (et stable si on passe à 500 Mo) | `/usr/bin/time -v ./bin/logsentry.sh -i data/big.log` |

Rebuild l'image et re-teste **dans le conteneur** :

```bash
docker build --tag logsentry:0.3.0 .
docker run --rm --read-only -v "$PWD/data:/data:ro" logsentry:0.3.0 -i /data/big.log -f text
docker run -d --name ls logsentry:0.3.0 -i /dev/stdin
time docker stop ls
docker inspect ls --format '{{.State.ExitCode}}'
docker rm ls
```

---

### Étape 6 — Teach-back `tests/NOTES.md` (5 min)

⚠️ **Ce fichier est noté sur la dimension `explication`. Sans lui, tu perds 15 points.**

Rédige **5 lignes maximum**, avec **tes mots**, sans recopier le jargon du cours. **Une ligne par défaut corrigé**, au format :

```
- <symptôme vu> → <ce que tu as réellement changé dans le code, en français simple>
```

Exemple de niveau attendu (ne recopie pas, écris le tien sur **tes** 5 bugs) :

> - `count=0` alors que le fichier a 500000 lignes → ma boucle vivait dans un tube, donc dans un autre processus : elle comptait dans le vide. Je l'ai ramenée dans le processus principal.  

Pas de copier-coller depuis StackOverflow, pas de « SC2031 : subshell issue ». **Ta phrase à toi.**

---

### Étape 7 — Commit & tag (3 min)

```bash
git add bin/logsentry.sh tests/NOTES.md Dockerfile
git commit -m "fix(logsentry): streaming RAM-constant, signaux, exit codes (0.3.0)"
git tag v0.3.0
git log --oneline -3
```

---

## 📚 Ressource recommandée (choisir-en une principale)

- **KodeKloud — Linux Shell Scripting** (module « Error handling & signals ») : <https://kodekloud.com/courses/shell-scripts-for-beginners/>
- **Bash Pitfalls** (mywiki.wooledge.org) — section *Trap* et *Pipes* : <https://mywiki.wooledge.org/BashPitfalls>
- **ShellCheck wiki SC2030 / SC2031** : <https://www.shellcheck.net/wiki/SC2030>
- *Bonus outillage* : `bats-core` pour transformer les 6 tests ci-dessus en suite automatisée.

---

## 🧮 Grille de notation (100 pts) — **grille `default`**

| Dimension | Poids | Ce qui est évalué | 0 pt | Partiel | Plein |
| --- | --- | --- | --- | --- | --- |
| **Connaissance** | **15 %** | Subshell dans un pipe, `set -u/-e`, trap, `mapfile` vs `while read`, ordre des erreurs | mal compris | correct sans justification | correct + justifié en 1 ligne dans `NOTES.md` |
| **Implémentation** | **25 %** | Les 5 corrections appliquées, contrat de l'étape 5 respecté, `git diff` < 40 lignes | pas de fix / réécriture | ≥ 3 fix OK | 5 fix OK, contrat intégralement vérifié |
| **Debug / robustesse** | **20 %** | Symptômes T1..T6 reproduits **et** expliqués, `bash -x` et `shellcheck` utilisés, exit codes 2/3/143 corrects | a corrigé au hasard | 2-3 bugs identifiés | 5 bugs identifiés avec méthode + preuve par test |
| **Explication** | **15 %** | `tests/NOTES.md` : 5 lignes max, en français, avec SES mots, une ligne par bug | absent / >5 lignes / copié | partiel, générique | 5 lignes précises, testables, sans jargon recopié |
| **Design** | **15 %** | Patch minimal (pas de réécriture), lisibilité conservée, pas de `bash 4` requis si le collègue macOS reste en scope | réécriture complète | patch correct mais bavard | patch chirurgical + commentaire concis là où il faut |
| **Sécurité** | **5 %** | Aucun secret, aucun `curl`, exit codes distincts, aucun fichier temporaire laissé | temp file résiduel | exit codes OK | tout + `--read-only` respecté dans les tests |
| **Performance** | **5 %** | RSS < 100 Mo (idéalement O(1) en taille de fichier), pas de second parcours | RSS ~ taille fichier | RSS < 100 Mo | RSS stable à 50 Mo **et** 500 Mo |

**Seuils** : ≥ 80 → `linux.bash_scripting` et `linux.file_parsing` passent ≥ 0.6 · 60-79 → consolidation ciblée · < 60 → à refaire.

**Effet sur les notions dues** :
- `bash_scripting` / `pipes_subshells` + `gestion_erreurs_set_e` validées si T1 = T2 **et** exit 2/3 corrects.
- `bash_scripting` / `trappage_signaux` validée si `docker stop` < 2 s **et** exit `143`.
- `file_parsing` / `parsing_streaming` validée si RSS < 100 Mo sur `big.log`.
- `debugging_methodology` validée si le bloc `Reproduire / Isoler / Hypothèse / Vérifier` de `NOTES.md` montre une démarche reproductible.

---

## ✅ Critères de réussite

- [ ] `diff <(./bin/logsentry.sh -i data/big.log) <(cat data/big.log | ./bin/logsentry.sh -)` → **vide** (fichier == stdin).
- [ ] `./bin/logsentry.sh -i /nope.log; echo $?` → `2` ; `-f xml` → `3`.
- [ ] Aucun texte parasite sur stdout : `./bin/logsentry.sh -i data/big.log -f json | jq -e '.count'` fonctionne.
- [ ] Aucun `cleanup:` visible dans la sortie standard (stderr autorisé).
- [ ] `/usr/bin/time -v ./bin/logsentry.sh -i data/big.log` → RSS < 100 Mo.
- [ ] `docker stop ls` < 2 s, `docker inspect ls --format '{{.State.ExitCode}}'` → `143`.
- [ ] `docker run --rm --read-only -v "$PWD/data:/data:ro" logsentry:0.3.0 -i /data/big.log` → OK.
- [ ] `shellcheck -S warning bin/logsentry.sh` → silencieux.
- [ ] `git diff v0.2.0..HEAD -- bin/logsentry.sh` < 40 lignes modifiées.
- [ ] `tests/NOTES.md` : **5 lignes maximum**, rédigées avec tes mots (notée dans `explication`).
- [ ] Commit + tag `v0.3.0` poussés.

---

## 🎤 Questions de débrief (5 min)

1. Pourquoi `count=0` alors que la boucle lit bien 500 000 lignes — explique en une phrase, puis décris **deux** façons de le réparer (donne celle que tu n'as pas choisie, et pourquoi).
2. Ton patch rend l'usage mémoire constant même sur 5 Go. Qu'est-ce qui **reste** en RAM quand même (le top endpoints) et comment changerais-tu l'algo si ce nombre de chemins distincts explosait ? *(→ amorce de l'incrément 4 : streaming top-N approché)*
3. Tu as ajouté un `trap TERM`. Que se passerait-il si tu l'avais mis **avant** `getopts` et qu'un `SIGTERM` arrivait pendant le parsing ? Que faut-il nettoyer dans ce cas ?
4. `set -e` **ne** protège **pas** d'une erreur dans un sous-shell de pipe. Comment tu l'aurais découvert sans le savoir ? Quelle option de bash le change (`set -o pipefail` — vérifie ce que tu en as en tête) ?
5. En une phrase : quelle différence entre *réparer* et *réécrire*, et pourquoi je t'ai imposé la première ?
