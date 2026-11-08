# Human-participant Name Game experiments

One folder per experiment, named by launch date. Each `code/` folder is a **complete, self-contained oTree project** — that is the folder you upload via Cyberduck. `settings.py` in each is trimmed to only that experiment's session configs.

| launched | experiment | participants | status |
|---|---|---|---|
| `2025-10-14` | [Dyad Name Game](2025-10-14_dyad_name_game/) | — | built, never run |
| `2025-11-12` | [Incentivized Name Game](2025-11-12_name_game_incentivized/) | 200 | collected |
| `2026-01-12` | [Name Game - feedback vs no-feedback](2026-01-12_name_game_feedback_vs_no_feedback/) | 350 | collected |
| `2026-04-01` | [Name Game No Partner (deception study)](2026-04-01_name_game_no_partner/) | — | built, never run |
| `2026-04-07` | [Coordination Moralization (third-person)](2026-04-07_coordination_moralization/) | — | built, never run |
| `2026-04-15` | [Mutual Observability](2026-04-15_mutual_observability/) | — | built, never run |

## Deploying one

```bash
cd <experiment>/code
cp secrets.env.example secrets.env    # fill in on the server
otree zip                             # or upload the folder contents directly
```

> `secrets.env` is never included in these folders — it holds live API keys.

Rebuild with `python3 tools/build_experiment_folders.py --force`.
Source of truth stays the repo root; these are copies.
