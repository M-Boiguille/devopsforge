# 🐳 LogSentry — Incrément 2 : conteneuriser le CLI

> **Note du formateur (transparence sur l'adaptation du profil)**
> 1. Ton profil `docker.yaml`, `git.yaml`, `kubernetes.yaml`, `terraform.yaml` ont des `notions: {}` **vides** — je m'appuie donc sur ta **roadmap** pour extraire les notions du domaine `docker`. C'est cohérent avec l'annonce faite au débrief de l'incrément 1 (*« amorce de l'incrément 2 : Docker »*).
> 2. Les notions **dues** `linux.bash_scripting` et `linux.file_parsing` restent **ciblées en consolidation** : ta dimension `debug` est à 0.3-0.5, cet incrément va l'attaquer frontalement (signaux, PID 1, entrées non fiables).
> 3. Je **prolonge le fil rouge LogSentry** annoncé à l'incrément 1. Si tu as un autre projet, dis-le : l'incrément s'y recollera.

---

## 📌 Contexte

Ton CLI `logsentry.sh` fonctionne et passe shellcheck — mais il tourne uniquement chez toi : un collègue a `bash 3.2` sur macOS, un autre n'a pas `jq`, un SRE ne veut pas installer `gawk`. Tu vas **packager le CLI dans une image Docker minimale, non-root, multi-stage**, qui s'exécute en lecture seule sur un volume et peut être pipée en stdin. Objectif : reproductibilité totale, `docker run` comme interface unique.

---

## 🎯 Objectifs (notions travaillées)

| # | Domaine | Notion / sous-notion | Ce que tu dois démontrer |
| --- | --- | --- | --- |
| 1 | linux | `bash_scripting` *(due)* → `trappage_signaux` | Le script gère `SIGTERM`/`SIGINT` (utile quand PID 1 reçoit `docker stop`) et sort proprement |
| 2 | linux | `file_parsing` *(due)* → `parsing_streaming` | Le CLI lit depuis **stdin** (`cat log | docker run -i`) sans casser le mode fichier |
| 3 | docker | `images` → `multi_stage`, `layers_cache`, `base_images` | Dockerfile 2 stages : lint de l'incrément 1, puis runtime minimal |
| 4 | docker | `containers` → `entrypoint_cmd_diff`, `healthcheck`, `resource_limits` | `ENTRYPOINT` = binaire, `CMD` = args par défaut ; `--memory` + `--cpus` documentés |
| 5 | docker | `best_practices` → `non_root`, `minimal_images`, `no_secrets_in_image` | Utilisateur non privilégié, image < 30 MB, `.dockerignore`, aucun secret |
| 6 | docker | `volumes` → `bind_mounts` | Montage `:ro` du fichier de log, preuve que l'image est immutable |

---

## ⚙️ Instructions

### Étape 0 — Setup (3 min)

```bash
cd ~/fil-rouge/logsentry
git checkout -b feat/docker-image
git status                                   # l'incrément 1 doit être commité
command -v docker && docker version --format '{{.Server.Version}}'
command -v hadolint || echo "hadolint non installé (optionnel, bonus)"
```

Crée les répertoires et un fichier `.dockerignore` **vide pour l'instant** (tu le remplis à l'étape 3).

---

### Étape 1 — Lecture guidée (10 min) — *les 20% théoriques*

Lis **uniquement** ces deux sources, puis reviens coder :

1. **Docker Docs — Best practices for writing Dockerfiles** : sections *Use multi-stage builds*, *Don't install unnecessary packages*, *Use a non-root user*, *ENTRYPOINT vs CMD*. Note en 4 lignes la différence **exec form `["..."]`** vs **shell form `"..."`** et l'impact sur les signaux.
2. **Docker Docs — Best practices : Understand signal handling** (document *PID 1 problem*).

👉 **Livrable de lecture** : complète `tests/NOTES.md` (créé à l'incrément 1) avec :

```
### Increment 2 — Docker
- exec form vs shell form :
- PID 1 et propagation SIGTERM :
- Pourquoi COPY avant RUN (cache de layers) :
- Pourquoi --chown sur COPY plutôt qu'un RUN chown :
```

---

### Étape 2 — Adapter le script au conteneur (10 min)

Modifie **légèrement** `bin/logsentry.sh` (ne réécris pas tout) pour :

1. **Accepter stdin** : si `--input` vaut `-` ou est absent en mode pipe, lire `/dev/stdin` sans toucher au reste.
2. **Traper SIGTERM** en plus de `SIGINT` et `EXIT` :
   ```bash
   trap 'cleanup' EXIT
   trap 'log_warn "SIGTERM reçu"; exit 143' TERM
   trap 'log_warn "SIGINT reçu";  exit 130' INT
   ```
3. **Sortir uniquement sur stdout** (messages d'erreur → stderr). Vérifie : `./bin/logsentry.sh -i data/access.log 2>/dev/null | wc -l` doit donner la même chose que sans redirection.
4. **Être idempotent** : deux exécutions successives sur le même fichier donnent un `diff` vide.

Test rapide avant de containeriser :

```bash
./bin/logsentry.sh -i data/access.log    > /tmp/a.txt
cat data/access.log | ./bin/logsentry.sh - > /tmp/b.txt
diff /tmp/a.txt /tmp/b.txt && echo "OK stdin==file"
```

---

### Étape 3 — Dockerfile multi-stage + non-root (12 min)

Crée `Dockerfile` **impérativement multi-stage** :

- **Stage `lint`** : base `koalaman/shellcheck-alpine` → `shellcheck -S warning /src/bin/logsentry.sh`. Si le lint échoue, **le build échoue** (l'incrément 1 doit rester vert en CI).
- **Stage `runtime`** : base `alpine:3.20` (ou `debian:12-slim` si tu justifies), installe **uniquement** `gawk` et `jq` (pas `bash` par défaut, apk peut te le donner en dépendance — justifie dans un commentaire).

Contraintes **obligatoires** dans le Dockerfile :

| Contrainte | Exemple d'implémentation |
| --- | --- |
| `WORKDIR` explicite | `/app` |
| Utilisateur non-root créé | `adduser -D -u 10001 sentry` |
| `COPY --chown` (pas de `RUN chown`) | `COPY --chown=sentry:sentry bin/ /app/bin/` |
| `ENTRYPOINT` en **exec form** | `ENTRYPOINT ["/app/bin/logsentry.sh"]` |
| `CMD` = args par défaut | `CMD ["--help"]` |
| `HEALTHCHECK` | exécute `--help` et vérifie exit 0 (timeout 3s, interval 30s) |
| Aucun secret en dur | (aucun `ENV PASSWORD=...`, pas de `.env` copié) |

Complète ensuite `.dockerignore` : au minimum `data/`, `.git/`, `tests/*.tmp`, `*.md`, `.gitignore` lui-même.

---

### Étape 4 — Build & run (8 min)

```bash
docker build --tag logsentry:0.2.0 .
docker images logsentry                       # taille attendue : < 30 MB
```

Prouve-le **trois fois** :

```bash
# 1. Mode fichier avec volume read-only
docker run --rm -v "$PWD/data:/data:ro" logsentry:0.2.0 -i /data/access.log -f text

# 2. Mode pipe stdin
cat data/access.log | docker run --rm -i logsentry:0.2.0 -f text -

# 3. JSON validé par jq dans un conteneur jetable
docker run --rm -i logsentry:0.2.0 -f json - < data/access.jsonl | jq -e '.top_endpoints[0].path'
```

**Contraintes** :
- Les 3 sorties doivent afficher **les mêmes chiffres** (mêmes 500 requêtes, même moyenne, même top).
- Le conteneur ne doit écrire **nulle part** en dehors de stdout (vérifie : `docker run --rm --read-only ...` doit passer pour le mode fichier).
- Fournis aussi un `docker compose run` minimal **optionnel** (bonus) ou justifie pourquoi tu n'en as pas besoin à ce stade.

---

### Étape 5 — Robustesse : signaux & cas limites (8 min)

| Test | Commande | Attendu |
| --- | --- | --- |
| SIGTERM propre | `docker run -d --name ls logsentry:0.2.0 -i /dev/stdin` puis `time docker stop ls` | arrêt **< 2 s**, code de sortie `143` |
| Non-root effectif | `docker run --rm --entrypoint id logsentry:0.2.0` | `uid=10001(sentry)` |
| Volume absent | `docker run --rm logsentry:0.2.0 -i /nope.log; echo $?` | exit **2** |
| Format bidon | `... -f xml; echo $?` | exit **3** |
| Top > endpoints | `... -n 999` | pas de crash, moins de lignes affichées |

Note les codes obtenus dans `tests/NOTES.md` (une ligne par test).

Bonus robustesse : `docker run --rm --memory=64m --cpus=0.25 logsentry:0.2.0 -i /data/access.log` doit passer sans OOM.

---

### Étape 6 — Commit & tag (3 min)

```bash
git add Dockerfile .dockerignore bin/ tests/
git commit -m "feat(logsentry): image docker multi-stage non-root (0.2.0)"
git tag v0.2.0
```

---

## 📚 Ressources recommandées (choisis-en une principale)

- **KodeKloud — Docker** (lab Dockerfile + multi-stage + non-root) : <https://kodekloud.com/courses/docker/>
- **Docker Docs — Best practices for Dockerfiles** : <https://docs.docker.com/develop/develop-images/dockerfile_best-practices/>
- **Docker Docs — PID 1 & signals** : <https://docs.docker.com/engine/reference/run/#foreground>
- *Bonus outillage* : `hadolint` (<https://github.com/hadolint/hadolint>) · `dive` (<https://github.com/wagoodman/dive>) · `trivy image logsentry:0.2.0`

---

## 🧮 Grille de notation (100 pts)

| Dimension | Poids | Ce qui est évalué | 0 pt | Partiel | Plein |
| --- | --- | --- | --- | --- | --- |
| **Implémentation** | **30 %** | Dockerfile build, image < 30 MB, les 4 tests de l'étape 5 passent | build échoue | build OK, 1-2 tests KO | build OK, tous les tests + mêmes chiffres text/json |
| **Connaissance** | 15 % | Multi-stage réellement utile (lint), exec vs shell form, ordre `COPY`/`RUN`, `--chown` sur `COPY` | mal compris | correct sans justification | idiomatique + justifié par écrit dans `NOTES.md` |
| **Design & intention** | 10 % | Structure Dockerfile (labels, ordre logique, commentaires utiles), `.dockerignore` cohérent | pas de `.dockerignore` | présent mais laxiste | `.dockerignore` minimal + Dockerfile lisible en 30 s |
| **Debug / robustesse** | 15 % | SIGTERM < 2 s, entrées malformées, volume absent, top > N, `--read-only` | crash silencieux | 1-2 cas gérés | tous gérés + codes d'erreur distincts respectés |
| **Sécurité** | 15 % | Non-root 10001, aucun secret, pas de `curl \| sh`, base minimale, `:ro` sur les volumes | root dans l'image | non-root mais surface large | non-root + image minimale + justification des paquets installés |
| **Performance** | 10 % | Taille image < 30 MB, cache de build exploité (2ᵉ `docker build` quasi instantané), `--cpus/--memory` raisonnés | image > 200 MB | image < 80 MB | < 30 MB + cache démontré + limites documentées |
| **Explication** | 5 % | `NOTES.md` complété + débrief tenu en 3 min | rien | notes partielles | explique un choix contestable de son Dockerfile |

**Seuils** : ≥ 80 → `docker.images`, `docker.containers`, `docker.best_practices` notées ≥ 0.6 · 60-79 → consolidation ciblée sur 1-2 sous-notions · < 60 → à refaire.

**Effet sur les notions dues** :
- `linux.bash_scripting` / `trappage_signaux` validée si SIGTERM < 2 s et exit 143.
- `linux.file_parsing` / `parsing_streaming` validée si `stdin == file` en mode texte **et** JSON.

---

## ✅ Critères de réussite

- [ ] `docker build` passe **et échoue** si tu introduis volontairement un warning shellcheck dans `bin/logsentry.sh` (preuve du stage `lint`).
- [ ] `docker images logsentry:0.2.0` → taille **< 30 MB**.
- [ ] `docker run --rm --entrypoint id logsentry:0.2.0` → `uid=10001`.
- [ ] Les 3 sorties de l'étape 4 donnent **exactement les mêmes chiffres**.
- [ ] `docker stop ls` s'arrête en **< 2 s**, `docker inspect` montre exit `143`.
- [ ] `docker run --rm --read-only -v "$PWD/data:/data:ro" ...` fonctionne.
- [ ] Aucun secret, aucun `.env` copié, aucune commande `curl` dans le Dockerfile.
- [ ] `docker image inspect logsentry:0.2.0 --format '{{.Config.User}}'` → `sentry`.
- [ ] Commit + tag `v0.2.0` poussés sur la branche.
- [ ] `tests/NOTES.md` complété (4 lignes de lecture + résultats des tests).

---

## 🚀 Bonus (si tu termines avant 60 min)

1. Injecte un `build-arg` `VERSION` et expose-le via `LABEL org.opencontainers.image.version=$VERSION` + un `--version` sur le CLI.
2. Fais tourner `trivy image logsentry:0.2.0` et corrige au moins un `HIGH` réel ou documente pourquoi il est inatteignable.
3. Compose minimal `docker-compose.yml` avec `read_only: true`, `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]` pour le conteneur.

---

## 🎤 Questions de débrief (5 min)

1. Pourquoi `ENTRYPOINT ["/app/bin/logsentry.sh"]` en **exec form** plutôt que shell form, quand on veut que `docker stop` fonctionne vite ?
2. Ton stage `lint` prend 40 MB dans l'image finale ou pas — pourquoi ? Que se passerait-il si tu supprimais `--from=lint` par erreur ?
3. Où ton conteneur échouerait-il si je l'exécutais avec `--memory=16m` sur un fichier de 10 GB ? Que faudrait-il changer pour tenir ? *(→ amorce de l'incrément 3 : parsing streaming)*
4. Qu'est-ce qui manque pour que cette image soit « déployable » en prod dans un cluster ? *(→ amorce de l'incrément 4 : Kubernetes — Deployment, resources, probes, ConfigMap)*
5. En une phrase : quelle est la différence entre **reproductibilité** (« ça marche chez moi ») et **immutabilité** (« l'image `0.2.0` ne changera jamais ») ?
