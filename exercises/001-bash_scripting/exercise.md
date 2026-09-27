# 🛡️ LogSentry — Incrément 1 : un parseur de logs robuste en Bash

> **Note du formateur (transparence sur l'adaptation du profil)**
> Ton profil ne contient **aucune notion « due »** (`dues: []`) et aucun projet fil rouge n'est défini. J'ai donc pris deux décisions que tu valides ou contestes :
>
> 1. Les **notions cibles** sont `linux.bash_scripting` et `linux.file_parsing` (toutes deux à 0.0) — ce sont les seules notions existantes dans ton profil, elles sont donc traitées comme **prioritaires** et deviendront dues après cet exercice.
> 2. Je **propose un fil rouge** : `LogSentry`, un CLI d'observabilité qui sera, incrément après incrément, versionné (Git), conteneurisé (Docker), déployé (Kubernetes) et provisionné (Terraform). Si tu as un autre projet, dis-le-moi : les incréments s'y raccrocheront.

---

## 📌 Contexte

Tu rejoins une équipe SRE qui analyse chaque jour des logs d'accès web pour détecter les endpoints lents et les pics d'erreurs 5xx. Aujourd'hui, chacun bricole ses `grep | wc -l` dans son coin : résultat non reproductible, pas de gestion d'erreur, aucun test. Ta mission est de poser la **première brique du fil rouge** : un script Bash robuste, idempotent et lintable, capable de résumer un fichier de logs en mode texte **ou** JSON.

---

## 🎯 Objectifs (notions travaillées)

| # | Domaine | Notion / sous-notion | Ce que tu dois démontrer |
| --- | --------- | ---------------------- | -------------------------- |
| 1 | linux | `bash_scripting` → `arguments_getopts` | CLI avec options courtes/longues, `-h`, exit codes distincts |
| 2 | linux | `bash_scripting` → `gestion_erreurs_set_e` | `set -euo pipefail`, trap, validation d'entrées |
| 3 | linux | `bash_scripting` → `fonctions` + `boucles_conditions` | Code découpé, pas de script « plat » de 200 lignes |
| 4 | linux | `file_parsing` → `awk` | Agrégation en **un seul passage** (comptage, moyenne, top N) |
| 5 | linux | `file_parsing` → `grep` + `expressions_regulieres` | Extraction/validation de lignes, regex ancrées |
| 6 | linux | `file_parsing` → `jq` | Mode `--format json` + parsing de logs JSONL |
| 7 | linux | `file_parsing` → `cut_sort_uniq` | Top endpoints, dédoublonnage IP |
| 8 | linux | `bash_scripting_advanced` → `lint_shellcheck`, `trappage_signaux` | `shellcheck` sans warning, `trap` de nettoyage |

---

## ⚙️ Instructions

### Étape 0 — Setup (3 min)

```bash
mkdir -p ~/fil-rouge/logsentry/{bin,data,tests}
cd ~/fil-rouge/logsentry
git init -q && printf 'data/\n*.tmp\n' > .gitignore
```

Génère le jeu de données (500 lignes de logs texte + l'équivalent JSONL) :

```bash
{
  for i in $(seq 1 500); do
    ip="10.0.0.$(( (RANDOM % 8) + 10 ))"
    method=$(printf '%s ' GET POST GET GET DELETE | cut -d' ' -f$(( (RANDOM % 4) + 1 )))
    path=$(printf '%s ' /api/users /api/orders /health /api/users/42 /api/payments | cut -d' ' -f$(( (RANDOM % 5) + 1 )))
    status=$(printf '%s ' 200 200 200 201 404 500 503 | cut -d' ' -f$(( (RANDOM % 7) + 1 )))
    ms=$(( RANDOM % 1200 ))
    printf '2024-06-01T08:%02d:%02dZ %s %s %s %s %dms\n' $((RANDOM%60)) $((RANDOM%60)) "$ip" "$method" "$path" "$status" "$ms"
  done
} > data/access.log

while read -r ts ip method path status ms; do
  printf '{"ts":"%s","ip":"%s","method":"%s","path":"%s","status":%s,"duration_ms":%s}\n' \
    "$ts" "$ip" "$method" "$path" "$status" "${ms%dms}"
done < data/access.log > data/access.jsonl

wc -l data/access.log data/access.jsonl
```

---

### Étape 1 — Lecture guidée (8 min) — *les 20% théoriques*

Lis **uniquement** ces deux sections, puis reviens coder :

- le builtin `getopts` dans le manuel Bash (lien ci-dessous) : comprends la différence entre `$OPTARG`, `$OPTIND` et une boucle `while getopts ... ; do case ... esac ; done`,
- la page ShellCheck : parcours les 5 codes d'erreur les plus fréquents (SC2086, SC2046, SC2181, SC2002, SC2164).

👉 **Livrable de lecture** : dans `tests/NOTES.md`, note en 3 lignes ce que fait chacun de ces codes. Tu les citeras au débrief.

---

### Étape 2 — Squelette CLI (12 min)

Crée `bin/logsentry.sh` avec **impérativement** :

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

Interface à implémenter :

| Option | Description | Défaut |
| -------- | ------------- | -------- |
| `-i, --input <file>` | fichier de logs (obligatoire) | — |
| `-f, --format <text\|json>` | format d'entrée | `text` |
| `-t, --threshold <ms>` | seuil « requête lente » en ms | `500` |
| `-n, --top <N>` | taille du top endpoints | `5` |
| `-v, --verbose` | trace sur stderr | off |
| `-h, --help` | usage + exit 0 | — |

**Exit codes imposés** : `0` OK · `1` usage invalide · `2` fichier introuvable/illisible · `3` format non supporté · `4` fichier vide ou aucune ligne valide.

Contraintes : supporte les options longues ET courtes, refuse les options inconnues, valide que `--top` et `--threshold` sont des entiers positifs (`^[0-9]+$`), et que `--input` existe et est lisible (`[[ -r "$input" ]]`).

---

### Étape 3 — Moteur d'analyse, mode texte (15 min)

`./bin/logsentry.sh -i data/access.log` doit produire exactement cette forme :

```
Fichier       : data/access.log
Requêtes      : 500
Erreurs 5xx   : 71 (14.20%)
Latence moy.  : 597 ms
Lentes (>500ms): 241
IPs en erreur : 10.0.0.11, 10.0.0.14

Top 5 endpoints:
  1. /api/users                 132  (26.40%)
  2. /health                    110  (22.00%)
  ...
```

Règles techniques :

- **Interdit** d'appeler `awk` plus d'une fois sur le fichier, ou de faire `cat fichier | grep ...`. Un `grep` + un `awk` maximum.
- L'agrégation du top et des compteurs se fait dans **le même `awk`** (tableau associatif + `END`).
- Le tri du top se fait par `sort -k2,2nr | head -n "$top"`, pas par une boucle Bash.
- `LC_ALL=C` pour la performance sur `sort`.

---

### Étape 4 — Mode JSON (10 min)

`./bin/logsentry.sh -i data/access.jsonl -f json` doit :

1. convertir la sortie en JSON **valide** (clés : `file`, `requests`, `error_rate`, `avg_latency_ms`, `slow_requests`, `top_endpoints[].path|count`),
2. rester composable : `./bin/logsentry.sh -i data/access.jsonl -f json | jq -r '.top_endpoints[0].path'` doit fonctionner.

Prouve-le : `./bin/logsentry.sh -i data/access.jsonl -f json | jq -e .` doit sortir sans erreur.

---

### Étape 5 — Robustesse & lint (8 min)

- `trap 'rm -f "$tmpfile"' EXIT INT TERM` si tu utilises un fichier temporaire (`mktemp`).
- Tous les `"$variables"` sont quotés ; aucun `eval`.
- Teste ces 4 cas et **note les exit codes obtenus** :

```bash
./bin/logsentry.sh                        ; echo $?   # attendu 1
./bin/logsentry.sh -i /nope.log           ; echo $?   # attendu 2
./bin/logsentry.sh -i data/access.log -f xml ; echo $? # attendu 3
./bin/logsentry.sh -i data/access.log -n zero ; echo $? # attendu 1
```

- Fais passer : `command -v shellcheck && shellcheck -S warning bin/logsentry.sh` → **0 warning**.

---

### Étape 6 — Commit (4 min)

```bash
git add bin/ tests/ .gitignore
git commit -m "feat(logsentry): CLI bash de résumé de logs (text/json)"
```

---

## 📚 Ressource recommandée

- **KodeKloud — Bash Scripting** (lab interactif getopts + gestion d'erreurs) : <https://kodekloud.com/courses/bash-scripting/>
- **Manuel Bash officiel — `getopts`** : <https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html#index-getopts>
- **ShellCheck** (à lancer en local) : <https://www.shellcheck.net/>
- **Manuel jq** : <https://jqlang.github.io/jq/manual/>
- **GNU awk** : <https://www.gnu.org/software/gawk/manual/gawk.html>

---

## 🧮 Grille de notation (100 pts)

| Dimension | Poids | Ce qui est évalué | 0 pt | Partiel | Plein |
| ----------- | ------- | ------------------- | ------ | --------- | ------- |
| **Implémentation** | **30 %** | Le script tourne, sortie conforme, les 4 cas de test passent | ne tourne pas | tourne partiellement | conforme + exit codes exacts |
| **Connaissance** | 15 % | Bon usage de `getopts`, `awk` (tableaux, `END`), `jq`, `sort/uniq` | API mal utilisée | usage correct mais détourné | usage idiomatique, justifié au débrief |
| **Design / lisibilité** | 15 % | Découpage en fonctions (`usage()`, `parse_args()`, `analyze_text()`, `analyze_json()`), nommage, zéro duplication | script plat | 1-2 fonctions | séparation nette + `main()` |
| **Debug / robustesse** | 15 % | `set -euo pipefail`, trap, validation d'entrées, cas limites (fichier vide, ligne malformée, N > nb endpoints) | crash silencieux | gère 1-2 cas | gère tous + messages sur stderr |
| **Sécurité** | 10 % | Quoting systématique, aucun `eval`, `mktemp` + trap, `grep --` / `-F` sur entrée non fiable | injection possible | quoting partiel | quoting complet + entrées neutralisées |
| **Explication** | 10 % | `tests/NOTES.md` + capacité à expliquer chaque ligne au débrief | rien | notes incomplètes | explique et critique ses choix |
| **Performance** | 5 % | Un seul passage awk, `LC_ALL=C`, pas de fork inutile | pipeline naïf | 1-2 optimisations | profil de coût justifié |

**Seuils** : ≥ 80 → notion validée · 60-79 → à consolider (revue ciblée) · < 60 → à refaire.

---

## ✅ Critères de réussite

- [x] `shellcheck -S warning bin/logsentry.sh` → **0 warning**.
- [x Les 4 exit codes attendus sont respectés (testés, pas supposés).
- [x] `-f text` et `-f json` donnent **les mêmes chiffres** sur le même jeu de données.
- [x] La sortie JSON est validée par `jq -e .`.
- [x] Au maximum **un** `awk` et **un** `grep` par exécution.
- [x] Le code contient au moins **4 fonctions** et un `main "$@"`.
- [x] Commit Git au message conventionnel.

## 🚀 Bonus (si tu termines avant 60 min)

1. Sous-commande `--compare <autre.log>` qui affiche le delta de taux d'erreur entre deux fichiers.
2. Détection des IP avec ≥ 3 erreurs 5xx **sans `grep`**, uniquement en `awk`.
3. Un test `tests/test_logsentry.bats` (si `bats` est installé) couvrant les cas limites.

## 🎤 Questions de débrief (5 min)

1. Pourquoi `set -e` **seul** ne suffit-il pas dans un pipeline ? Que change `pipefail` ?
2. Pourquoi `awk` est-il structurellement plus rapide que `grep | cut | sort | uniq` sur 1 M de lignes ?
3. Où ton script casserait-il si un chemin d'endpoint contenait `; rm -rf /` ? Comment l'as-tu neutralisé ?
4. Si je te demandais de le conteneuriser demain, qu'est-ce qui manquerait à ce script pour être « prêt pour la prod » ? *(→ amorce de l'incrément 2 : Docker)*
