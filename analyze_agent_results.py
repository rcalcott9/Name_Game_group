"""
Analyze results from Claude agent experiments.

Compare behavioral patterns between Mutual Observability (MO) and
No Mutual Observability (No MO) conditions.
"""

import pandas as pd
import argparse
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path


def load_and_combine_data(mo_file: str, no_mo_file: str) -> pd.DataFrame:
    """Load and combine data from both treatment conditions."""
    try:
        df_mo = pd.read_csv(mo_file)
        df_no_mo = pd.read_csv(no_mo_file)

        # Combine
        df = pd.concat([df_mo, df_no_mo], ignore_index=True)
        return df
    except FileNotFoundError as e:
        print(f"Error: Could not find file {e.filename}")
        return None


def calculate_switching_rates(df: pd.DataFrame) -> pd.DataFrame:
    """Calculate switching rates from J to M/N in rounds 8-14."""

    # Filter to rounds 8-14
    df_late = df[df['round'] >= 8].copy()

    # Count switches to M or N
    df_late['switched_to_better'] = df_late['choice'].isin(['M', 'N'])

    # Aggregate by treatment
    switching_rates = df_late.groupby(['treatment', 'round']).agg({
        'switched_to_better': 'mean'
    }).reset_index()

    switching_rates.columns = ['treatment', 'round', 'switch_rate']

    return switching_rates


def calculate_coordination_rates(df: pd.DataFrame) -> pd.DataFrame:
    """Calculate coordination rates by treatment and round."""

    coord_rates = df.groupby(['treatment', 'round']).agg({
        'coordinated': 'mean'
    }).reset_index()

    coord_rates.columns = ['treatment', 'round', 'coordination_rate']

    return coord_rates


def plot_switching_behavior(switching_rates: pd.DataFrame, output_dir: str):
    """Plot switching rates over rounds by treatment."""

    plt.figure(figsize=(10, 6))

    for treatment in ['feedback', 'no_feedback']:
        data = switching_rates[switching_rates['treatment'] == treatment]
        label = 'Mutual Observability' if treatment == 'feedback' else 'No Mutual Observability'
        plt.plot(data['round'], data['switch_rate'] * 100,
                marker='o', label=label, linewidth=2)

    plt.axvline(x=7.5, color='gray', linestyle='--', alpha=0.5, label='New options (M/N) introduced')
    plt.xlabel('Round', fontsize=12)
    plt.ylabel('% Switching to M or N', fontsize=12)
    plt.title('Agent Switching Behavior by Treatment', fontsize=14, fontweight='bold')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    output_path = Path(output_dir) / 'agent_switching_rates.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Saved plot: {output_path}")
    plt.close()


def plot_coordination_rates(coord_rates: pd.DataFrame, output_dir: str):
    """Plot coordination success rates over rounds."""

    plt.figure(figsize=(10, 6))

    for treatment in ['feedback', 'no_feedback']:
        data = coord_rates[coord_rates['treatment'] == treatment]
        label = 'Mutual Observability' if treatment == 'feedback' else 'No Mutual Observability'
        plt.plot(data['round'], data['coordination_rate'] * 100,
                marker='s', label=label, linewidth=2)

    plt.axvline(x=7.5, color='gray', linestyle='--', alpha=0.5, label='New options introduced')
    plt.xlabel('Round', fontsize=12)
    plt.ylabel('% Successful Coordination', fontsize=12)
    plt.title('Coordination Success by Treatment', fontsize=14, fontweight='bold')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    output_path = Path(output_dir) / 'agent_coordination_rates.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Saved plot: {output_path}")
    plt.close()


def plot_letter_distribution(df: pd.DataFrame, output_dir: str):
    """Plot distribution of letter choices by treatment and phase."""

    # Add phase
    df['phase'] = df['round'].apply(lambda r: 'Rounds 1-7' if r <= 7 else 'Rounds 8-14')

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    for i, treatment in enumerate(['feedback', 'no_feedback']):
        for j, phase in enumerate(['Rounds 1-7', 'Rounds 8-14']):
            ax = axes[i, j]

            data = df[(df['treatment'] == treatment) & (df['phase'] == phase)]

            letter_counts = data['choice'].value_counts().sort_index()

            ax.bar(letter_counts.index, letter_counts.values, color='steelblue', alpha=0.7)
            ax.set_xlabel('Letter Choice', fontsize=10)
            ax.set_ylabel('Frequency', fontsize=10)

            treatment_label = 'MO' if treatment == 'feedback' else 'No MO'
            ax.set_title(f'{treatment_label}: {phase}', fontsize=11, fontweight='bold')
            ax.grid(True, alpha=0.3, axis='y')

    plt.suptitle('Letter Choice Distribution by Treatment and Phase',
                 fontsize=14, fontweight='bold', y=0.995)
    plt.tight_layout()

    output_path = Path(output_dir) / 'agent_letter_distribution.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Saved plot: {output_path}")
    plt.close()


def print_summary_statistics(df: pd.DataFrame):
    """Print summary statistics comparing treatments."""

    print("\n" + "="*60)
    print("SUMMARY STATISTICS")
    print("="*60 + "\n")

    # Overall switching rates in rounds 8-14
    df_late = df[df['round'] >= 8].copy()
    df_late['switched'] = df_late['choice'].isin(['M', 'N'])

    print("Switching to M/N in Rounds 8-14:")
    for treatment in ['feedback', 'no_feedback']:
        data = df_late[df_late['treatment'] == treatment]
        switch_rate = data['switched'].mean() * 100
        treatment_label = 'Mutual Observability' if treatment == 'feedback' else 'No Mutual Observability'
        print(f"  {treatment_label}: {switch_rate:.1f}%")

    # Coordination rates
    print("\nOverall Coordination Rates:")
    for treatment in ['feedback', 'no_feedback']:
        data = df[df['treatment'] == treatment]
        coord_rate = data['coordinated'].mean() * 100
        treatment_label = 'Mutual Observability' if treatment == 'feedback' else 'No Mutual Observability'
        print(f"  {treatment_label}: {coord_rate:.1f}%")

    # Average final points
    print("\nAverage Final Points (per agent):")
    final_points = df[df['round'] == 14].groupby('treatment')['total_points'].mean()
    for treatment in ['feedback', 'no_feedback']:
        treatment_label = 'Mutual Observability' if treatment == 'feedback' else 'No Mutual Observability'
        print(f"  {treatment_label}: {final_points[treatment]:.1f} points")

    print("\n" + "="*60 + "\n")


def main():
    parser = argparse.ArgumentParser(description='Analyze Claude agent experiment results')
    parser.add_argument('--mo-file', type=str, required=True,
                        help='CSV file with Mutual Observability (feedback) results')
    parser.add_argument('--no-mo-file', type=str, required=True,
                        help='CSV file with No Mutual Observability (no_feedback) results')
    parser.add_argument('--output-dir', type=str, default='agent_results',
                        help='Directory to save plots (default: agent_results)')

    args = parser.parse_args()

    # Create output directory
    Path(args.output_dir).mkdir(exist_ok=True)

    # Load data
    print("Loading data...")
    df = load_and_combine_data(args.mo_file, args.no_mo_file)

    if df is None:
        return

    print(f"Loaded {len(df)} total observations")
    print(f"  MO sessions: {df[df['treatment']=='feedback']['session_id'].nunique()}")
    print(f"  No MO sessions: {df[df['treatment']=='no_feedback']['session_id'].nunique()}")

    # Calculate metrics
    print("\nCalculating switching rates...")
    switching_rates = calculate_switching_rates(df)

    print("Calculating coordination rates...")
    coord_rates = calculate_coordination_rates(df)

    # Generate plots
    print("\nGenerating plots...")
    plot_switching_behavior(switching_rates, args.output_dir)
    plot_coordination_rates(coord_rates, args.output_dir)
    plot_letter_distribution(df, args.output_dir)

    # Print summary
    print_summary_statistics(df)

    print(f"\n✓ Analysis complete! Plots saved to {args.output_dir}/")


if __name__ == '__main__':
    main()
