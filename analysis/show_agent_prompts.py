"""Show exactly what prompts agents receive in both conditions."""

from claude_agent_utils import create_game_context_prompt

# Simulate agent history
past_choices_feedback = [
    # Rounds 1-7: All coordinated on J
    {'round': 1, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 2, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 3, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 4, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 5, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 6, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    {'round': 7, 'my_choice': 'J', 'all_choices': ['J','J','J','J','J','J'], 'points': 10},
    # Round 8: Agent chose M, coordinated (but doesn't know others' choices yet in prompt)
    {'round': 8, 'my_choice': 'M', 'all_choices': ['M','M','M','M','M','M'], 'points': 15},
    # Round 9: Agent chose M, failed coordination
    {'round': 9, 'my_choice': 'M', 'all_choices': ['M','M','N','M','M','M'], 'points': 0},
]

past_choices_no_feedback = past_choices_feedback.copy()

point_values_late = {'J': 10, 'M': 15, 'N': 15, 'P': 0, 'R': 0, 'C': 0, 'D': 0, 'Q': 0, 'X': 0, 'Y': 0, 'F': 0}

print("\n" + "="*80)
print("MUTUAL OBSERVABILITY (FEEDBACK) - ROUND 10")
print("="*80)
prompt_feedback = create_game_context_prompt(
    round_number=10,
    treatment='feedback',
    available_letters=['J', 'M', 'N'],
    point_values=point_values_late,
    past_choices=past_choices_feedback,
    current_points=85  # 7x10 + 15 + 0
)
print(prompt_feedback)

print("\n\n" + "="*80)
print("NO MUTUAL OBSERVABILITY (NO FEEDBACK) - ROUND 10")
print("="*80)
prompt_no_feedback = create_game_context_prompt(
    round_number=10,
    treatment='no_feedback',
    available_letters=['J', 'M', 'N'],
    point_values=point_values_late,
    past_choices=past_choices_no_feedback,
    current_points=85  # Same starting point, but they don't actually know their real total
)
print(prompt_no_feedback)

print("\n\n" + "="*80)
print("KEY DIFFERENCES:")
print("="*80)
print("\n1. MUTUAL OBSERVABILITY (Round 8-10):")
print("   - Sees all 6 players' choices")
print("   - Knows if coordination succeeded or failed")
print("   - Can observe emerging patterns (e.g., some switching to N)")
print("\n2. NO MUTUAL OBSERVABILITY (Round 8-10):")
print("   - Only sees OWN choice")
print("   - NO feedback on points earned")
print("   - Cannot tell if others are switching or sticking to J")
print("   - Must decide blindly based on precedent from rounds 1-7")
print("\n" + "="*80)
