---
name: project-guide
description: >
  Project structure and file conventions for the Group_Name_Game repository.
  Use whenever creating, moving, or looking for files in this repo. Use when
  asked where something is, when saving new scripts or data, or when the user
  says "where does this go."
---

## Repository Layout

```
Group_Name_Game/
├── data/              # All CSV data files. Never overwrite raw exports.
├── plots/             # All visualizations (PNG, HTML, PDF)
├── analysis/          # All R and Python analysis scripts
├── docs/              # All documentation and READMEs
├── [experiment apps]/ # oTree app folders (root level, oTree requirement)
├── _unused_apps/      # Archived/legacy experiments
├── _static/           # oTree static files
├── _templates/        # oTree shared templates
├── settings.py        # oTree session configurations
└── Procfile           # Heroku deployment config
```

## File Rules

- Data files always go in `data/`, plots in `plots/`, scripts in `analysis/`, docs in `docs/`.
- Always use relative paths from project root: `data/filename.csv`, never `~/Downloads/filename.csv`.
- Raw data exports are immutable — never overwrite, always save new versions with dates.
- Data naming: `[source]_[date]_[version].csv`
- Plot naming: `[type]_[description].png` or `plot#_[description].html`

## What NOT to commit

- `db.sqlite3` (participant data)
- `secrets.env` (API keys)
- `__pycache__/`
- Any file with PII

## Active Experiment Apps

- `mutual_observability/` — Study 2: MO vs No MO, 6-player groups
- `coordination_moralization/` — Third-person moral judgment study
- `name_game_incentivized/` — Dyadic vs group size manipulation
- `Dyad_Name_Game/` — Fixed pairs study
- `name_game_no_partner/` — Deception study with bot partner

Shared components: `consent/`, `Intro/`, `End_name/`, `End_no_partner/`

## Testing Experiments

When setting up or modifying experiments, always provide a list of clickable localhost links for every condition and test mode so the user can quickly test each one. Format like:

```
Test links:
- MO condition: http://localhost:8000/demo/test_mutual_observability_feedback
- No MO condition: http://localhost:8000/demo/test_mutual_observability_no_feedback
- Full random assignment: http://localhost:8000/demo/test_mutual_observability
```

Include links for every between-subjects condition separately, plus the randomized version. Always check `settings.py` for the actual session config names.

## Finding Things

- Experiment code → root-level app folder or `_unused_apps/` if archived
- Data → `data/`, look for `all_apps_wide-[date].csv`
- Analysis → `analysis/`, look for `[study_name]_analysis.R`
- Plots → `plots/`
- Session configs → `settings.py`
- App logic → `[app_name]/__init__.py`
