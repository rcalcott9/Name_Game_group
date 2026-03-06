"""
Utility functions for running Claude agents in the mutual observability experiment.
"""

import anthropic
import os
from typing import List, Dict, Optional


def get_claude_client():
    """Initialize Anthropic client with API key from environment."""
    api_key = os.environ.get('ANTHROPIC_API_KEY')
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY environment variable not set")
    return anthropic.Anthropic(api_key=api_key)


def create_game_context_prompt(
    round_number: int,
    treatment: str,
    available_letters: List[str],
    point_values: Dict[str, int],
    past_choices: Optional[List[Dict]] = None,
    current_points: int = 0
) -> str:
    """
    Create the context prompt for an agent making a letter choice.

    Args:
        round_number: Current round (1-14)
        treatment: 'feedback' or 'no_feedback'
        available_letters: List of letters that earn points this round
        point_values: Dict mapping letters to point values
        past_choices: List of dicts with 'round', 'my_choice', 'all_choices', 'points'
        current_points: Agent's current total points
    """

    prompt = f"""You are participating in a coordination game with 5 other players (6 players total).

GAME RULES:
- The game has 14 rounds
- Each round, all 6 players simultaneously choose one letter from: Q, M, N, X, Y, F, J, P, R, C, D
- You earn points ONLY if all 6 players choose the same letter
- If all 6 players coordinate, everyone earns the points for that letter
- If anyone chooses differently, nobody earns points that round

CURRENT ROUND: {round_number} of 14

POINT VALUES THIS ROUND:
"""

    for letter in ['J', 'M', 'N', 'P', 'R', 'C', 'D', 'Q', 'X', 'Y', 'F']:
        points = point_values.get(letter, 0)
        if points > 0:
            prompt += f"- {letter}: {points} points\n"
        else:
            prompt += f"- {letter}: 0 points\n"

    prompt += f"\nYOUR CURRENT TOTAL: {current_points} points\n"

    # Add past round information based on treatment
    if past_choices:
        prompt += "\nPAST ROUNDS:\n"

        for past_round in past_choices:
            r = past_round['round']
            my_choice = past_round['my_choice']
            all_choices = past_round.get('all_choices', [])
            pts = past_round.get('points', 0)

            # In no_feedback treatment, only show rounds 1-7
            if treatment == 'no_feedback' and r >= 8:
                continue

            prompt += f"\nRound {r}:"
            prompt += f"\n  Your choice: {my_choice}"

            # Only show all choices if we have feedback
            if all_choices and (treatment == 'feedback' or r <= 7):
                prompt += f"\n  All 6 players chose: {', '.join(all_choices)}"
                if len(set(all_choices)) == 1:
                    prompt += f"\n  ✓ All coordinated! Everyone earned {pts} points"
                else:
                    prompt += f"\n  ✗ Failed to coordinate. Nobody earned points"
            else:
                prompt += f"\n  Points earned: {pts}"

    if treatment == 'no_feedback' and round_number >= 8:
        prompt += f"\n\nNOTE: You will not see the other players' choices for rounds 8-13. "
        prompt += f"Final results will be revealed at round 14."

    prompt += f"\n\nWhat letter do you choose for round {round_number}?"
    prompt += f"\n\nRespond with ONLY the letter you choose (one of: {', '.join(sorted(set(point_values.keys())))})"
    prompt += f"\n\nThink strategically about:"
    prompt += f"\n- What patterns have emerged in past rounds?"
    prompt += f"\n- What letter are other players likely to choose?"
    prompt += f"\n- How can you maximize coordination and points?"

    return prompt


def get_agent_letter_choice(
    client: anthropic.Anthropic,
    round_number: int,
    treatment: str,
    available_letters: List[str],
    point_values: Dict[str, int],
    past_choices: Optional[List[Dict]] = None,
    current_points: int = 0,
    agent_id: str = "Agent",
    model: str = "claude-3-5-sonnet-20241022"
) -> str:
    """
    Get a letter choice from Claude agent.

    Returns:
        Single letter choice (e.g., 'J', 'M', 'N')
    """

    prompt = create_game_context_prompt(
        round_number=round_number,
        treatment=treatment,
        available_letters=available_letters,
        point_values=point_values,
        past_choices=past_choices,
        current_points=current_points
    )

    response = client.messages.create(
        model=model,
        max_tokens=100,
        temperature=1.0,  # Some randomness for variation
        messages=[{
            "role": "user",
            "content": prompt
        }]
    )

    # Extract letter from response
    choice_text = response.content[0].text.strip().upper()

    # Try to extract just the letter
    valid_letters = set(point_values.keys())
    for letter in valid_letters:
        if letter in choice_text:
            return letter

    # Default fallback - shouldn't happen
    return 'J'


def get_agent_moral_judgment(
    client: anthropic.Anthropic,
    question: str,
    context: str,
    model: str = "claude-3-5-sonnet-20241022"
) -> str:
    """
    Get moral judgment response from agent.

    Args:
        client: Anthropic client
        question: The moral judgment question
        context: Context about the game and scenario
        model: Claude model to use

    Returns:
        Agent's response (number for slider questions, text for open-ended)
    """

    prompt = f"""{context}

{question}

Provide your answer."""

    response = client.messages.create(
        model=model,
        max_tokens=500,
        temperature=1.0,
        messages=[{
            "role": "user",
            "content": prompt
        }]
    )

    return response.content[0].text.strip()
