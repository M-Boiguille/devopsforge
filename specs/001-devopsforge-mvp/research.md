# Research: DevOpsForge MVP

## Décision 1 : Format du rapport d'analyse (`analysis.md`)

**Décision** : Front-matter YAML machine-readable (délimité par `---`) + corps Markdown lisible.

**Rationnel** : `update_profile.py` doit parser des scores de façon fiable. Un front-matter YAML (chargé via
`pyyaml`) évite tout parsing fragile de tableaux Markdown, tout en conservant un corps Markdown pour la lecture
humaine et OpenClaw (plus tard).

**Alternatives envisagées** :
- Tableau Markdown strict → fragile (variabilité de rendu), parsing regex coûteux.
- Fichier YAML séparé `analysis.yaml` → duplique l'information, deux fichiers à maintenir.

## Décision 2 : Calcul de `due_at` (spaced repetition)

**Décision** : `due_at = last_reviewed + jours`, où `jours = ln(score / review_threshold) / rate`, borné `[1, 30]`.

**Rationnel** : La courbe d'Ebbinghaus `score * exp(-rate * jours)` donne directement le nombre de jours avant
que le score retombe sous `review_threshold` (0.80). C'est une utilisation cohérente et défendable de la formule
fournie dans `forgetting.yaml`, sans inventer de calendrier arbitraire.

**Alternatives envisagées** :
- Intervalles fixes (1/3/7/14 jours) → ne respecte pas la formule d'Ebbinghaus demandée.
- SM-2 complet → sur-ingénierie pour le MVP.

## Décision 3 : Mise à jour des scores (moyenne mobile)

**Décision** : `nouveau_score = 0.7 * score_analyse + 0.3 * score_existant` si une valeur existe, sinon
`score_analyse` directement. Clamp `[0,1]`.

**Rationnel** : Le score de l'analyse reflète l'état actuel mais une moyenne pondérée lisse la volatilité
d'une seule évaluation. La dimension absente de l'analyse conserve son ancien score.

**Alternatives envisagées** :
- Remplacer systématiquement par le score d'analyse → volatil, perd l'historique.
- Moyenne 50/50 → donne trop de poids au passé.

## Décision 4 : Passerelle IA

**Décision** : Appel HTTP OpenAI-compatible (`POST {base_url}/chat/completions` avec `Authorization: Bearer`).
`base_url` et `model` lus depuis variables/env, clé depuis secret `AI_GATEWAY_API_KEY`.

**Rationnel** : L'utilisateur a confirmé un placeholder OpenAI-compatible. C'est le standard de facto et permet
de brancher n'importe quelle passerelle (LiteLLM, VPS OCI, DeepSeek officiel) sans modifier le code.

**Alternatives envisagées** :
- SDK OpenAI → dépendance inutile, `requests` suffit.
- Endpoint propriétaire DeepSeek → non, l'utilisateur veut une passerelle.

## Décision 5 : Détection d'anti-patterns (lint côté CI)

**Décision** : `analyze-session.yml` exécute `flake8` (Python) et `shellcheck` (Bash) si présents, puis une
détection par motifs regex (`hardcoded_secret`, `latest_tag`, etc.) listée dans `thresholds.yaml` et transmise
au prompt d'évaluation.

**Rationnel** : Séparation des rôles (section 2 de la mission) : le lint/tests restent déterministes et rapides
dans l'Action, sans appel LLM. Les anti-patterns détectés sont injectés dans le prompt LLM comme contexte.

**Alternatives envisagées** :
- Tout déléguer au LLM → non déterministe, coûteux.
- Outil SAST lourd → hors périmètre MVP.

## Décision 6 : Idempotence des workflows

**Décision** : Chaque workflow utilise `actions/checkout` + un commit dédié. Les scripts sont idempotents
(dernière analyse écrase, `last_reviewed` = date du jour). Les commits automatisés utilisent un token
fine-grained (secret `GH_TOKEN`) sur compte séparé pour ne pas casser les autres workflows.

**Rationnel** : Relancer un workflow ne doit pas produire d'état incohérent ni de boucle infinie. L'usage d'un
PAT dédié (plutôt que `GITHUB_TOKEN`) évite de ne pas déclencher les autres workflows sur push.
