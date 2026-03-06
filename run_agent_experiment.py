"""
Run the mutual observability experiment with Claude agents.

This script runs 6 Claude agents through the coordination game in either
the Mutual Observability (MO) or No Mutual Observability (No MO) condition.

Usage:
    python run_agent_experiment.py --treatment feedback --output results_mo.csv
    python run_agent_experiment.py --treatment no_feedback --output results_no_mo.csv
"""

import argparse
import csv
import os
from datetime import datetime
from typing import List, Dict
from claude_agent_utils import get_claude_client, get_agent_letter_choice


# Game constants
NUM_ROUNDS = 14
NUM_AGENTS = 6
ALL_LETTERS = ['Q', 'M', 'N', 'X', 'Y', 'F', 'J', 'P', 'R', 'C', 'D']


def get_point_values(round_number: int) -> Dict[str, int]:
    """Get point values for each letter based on round number."""
    point_values = {letter: 0 for letter in ALL_LETTERS}

    if round_number <= 7:
        # Rounds 1-7: Only J worth points
        point_values['J'] = 10
    else:
        # Rounds 8+: J, M, N worth points
        point_values['J'] = 10
        point_values['M'] = 15
        point_values['N'] = 15

    return point_values


def get_available_letters(round_number: int) -> List[str]:
    """Get letters that are worth points this round."""
    if round_number <= 7:
        return ['J']
    else:
        return ['J', 'M', 'N']


def calculate_round_points(all_choices: List[str], point_values: Dict[str, int]) -> int:
    """
    Calculate points earned this round.
    All 6 players must choose the same letter to earn points.
    """
    if len(set(all_choices)) == 1:
        # All coordinated
        letter = all_choices[0]
        return point_values.get(letter, 0)
    else:
        # Failed to coordinate
        return 0


def run_experiment(treatment: str, output_file: str, session_id: str = None):
    """
    Run one session of the experiment with 6 Claude agents.

    Args:
        treatment: 'feedback' or 'no_feedback'
        output_file: Path to save results CSV
        session_id: Optional session identifier
    """

    if session_id is None:
        session_id = datetime.now().strftime("%Y%m%d_%H%M%S")

    print(f"\n{'='*60}")
    print(f"Running Agent Experiment")
    print(f"Treatment: {treatment}")
    print(f"Session ID: {session_id}")
    print(f"{'='*60}\n")

    # Initialize Claude client
    client = get_claude_client()

    # Initialize agent data
    agents_data = []
    for agent_id in range(1, NUM_AGENTS + 1):
        agents_data.append({
            'agent_id': agent_id,
            'past_choices': [],
            'total_points': 0,
            'all_round_data': []
        })

    # Run through all rounds
    for round_num in range(1, NUM_ROUNDS + 1):
        print(f"\n--- Round {round_num} ---")

        point_values = get_point_values(round_num)
        available_letters = get_available_letters(round_num)

        # Get choices from all agents
        round_choices = []
        for agent_data in agents_data:
            agent_id = agent_data['agent_id']

            # Get agent's choice
            choice = get_agent_letter_choice(
                client=client,
                round_number=round_num,
                treatment=treatment,
                available_letters=available_letters,
                point_values=point_values,
                past_choices=agent_data['past_choices'],
                current_points=agent_data['total_points'],
                agent_id=f"Agent_{agent_id}"
            )

            round_choices.append(choice)
            print(f"  Agent {agent_id}: {choice}")

        # Calculate points
        round_points = calculate_round_points(round_choices, point_values)

        # Check coordination
        coordinated = len(set(round_choices)) == 1
        print(f"  Coordination: {'✓ YES' if coordinated else '✗ NO'} | Points: {round_points}")

        # Update agent data
        for i, agent_data in enumerate(agents_data):
            agent_choice = round_choices[i]

            # Update total points
            agent_data['total_points'] += round_points

            # Store round data for history
            round_data = {
                'round': round_num,
                'my_choice': agent_choice,
                'points': round_points
            }

            # Add all choices if feedback is available
            if treatment == 'feedback' or round_num <= 7:
                round_data['all_choices'] = round_choices.copy()

            agent_data['past_choices'].append(round_data)

            # Store full round data for CSV output
            agent_data['all_round_data'].append({
                'session_id': session_id,
                'treatment': treatment,
                'agent_id': agent_data['agent_id'],
                'round': round_num,
                'choice': agent_choice,
                'all_choices': ','.join(round_choices),
                'coordinated': coordinated,
                'round_points': round_points,
                'total_points': agent_data['total_points']
            })

    # Print final results
    print(f"\n{'='*60}")
    print(f"FINAL RESULTS")
    print(f"{'='*60}")
    for agent_data in agents_data:
        print(f"Agent {agent_data['agent_id']}: {agent_data['total_points']} points")

    # Save results to CSV
    print(f"\nSaving results to {output_file}...")

    fieldnames = ['session_id', 'treatment', 'agent_id', 'round', 'choice',
                  'all_choices', 'coordinated', 'round_points', 'total_points']

    # Flatten all round data
    all_rows = []
    for agent_data in agents_data:
        all_rows.extend(agent_data['all_round_data'])

    with open(output_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_rows)

    print(f"✓ Results saved!")
    print(f"\n{'='*60}\n")

    return agents_data


def main():
    parser = argparse.ArgumentParser(description='Run Claude agents through mutual observability experiment')
    parser.add_argument('--treatment', type=str, required=True,
                        choices=['feedback', 'no_feedback'],
                        help='Treatment condition: feedback (MO) or no_feedback (No MO)')
    parser.add_argument('--output', type=str, required=True,
                        help='Output CSV file path')
    parser.add_argument('--session-id', type=str, default=None,
                        help='Optional session identifier')
    parser.add_argument('--n-sessions', type=int, default=1,
                        help='Number of sessions to run (default: 1)')

    args = parser.parse_args()

    # Check for API key
    if not os.environ.get('ANTHROPIC_API_KEY'):
        print("ERROR: ANTHROPIC_API_KEY environment variable not set")
        print("Please set it with: export ANTHROPIC_API_KEY='your-key-here'")
        return

    # Run experiment session(s)
    if args.n_sessions == 1:
        run_experiment(args.treatment, args.output, args.session_id)
    else:
        # Run multiple sessions and append to same file
        for session_num in range(1, args.n_sessions + 1):
            session_id = f"{args.session_id or 'session'}_{session_num}"
            run_experiment(args.treatment, args.output, session_id)


if __name__ == '__main__':
    main()
