"""Debug script to see what prompts agents actually receive."""

from claude_agent_utils import create_game_context_prompt

# Simulate round 10 in no_feedback condition
# Agent has history from rounds 1-9

past_choices = [
    {'round': 1, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 2, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 3, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 4, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 5, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 6, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 7, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 8, 'my_choice': 'M', 'points': 15},  # No all_choices in round 8+
    {'round': 9, 'my_choice': 'M', 'points': 15},
]

point_values = {'J': 10, 'M': 15, 'N': 15, 'P': 0, 'R': 0, 'C': 0, 'D': 0, 'Q': 0, 'X': 0, 'Y': 0, 'F': 0}

prompt = create_game_context_prompt(
    round_number=10,
    treatment='no_feedback',
    available_letters=['J', 'M', 'N'],
    point_values=point_values,
    past_choices=past_choices,
    current_points=100
)

print("="*60)
print("PROMPT FOR ROUND 10 (NO FEEDBACK CONDITION)")
print("="*60)
print(prompt)
print("="*60)
