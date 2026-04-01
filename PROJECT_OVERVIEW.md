# Name Game Experiments - Project Overview

**Repository**: Group_Name_Game
**Location**: `~/Documents/GitHub/Group_Name_Game/`
**Based on**: [Centola & Baronchelli (2015) Science paper](https://www.science.org/doi/10.1126/science.aas8827)

---

## 🎯 MAIN STUDY: Mutual Observability Experiments (Study 2)

### Research Question
How does mutual observability of others' choices affect:
1. Willingness to switch from established precedent to better alternatives?
2. Moral evaluations of sticking with vs. abandoning precedent?

### Two Experimental Conditions

#### 1. Mutual Observability (MO) - `name_game_feedback/`
- Participants see **ALL 6 players' choices after EVERY round** (rounds 1-14)
- Players can observe when others start switching to M or N
- Enables gradual coordination on new, better equilibria
- **Expected**: Higher switching rate, sticking to J judged morally worse

#### 2. No Mutual Observability (No MO) - `name_game_no_feedback/`
- Participants see choices **only in rounds 1-7**
- **NO feedback in rounds 8-13** (blind coordination period)
- Final results shown at round 14 only
- Makes switching risky since you can't see if others are switching
- **Expected**: Lower switching rate, sticking to J judged morally better

### Game Structure

**Group Size**: 6 players per group (all must coordinate for payoff)
**Total Rounds**: 14

#### Rounds 1-7: Establish Precedent
- Only letter **J** worth points (10 points)
- All other letters worth 0 points
- **Both conditions** show feedback after each round
- Groups converge on choosing J

#### Rounds 8-14: New Options Available
- **J** = 10 points (old equilibrium)
- **M** = 15 points (new, better option - 50% more valuable)
- **N** = 15 points (new, better option - 50% more valuable)
- All other letters = 0 points

**Critical Manipulation**:
- **MO condition**: Continue seeing all 6 choices → can coordinate switch
- **No MO condition**: No feedback → blind coordination challenge

### Implementation Details

**Files**:
- `name_game_feedback/__init__.py` - MO condition logic
- `name_game_feedback/Results.html` - Shows all 6 choices every round
- `name_game_no_feedback/__init__.py` - No MO condition logic
- `name_game_no_feedback/Results.html` - Only shows results rounds 1-7 and 14
- `consent/` - Consent form with treatment randomization
- `Intro/` - Shared instructions
- `End_name/` - Post-game moral judgment questions

**Treatment Assignment**:
- Random via `participant.vars['treatment']`
- `'feedback'` → MO condition
- `'no_feedback'` → No MO condition

**App Sequence**:
```python
['consent', 'Intro', 'name_game_feedback', 'name_game_no_feedback', 'End_name']
```
Each app checks treatment and only displays for assigned condition.

**See**: `MUTUAL_OBSERVABILITY_README.md` for technical details

---

## 📁 Other Experiments in This Repo

### Secondary Studies

#### 1. `name_game_incentivized/`
- **Design**: Dyadic (2 players) vs Group (4 players) conditions
- **Rounds**: 14
- **Payoffs**: J=10 (rounds 1-7), then J=10, M=15, N=15 (rounds 8-14)
- **Key Feature**: Tests group size effects on coordination
- **Session Config**: `name_game_incentivized`

#### 2. `Dyad_Name_Game/`
- **Design**: Fixed pairs throughout experiment
- **Players**: 2 per pair
- **Rounds**: 14
- **Payoffs**: J=10, then M=15, Q=15 after round 7
- **Key Feature**: No reshuffling, stable partnerships
- **Session Config**: `dyad_name_game`

#### 3. `name_game/`
- **Design**: Unified session with random assignment
- **Players**: 4 (can form 2 dyadic pairs or 1 group of 4)
- **Key Feature**: Mixed conditions within same session
- **Session Config**: `name_game`

#### 4. `name_game_no_partner/` (Deception Study)
- **Design**: Single-player with simulated partner
- **Rounds**: 15
- **Two Treatments**:
  - **Control**: Partner always chooses J (after 3 random rounds)
  - **Experimental**: Partner chooses J (rounds 4-12), switches to C (rounds 13-15)
- **Purpose**: Test adaptation to norm shifts in controlled environment
- **Session Config**: `name_game_no_partner`

### Pilot/Archived Studies

Located in `_unused_apps/`:
- `name_game_simple` - 10-round simplified version
- `name_game_4` - Treatment version with partner feedback
- Original 30-round variants

---

## 🗂 Repository Structure

```
Group_Name_Game/
├── settings.py                          # oTree session configurations
├── requirements.txt                     # Python dependencies
├── .gitignore                          # Ignore pycache, db, etc.
│
├── PROJECT_OVERVIEW.md                 # This file
├── MUTUAL_OBSERVABILITY_README.md      # Study 2 technical details
├── AGENT_EXPERIMENT_README.md          # AI agent experiments
├── TESTING_INSTRUCTIONS.md             # How to test experiments
│
├── consent/                            # Consent & treatment assignment
├── Intro/                              # Shared instructions
├── End_name/                           # Post-game questions
├── End_no_partner/                     # Deception study ending
│
├── name_game_feedback/                 # 🎯 MO condition (MAIN STUDY)
├── name_game_no_feedback/              # 🎯 No MO condition (MAIN STUDY)
├── name_game_incentivized/             # Dyadic vs Group study
├── Dyad_Name_Game/                     # Fixed pairs study
├── name_game/                          # Unified random assignment
├── name_game_no_partner/               # Single-player deception
│
├── _unused_apps/                       # Archived/pilot experiments
│
├── analyze_data.R                      # Main R analysis script
├── name_game_analysis_updated.R        # Updated analysis
├── name_game_incentivized.R            # Incentivized study analysis
├── *.png, *.html                       # Analysis outputs/plots
│
└── venv/                               # Python virtual environment
```

---

## 🚀 Running Experiments

### Development Server
```bash
cd ~/Documents/GitHub/Group_Name_Game
source venv/bin/activate
otree devserver
```

### Session Configs (in settings.py)

**Main Study**:
- Default config runs both MO conditions with random assignment

**Test Modes**:
- `test_incentivized_dyadic` - Solo test of dyadic condition
- `test_incentivized_group` - Solo test of group condition
- `test_dyad_bot` - Solo test with bot partner
- `test_dyadic` - 2-player dyadic test
- `test_group` - 4-player group test

### Prolific Integration
All experiments include Prolific completion links:
- Live studies: Custom completion codes in session configs
- Assigned in `settings.py` per experiment

---

## 📊 Analysis Files

### R Scripts
- `analyze_data.R` - Main analysis pipeline
- `name_game_analysis_updated.R` - Updated version
- `name_game_incentivized.R` - Incentivized study analysis

### Python Analysis
- `analyze_agent_results.py` - AI agent behavior analysis
- `analyze_time_management.py` - Timing/duration analysis
- `extract_activity_data.py` - Activity extraction
- `visualize_time_management.py` - Time visualizations

### Data Files
- `name_game_long.csv` - Long-format experiment data
- `name_game_long_with_groups.csv` - With group identifiers
- Various test CSVs for validation

### Plots/Visualizations
- `coordination_rates.png`
- `letter_choice_*.png`
- `moral_evaluations_*.png`
- `heatmap_*.png`
- Interactive HTML plots

---

## 🔧 Technical Details

### oTree Version
- oTree 5.x (check `requirements.txt`)

### Key Dependencies
```
otree
pandas
numpy
```

### Database
- SQLite (`db.sqlite3`) - auto-generated, not tracked in git
- Contains participant data - never commit to git

### Environment Variables
- `OTREE_ADMIN_PASSWORD` - Set via environment
- `secrets.env` - Not tracked in git (contains API keys)

---

## 📝 Important Notes

### Git Workflow
- **Main branch**: production-ready code
- **Commits**: All local changes, ready to push
- **.gitignore**: Configured to exclude pycache, db, secrets

### Data Privacy
- Never commit `db.sqlite3` (contains participant data)
- Never commit `secrets.env`
- Be careful with CSV exports containing PII

### Testing
- Always test in `test_mode=True` before live deployment
- Use solo testing modes for rapid iteration
- See `TESTING_INSTRUCTIONS.md` for details

---

## 🎓 Related Publications

### Main Theory Paper
**Study 2** (Mutual Observability) is from:
- **Anonymous CogSci Submission (2026)**. "Mutual Observability Determines When Precedent is Moralized in Multi-Agent Coordination Games."

### Original Name Game
- Centola, D., & Baronchelli, A. (2015). "The spontaneous emergence of conventions: An experimental study of cultural evolution." *Science*, 348(6240), 1130-1133.
  - https://www.science.org/doi/10.1126/science.aas8827

---

## 📞 Contact & Collaboration

**Primary Researcher**: Calypso Calcott
**Collaborators**:
- AnitaB75 (Moral_Coordination repo)

**Other Repos**:
- `~/Documents/GitHub/Moral_Coordination/` - Collaborator's fork with additional variants

---

## ⚙️ Common Tasks

### Add New Experiment Variant
1. Copy existing app folder (e.g., `name_game_feedback/`)
2. Modify `__init__.py` logic
3. Update templates as needed
4. Add session config to `settings.py`
5. Test with solo mode first

### Update Main Study
- Edit `name_game_feedback/` or `name_game_no_feedback/`
- Check `MUTUAL_OBSERVABILITY_README.md` for logic
- Test both conditions

### Export Data
```bash
otree exportdata
```
Data exports to CSV automatically

### Clean Database
```bash
otree resetdb
```
**Warning**: Deletes all participant data!

---

## 🔄 Recent Changes

### 2026-04-01
- ✅ Consolidated `otree_code/name_game_no_partner/` into main repo
- ✅ Added deception study to session configs
- ✅ Updated `.gitignore` for better organization
- ✅ Created `PROJECT_OVERVIEW.md` for future reference

### Previous Updates
- 2026-03-06: Added mutual observability experiments (Study 2)
- 2026-01-15: Analysis updates and visualizations
- 2025-11-13: Incentivized version with dynamic scoring

---

**Last Updated**: 2026-04-01
**For Questions**: Refer to this file in Claude Code conversations
