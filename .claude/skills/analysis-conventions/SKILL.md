---
name: analysis-conventions
description: >
  R and Python analysis conventions for behavioral economics research.
  Use when writing, editing, or debugging analysis scripts. Use when
  the user asks to analyze data, run statistics, create plots, clean data,
  or work with CSV exports from oTree.
---

## Script Structure

Every analysis script should follow this order:
1. Load packages
2. Read data (relative path from project root)
3. Clean and filter (exclusions, recoding)
4. Analyze (models, tests)
5. Visualize
6. Save outputs to `plots/`

## Paths

```r
# Always relative from project root
data <- read_csv("data/all_apps_wide-2026-01-12-6.csv")
ggsave("plots/coordination_rates.png")
```

Never use absolute paths or `~/Downloads/`.

## Data Conventions

- oTree exports are wide format — one row per participant per round
- Key ID columns: `participant.code`, `session.code`, `group.id_in_subsession`
- Treatment variable: `participant.vars['treatment']` exports as a column
- Round number: `player.round_number` or `subsession.round_number`
- Convert wide to long when needed for repeated-measures analysis

## Study-Specific Variables

**Mutual Observability (Study 2):**
- Treatment: `feedback` (MO) vs `no_feedback` (No MO)
- DV: choice per round (J, M, N, etc.), coordination rate
- Rounds 1-7: both conditions see feedback; Rounds 8-13: MO diverges from No MO
- Group size: 6

**Coordination Moralization:**
- Condition: `solo` (asymmetric knowledge) vs `coordination` (mutual knowledge)
- DV: moral wrongness judgments (Likert scale)
- Format: third-person observation, solo participant

## Plotting

- Save all plots to `plots/` with descriptive names
- Use `coordination_rates.png` style naming, not `plot1.png`
- For interactive plots, save as HTML with `_interactive` suffix
