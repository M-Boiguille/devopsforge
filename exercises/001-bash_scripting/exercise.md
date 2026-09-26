# Exercice — `logpipe.sh` : un agrégateur de logs nginx robuste, idempotent et conteneurisé

> **Note du formateur** : ton profil ne contient aucune notion *due* (`dues: []`) et deux domaines seulement sont documentés (`linux/bash_scripting`, `linux/file_parsing`) — tous deux à **score 0.0 partout**. J'ai donc traité ces deux notions comme prioritaires et j'ai ajouté **Docker** et **Git** en surface (domaines vides → découverte active, pas d'évaluation profonde). C'est un exercice « fondations » : on vise la solidité, pas l'exotisme.

---

## Contexte

Tu construis **`logpipe`**, le fil rouge de ce cycle : un pipeline d'analyse de logs d'accès HTTP qui doit être fiable en production (cron, CI, conteneur). Aujourd'hui, on livre le **premier incrément** : un script Bash qui transforme un `access.log` nginx en rapport JSON exploitable, qui peut être réexécuté mille fois sans effet de bord, et qui tourne dans un conteneur Alpine minimal.

Durée cible : **45 minutes** (30 min si tu es à l'aise, 60 min si tu soignes les cas limites — et tu devrais).

---

## Objectifs (notions travaillées)

| # | Notion | Statut | Attendu |
|---|--------|--------|---------|
| 1 | `bash_scripting` → `gestion_erreurs_set_e` | prio (0.0) | `set -euo pipefail` + `trap` + codes de sortie explicites |
| 2 | `bash_scripting` → `arguments_getopts` | prio (0.0) | `getopts` avec options courtes, validation, `usage()` |
| 3 | `bash_scripting` → `boucles_conditions`, `fonctions`, `variables_expansion` | prio (0.0) | découpage en fonctions, `"${var}"`, `${var:-defaut}`, `[[ ]]` |
| 4 | `file_parsing` → `awk` | prio (0.0) | extraction et agrégation en **une seule passe** |
| 5 | `file_parsing` → `grep`, `expressions_regulieres`, `cut_sort_uniq`, `jq` | prio (0.0) | filtrage, comptage, validation JSON |
| 6 | `docker` | découverte | image Alpine + deps, exécution avec volume en lecture seule |
| 7 | `git` | découverte | branche + commit atomique, message conventionnel |

---

## Instructions

### Étape 0 — Setup (3 min)

```bash
mkdir -p ~/fil-rouge/logpipe/{data,out,tests} && cd ~/fil-rouge/logpipe
git init -q && git checkout -q -b feat/logpipe
```

**Jeu de données** — génère-le, ne le fabrique pas à la main :

```bash
awk 'BEGIN{
  srand(42)
  split("10.0.0.12 10.0.0.34 172.16.5.9 192.168.1.77 10.0.0.99", ips, " ")
  split("/api/v1/users /api/v1/orders /health /static/app.js /api/v1/login", paths, " ")
  split("200 200 200 404 500 302 200 503", codes, " ")
  for (i=1; i<=500; i++)
    printf "%s - - [12/Mar/2025:%02d:%02d:%02d +0100] \"GET %s HTTP/1.1\" %s %d \"-\" \"curl/8.1.0\"\n",
      ips[1+int(rand()*5)], int(rand()*24), int(rand()*60), int(rand()*60),
      paths[1+int(rand()*5)], codes[1+int(rand()*8)], int(rand()*9000)+100
}' > data/access.log
wc -l data/access.log   # attendu : 500
```

### Étape 1 — Squelette et contrat d'interface (8 min)

Crée `logpipe.sh` avec :

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

Signature imposée :

```
logpipe.sh -i <fichier|dossier> [-o <sortie.json>] [-n <top>] [-f json|text] [-F] [-v] [-h]
```

- `-i` : requis. Si c'est un **dossier**, tu traites tous les `*.log` qu'il contient (récursif = bonus).
- `-o` : défaut `out/report.json` (le dossier parent doit être créé si absent).
- `-n` : top N, défaut `5`, **doit être un entier > 0** sinon erreur + code 2.
- `-f` : `json` (défaut) ou `text`.
- `-F` : force le recalcul même si le rapport est à jour.
- `-v` : traces sur **stderr** (jamais sur stdout : stdout ne sert qu'aux données).
- `-h` : `usage()` sur stdout, code 0.

**À faire maintenant, sans tricher** : `usage()`, le parse `getopts`, la validation des entrées, et **des codes de sortie distincts** (0 OK / 2 usage invalide / 3 entrée illisible / 4 parsing impossible). Termine par un `main "$@"`.

> ⚠️ Utilise `[[ ... ]]`, `"${var}"` systématiquement, `printf` plutôt que `echo` pour du formaté, et n'utilise **jamais** `eval`.

### Étape 2 — Extraction et agrégation (15 min)

Produis ces statistiques à partir du log :

| Métrique | Méthode imposée |
|---|---|
| `total_requests` | comptage, pas `wc -l` sur un flux déjà consommé |
| `bytes_served` | somme du 10ᵉ champ |
| `status_classes` (`2xx`…`5xx`) | `substr($9,1,1)"xx"` |
| `error_rate_5xx` | arrondi à 4 décimales |
| `top_ips` | comptage par IP, tri décroissant, `head -n "$top"` |
| `top_paths` | idem sur le chemin, avec le `query string` retiré (regex) |
| `invalid_lines` | lignes ne matchant pas le format → comptées, **pas** de crash |

Contraintes de performance :
- **Une seule passe `awk`** pour les compteurs globaux ; les top-N peuvent passer par `sort | uniq -c | sort -rn | head`.
- Pas de `cat file | grep` : redirige le fichier.
- Le script doit tenir < 2 s sur 500 lignes (et rester linéaire — teste mentalement sur 1 M de lignes).

### Étape 3 — Sortie JSON valide + idempotence (8 min)

Format de sortie :

```json
{
  "generated_at": "2025-03-12T10:23:45Z",
  "source": "data/access.log",
  "source_sha256": "…",
  "total_requests": 500,
  "invalid_lines": 0,
  "bytes_served": 1234567,
  "status_classes": {"2xx": 250, "3xx": 60, "4xx": 90, "5xx": 100},
  "error_rate_5xx": 0.2,
  "top_ips": [{"ip": "10.0.0.12", "count": 120}],
  "top_paths": [{"path": "/api/v1/users", "count": 110}]
}
```

**L'échappement JSON doit être fait par toi** (ghostscript interdit) :
- échappe `\` et `"` dans les chaînes ;
- construis via `printf`/heredoc, puis **valide** avec `jq -e . out/report.json >/dev/null` — si `jq` échoue, le script sort en code 4.

**Idempotence** : si `out/report.json` existe, est un JSON valide, et que `source_sha256` correspond au hash actuel de l'entrée → affiche `up-to-date` et sors en **0 sans réécrire le fichier** (sauf `-F`). Vérifie-le avec :

```bash
sha256sum out/report.json && ./logpipe.sh -i data/access.log -v && sha256sum out/report.json
# les deux hash doivent être identiques
```

**Écriture atomique** : écris dans `mktemp`, puis `mv` sur la cible. Ajoute un `trap` de nettoyage sur `EXIT INT TERM` qui supprime le temporaire — y compris si le script meurt en cours de route.

### Étape 4 — Tests négatifs (5 min)

Le script doit se comporter proprement (message clair sur **stderr**, code non nul, **aucun fichier temporaire résiduel**) sur :

```bash
./logpipe.sh -i data/inexistant.log      # code 3
./logpipe.sh -i data/access.log -n abc   # code 2
./logpipe.sh                             # code 2 + usage
./logpipe.sh -i /etc/passwd              # 0 lignes valides → code 4
```

### Étape 5 — Conteneurisation (5 min)

`Dockerfile` :

```dockerfile
FROM alpine:3.20
RUN apk add --no-cache bash coreutils gawk jq
WORKDIR /app
COPY logpipe.sh /app/logpipe.sh
ENTRYPOINT ["/app/logpipe.sh"]
```

Puis :

```bash
docker build -t logpipe:0.1 .
docker run --rm -v "$PWD/data:/data:ro" -v "$PWD/out:/out" logpipe:0.1 -i /data/access.log -o /out/report.json
```

Question à traiter en une ligne dans ton README : *pourquoi `:ro` sur le volume d'entrée et un volume distinct pour la sortie ?*

### Étape 6 — Finition (4 min)

```bash
shellcheck -S style logpipe.sh    # 0 warning attendu
git add logpipe.sh Dockerfile README.md
git commit -m "feat(logpipe): agrégateur de logs idempotent et conteneurisé"
```

Le `README.md` explique en 10 lignes : usage, codes de sortie, garantie d'idempotence, limites connues.

---

## Ressource recommandée (20 % lecture)

- **KodeKloud — Bash Scripting** (sections *Exit codes*, *Functions*, *Trap*, *getopts*) : https://kodekloud.com/courses/bash-scripting/
- **GNU Bash Manual — `set` / `trap` / `getopts`** : https://www.gnu.org/software/bash/manual/bash.html#The-Set-Builtin
- **ShellCheck** (passe ton script en ligne, lis chaque règle déclenchée) : https://www.shellcheck.net/

---

## Grille de notation (100 pts)

| Dimension | Poids | Ce qui est évalué |
|---|---:|---|
| **Implémentation fonctionnelle** | **30 %** | Les 7 métriques sont exactes sur le jeu de 500 lignes ; `-f text` fonctionne ; options `-o/-n/-F/-v/-h` opérationnelles. |
| **Design & robustesse** | **20 %** | `set -euo pipefail`, découpage en fonctions, `main "$@"`, `trap` de nettoyage, écriture atomique, idempotence réellement vérifiée (hash identique). |
| **Parsing (awk/grep/regex/jq)** | **20 %** | Extraction correcte des champs, une seule passe pour les compteurs, `invalid_lines` géré, JSON validé par `jq -e`, échappement maison correct. |
| **Sécurité** | **10 %** | Zéro `eval`, quoting systématique, validation stricte de `-n` et des chemins, pas d'écriture hors de `-o`, `:ro` sur le volume d'entrée. |
| **Debug & gestion d'erreurs** | **10 %** | Codes de sortie distincts et cohérents, messages d'erreur actionnables sur stderr, aucun fichier temporaire résiduel après échec. |
| **Performance** | **5 %** | Pas de `cat | grep`, pas de relecture du fichier par métrique, pas de `$( )` dans une boucle chaude. |
| **Explication & Git** | **5 %** | README clair, message de commit conventionnel, un seul commit atomique (ou deux commits bien séparés script/conteneur). |

**Barème indicatif** : ≥ 85 = notion validée (score visé ≥ 0.8) · 60–84 = à consolider · < 60 = à refaire après relecture de la ressource.

---

## Critères de réussite (checklist finale)

- [ ] `shellcheck -S style logpipe.sh` ne sort **aucun** warning.
- [ ] Deux exécutions consécutives → même hash de `out/report.json` (idempotence prouvée, pas supposée).
- [ ] `./logpipe.sh -i data/access.log -o /tmp/nawak.json` alors que `/tmp` est en lecture seule → code non nul, message clair, **pas** de fichier orphelin.
- [ ] `jq -e . out/report.json` passe, et `error_rate_5xx` correspond au calcul manuel (`100/500 = 0.2`).
- [ ] `docker run` produit le rapport avec le volume d'entrée monté en `:ro`.
- [ ] Le script tient la charge : `seq 1 200 | ...` (ou `yes` + `head`) sur 100 k lignes reste sous 5 s.

**Bonus (non noté, à mentionner dans le README)** : support récursif du dossier d'entrée, `parallel`/`xargs -P` sur plusieurs fichiers, sortie `csv`, ou version `--watch` avec `inotifywait`.

---

### Pièges que je vais regarder en premier

1. `set -e` **sans** `pipefail` : l'erreur d'`awk` disparaît dans le pipe.
2. `trap 'rm -f "$tmp"' EXIT` déclaré **avant** que `$tmp` existe → `set -u` te tue. Utilise `tmp=""` puis `[[ -n "$tmp" ]] && rm -f "$tmp"`.
3. JSON construit à la main sans échappement → un User-Agent avec `"` casse tout.
4. `echo` au lieu de `printf` pour les sorties formatées (comportement variable sous `sh`).
5. Idempotence « fausse » : tu compares les dates au lieu du hash du contenu.

Bon courage — et sois fier du `trap` : c'est ce qui distingue un script jetable d'un script de production.
