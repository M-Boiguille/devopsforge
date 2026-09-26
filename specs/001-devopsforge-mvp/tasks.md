# Tasks: DevOpsForge MVP

- [x] T1 Constitution : écrire `.specify/memory/constitution.md` (principes DevOpsForge)
- [x] T2 Config : `config/thresholds.yaml`, `grading_weights.yaml`, `forgetting.yaml`, `agent.yaml`
- [x] T3 Profil : `profile/linux.yaml` (bash_scripting, file_parsing) + 6 placeholders de domaine
- [x] T4 Données : `dues.yaml` vide, `errors.log`, `exercises/.gitkeep`, `journal.md`
- [x] T5 Script `scripts/update_profile.py` (parse front-matter, MAJ profil, due_at Ebbinghaus, dues.yaml)
- [x] T6 Script `scripts/select_due_notions.py` (tri priorité + ancienneté)
- [x] T7 Workflow `generate-exercise.yml` (dispatch + cron, LLM Flash, PR bot)
- [x] T8 Workflow `analyze-session.yml` (pull_request, lint flake8/shellcheck + LLM Pro + approve)
- [x] T9 Workflow `update-profile.yml` (push main + dispatch, PR bot)
- [x] T10 Prompts `.github/prompts/generate-exercise.md` (3-8 notions) et `evaluate-submission.md` (JSON strict)
- [x] T11 `AGENTS.md` + `README.md` (secrets, protection branche, flux PR, ajout de notion)
- [x] T12 Fixture de test + exécution des scripts (validation pyyaml)

## Différé (hors MVP)

- [ ] `scripts/apply_decay.py` : décroissance quotidienne (nice-to-have, non câblé)
- [ ] OpenClaw (socratique/Feynman), WakaTime/ActivityWatch, NotebookLM, entretien simulé
