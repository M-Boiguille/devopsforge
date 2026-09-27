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
