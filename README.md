# Group Name Game

A customized version of the Name Game coordination experiment based on the original Science paper: https://www.science.org/doi/10.1126/science.aas8827

## Overview
This is a multiplayer coordination experiment where participants choose letters and try to coordinate with their partners across multiple rounds.

## Experiment Variants
- **name_game**: Original 30-round version with 4 players per group
- **name_game_simple**: Simplified 10-round version
- **name_game_no_partner**: Solo version with simulated partners
- **name_game_4**: Treatment version with partner feedback

## Setup
1. Create virtual environment: `python -m venv venv`
2. Activate: `source venv/bin/activate` (Mac/Linux) or `venv\Scripts\activate` (Windows)
3. Install requirements: `pip install -r requirements.txt`
4. Run server: `otree devserver`

## Structure
- `Intro/`: Consent and instructions
- `name_game/`: Main coordination game
- `End_name/`: Post-game surveys and debrief
- `settings.py`: Experiment configuration

## Notes
This is a fork/clone for custom development and research purposes.