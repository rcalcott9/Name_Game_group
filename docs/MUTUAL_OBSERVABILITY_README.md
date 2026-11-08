# Mutual Observability Experiment (Study 2)

This is the implementation of the **mutual observability manipulation** described in the CogSci paper "Mutual Observability Determines When Precedent is Moralized in Multi-Agent Coordination Games."

## Overview

This experiment tests how mutual observability of others' choices affects:
1. Willingness to switch from established precedent to better alternatives
2. Moral evaluations of sticking with vs. abandoning precedent

## Two Experimental Conditions

### 1. Mutual Observability (MO) - `name_game_feedback/`
- Participants see **ALL 6 players' choices after EVERY round** (rounds 1-14)
- Players can observe when others start switching to M or N
- Enables gradual coordination on new, better equilibria

### 2. No Mutual Observability (No MO) - `name_game_no_feedback/`
- Participants see choices **only in rounds 1-7**
- **NO feedback in rounds 8-13**
- Final results shown at round 14 only
- Makes switching risky since you can't see if others are also switching

## Game Structure

### Rounds 1-7: Establish Precedent
- Only letter **J** worth points (10 points)
- All other letters worth 0
- Both conditions show feedback after each round
- Groups converge on choosing J

### Rounds 8-14: New Options Available
- **J** = 10 points (old equilibrium)
- **M** = 15 points (new, better option)
- **N** = 15 points (new, better option)
- All other letters = 0 points

**KEY MANIPULATION:**
- **MO condition**: Continue seeing all choices → can coordinate on M or N
- **No MO condition**: No feedback → can't tell if others are switching

## Expected Results (per paper)

### Behavioral:
- **MO condition**: Higher switching rate to M/N (mutual observability enables coordination)
- **No MO condition**: Lower switching rate (too risky without feedback)

### Moral Judgments:
- **MO condition**: Sticking to J is morally worse (foregoes achievable mutual benefit)
- **No MO condition**: Sticking to J is morally better (maintains coordination)

## Implementation Details

### Group Size
- 6 players per group (all must coordinate for anyone to earn points)

### Treatment Assignment
- Randomly assigned via `participant.vars['treatment']`:
  - `'feedback'` → MO condition
  - `'no_feedback'` → No MO condition

### App Sequence
```python
app_sequence=['consent', 'Intro', 'name_game_feedback', 'name_game_no_feedback', 'End_name']
```

Each app checks the treatment variable and only displays for the assigned condition.

## Files

- `name_game_feedback/__init__.py` - Mutual Observability condition
- `name_game_feedback/Results.html` - Shows all 6 choices after each round
- `name_game_no_feedback/__init__.py` - No Mutual Observability condition
- `name_game_no_feedback/Results.html` - Only shows results in rounds 1-7 and 14
- `consent/` - Consent form with treatment randomization
- `Intro/` - Instructions (same for both conditions)
- `End_name/` - Post-game moral judgment questions

## Key Code Differences

### Mutual Observability (MO)
```python
def is_displayed(player):
    if player.participant.vars.get('treatment') != 'feedback':
        return False
    # Results page shows EVERY round
    return True
```

### No Mutual Observability (No MO)
```python
def is_displayed(player):
    if player.participant.vars.get('treatment') != 'no_feedback':
        return False
    # Results page ONLY shows rounds 1-7 and 14
    if player.round_number >= 8 and player.round_number < 14:
        return False
    return True
```

## Running the Experiment

### Test Mode
See session configs for test versions

### Live Mode
Use the main `name_game` session config with 6 participants minimum

## Citation

Anonymous CogSci Submission (2026). "Mutual Observability Determines When Precedent is Moralized in Multi-Agent Coordination Games."
