# Claude Agents Mutual Observability Experiment

This folder contains code to run the mutual observability experiment with Claude AI agents instead of human participants.

## Purpose

Test whether Claude agents show similar behavioral and moral judgment patterns as humans:
- **Behavioral**: Do agents in MO condition switch to better equilibria (M/N) more than No MO?
- **Moral**: Do agents judge sticking vs. switching differently by condition?
- **Reasoning**: What strategies do agents articulate?

## Setup

### 1. Install Requirements

```bash
pip install -r requirements.txt
```

This will install:
- `otree` - For potential oTree integration
- `anthropic` - For Claude API

### 2. Set API Key

```bash
export ANTHROPIC_API_KEY='your-anthropic-api-key'
```

Or add to your `.bash_profile` / `.zshrc`:
```bash
echo "export ANTHROPIC_API_KEY='your-key'" >> ~/.zshrc
source ~/.zshrc
```

## Running Experiments

### Basic Usage

Run one session (6 agents, 14 rounds) in Mutual Observability condition:
```bash
python run_agent_experiment.py --treatment feedback --output results_mo.csv
```

Run one session in No Mutual Observability condition:
```bash
python run_agent_experiment.py --treatment no_feedback --output results_no_mo.csv
```

### Multiple Sessions

Run 10 sessions of each condition:
```bash
python run_agent_experiment.py --treatment feedback --output results_mo.csv --n-sessions 10
python run_agent_experiment.py --treatment no_feedback --output results_no_mo.csv --n-sessions 10
```

### Custom Session IDs

```bash
python run_agent_experiment.py --treatment feedback --output results.csv --session-id "pilot_1"
```

## Output Format

Results are saved as CSV with columns:
- `session_id`: Unique session identifier
- `treatment`: 'feedback' or 'no_feedback'
- `agent_id`: Agent number (1-6)
- `round`: Round number (1-14)
- `choice`: Letter chosen by this agent
- `all_choices`: All 6 agents' choices (comma-separated)
- `coordinated`: Boolean - did all 6 agents coordinate?
- `round_points`: Points earned this round
- `total_points`: Cumulative points

## Files

### Core Implementation
- `claude_agent_utils.py` - API integration and prompt templates
- `run_agent_experiment.py` - Main experiment runner script

### Analysis (to be added)
- `analyze_agent_results.py` - Compare agent vs. human behavior
- `plot_agent_results.R` - Visualizations

## Experiment Design

### Game Structure

**Rounds 1-7: Establish Precedent**
- Only **J** worth 10 points
- Both conditions show feedback
- Agents should converge on J

**Rounds 8-14: New Options Available**
- **J** = 10 points (precedent)
- **M** = 15 points (new, better)
- **N** = 15 points (new, better)

**Treatment Manipulation:**
- **MO (feedback)**: Agents see all 6 choices after every round
- **No MO (no_feedback)**: Agents see choices rounds 1-7 only, then blind until round 14

### Agent Prompts

Agents receive:
1. Game rules (6 players, all must coordinate)
2. Current round number
3. Point values for this round
4. Their current total points
5. History of past rounds:
   - MO: All past rounds with all 6 choices visible
   - No MO: Rounds 1-7 with choices, rounds 8-13 without choices

Agents are asked to "Think strategically" about patterns and coordination.

## Expected Results

Based on human data from the paper:

### Behavioral (Switching Rates)
- **MO agents**: Higher switching to M/N in rounds 8-14
- **No MO agents**: Lower switching (stick to J)

### Reasoning
- **MO agents**: "I can see others are switching to M, so I'll join them"
- **No MO agents**: "Can't see what others are doing, safer to stick to J"

## Next Steps

1. Run pilot sessions (5 each condition)
2. Analyze switching patterns
3. Add moral judgment questions post-game
4. Compare with human data
5. Test variations (different models, temperatures, prompts)

## Cost Estimates

Using Claude 3.5 Sonnet:
- ~100 tokens per choice
- 6 agents × 14 rounds = 84 choices per session
- ~8,400 tokens per session
- At $3/$15 per 1M tokens: ~$0.03-0.13 per session

10 sessions per condition = ~$0.60-2.60 total

## Troubleshooting

**API Key Error:**
```
ERROR: ANTHROPIC_API_KEY environment variable not set
```
→ Make sure to export your API key (see Setup above)

**Import Error:**
```
ModuleNotFoundError: No module named 'anthropic'
```
→ Run `pip install -r requirements.txt`

**Invalid Letter Choice:**
The script has fallback logic to default to 'J' if the model returns an invalid choice, but this should be rare with proper prompting.
