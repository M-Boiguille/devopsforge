# Quickstart: Valider DevOpsForge MVP de bout en bout

## Prérequis

- Python 3.11+ avec `pyyaml` : `pip install pyyaml requests python-dateutil`

## 1. Tester les scripts en local

```bash
# Fixture d'analyse fournie pour le test
cp scripts/../tests/fixtures/analysis-sample.md /tmp/analysis.md

# (a) Mise à jour du profil depuis l'analyse
python3 scripts/update_profile.py --analysis /tmp/analysis.md

# (b) Décroissance quotidienne
python3 scripts/apply_decay.py

# (c) Sélection des notions dues
python3 scripts/select_due_notions.py --limit 3
```

Résultats attendus : `profile/linux.yaml` contient des scores mis à jour bornés `[0,1]`, `due_at` est une date
future, `dues.yaml` reflète les notions fragiles, et `select_due_notions.py` imprime les notions prioritaires.

## 2. Déclencher le premier exercice (GitHub)

1. Configurer les secrets : `AI_GATEWAY_API_KEY`, `GH_TOKEN` (voir README).
2. Actions → `generate-exercise` → Run workflow.
3. Vérifier que `sessions/YYYY-MM-DD-exercise.md` est créé et committé.

## 3. Soumettre et analyser

1. Résoudre l'exercice, remplir l'auto-évaluation dans `sessions/YYYY-MM-DD-submission.md`.
2. Pousser : le workflow `analyze-session` produit `sessions/YYYY-MM-DD-analysis.md`.
3. Lancer `update-profile` (ou `scripts/update_profile.py` en local) pour mettre à jour le profil.

## 4. Vérifier

- `git log --oneline -5` : commits conventionnels (`feat:`, `chore:`, …).
- `python3 -c "import yaml; yaml.safe_load(open('profile/linux.yaml')); yaml.safe_load(open('dues.yaml'))"` sans erreur.
- Aucun secret dans le diff (`git diff HEAD~1`).
