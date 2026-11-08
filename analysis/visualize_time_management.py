"""
Create visualizations for time management analysis.
"""

import json
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime
from pathlib import Path
from collections import defaultdict
from urllib.parse import urlparse
import numpy as np


# Set style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 10


def load_data(data_dir):
    """Load all extracted data."""
    data_dir = Path(data_dir)

    with open(data_dir / "chrome_history.json") as f:
        chrome_data = json.load(f)

    with open(data_dir / "safari_history.json") as f:
        safari_data = json.load(f)

    with open(data_dir / "terminal_history.json") as f:
        terminal_data = json.load(f)

    with open(data_dir / "file_activity.json") as f:
        file_data = json.load(f)

    return chrome_data, safari_data, terminal_data, file_data


def categorize_url(url, title):
    """Categorize a URL into activity types."""
    url_lower = url.lower()
    domain = urlparse(url).netloc

    if any(x in domain for x in ['arxiv.org', 'scholar.google', 'researchgate', 'jstor',
                                   'pubmed', 'ncbi.nlm.nih.gov', 'wikipedia.org']):
        return 'Research'
    if any(x in domain for x in ['stackoverflow.com', 'github.com', 'docs.', 'api.',
                                   'developer.', 'readthedocs', 'mdn.', 'w3schools']):
        return 'Technical Docs'
    if any(x in domain for x in ['mail.google.com', 'outlook.', 'slack.com']):
        return 'Communication'
    if any(x in domain for x in ['x.com', 'twitter.com', 'reddit.com', 'news.']):
        return 'Social/News'
    if any(x in domain for x in ['prolific.com', 'qualtrics.com', 'overleaf.com']):
        return 'Academic Tools'
    if any(x in domain for x in ['docs.google.com', 'sheets.google.com', 'slides.google.com']):
        return 'Google Workspace'
    if any(x in domain for x in ['claude.ai', 'openai.com', 'chat.openai', 'anthropic.com']):
        return 'AI Tools'
    if any(x in domain for x in ['youtube.com', 'netflix.com', 'spotify.com']):
        return 'Video/Entertainment'
    if any(x in domain for x in ['calendar.google.com', 'calendly.com']):
        return 'Calendar'
    return 'Other'


def plot_activity_breakdown(chrome_data, safari_data, output_dir):
    """Create pie chart of activity categories."""
    all_browsing = chrome_data + safari_data

    categories = defaultdict(int)
    for entry in all_browsing:
        category = categorize_url(entry['url'], entry.get('title', ''))
        categories[category] += 1

    # Filter to top categories
    sorted_cats = sorted(categories.items(), key=lambda x: x[1], reverse=True)
    top_cats = dict(sorted_cats[:8])
    other_count = sum(count for _, count in sorted_cats[8:])
    if other_count > 0:
        top_cats['Other'] = other_count

    # Create pie chart
    fig, ax = plt.subplots(figsize=(10, 8))

    colors = sns.color_palette("husl", len(top_cats))
    wedges, texts, autotexts = ax.pie(
        top_cats.values(),
        labels=top_cats.keys(),
        autopct='%1.1f%%',
        colors=colors,
        startangle=90
    )

    # Make percentage text bold
    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontweight('bold')

    ax.set_title('Activity Breakdown: Last 2 Weeks', fontsize=16, fontweight='bold', pad=20)

    plt.tight_layout()
    plt.savefig(output_dir / 'activity_breakdown.png', dpi=300, bbox_inches='tight')
    print(f"✓ Saved activity_breakdown.png")
    plt.close()


def plot_hourly_activity(chrome_data, safari_data, output_dir):
    """Create heatmap of activity by hour."""
    all_browsing = chrome_data + safari_data

    activity_by_hour = defaultdict(int)
    for entry in all_browsing:
        if 'timestamp' in entry:
            try:
                dt = datetime.fromisoformat(entry['timestamp'])
                activity_by_hour[dt.hour] += 1
            except:
                pass

    if not activity_by_hour:
        print("No timestamp data available for hourly analysis")
        return

    # Create bar chart
    fig, ax = plt.subplots(figsize=(14, 6))

    hours = list(range(24))
    counts = [activity_by_hour.get(h, 0) for h in hours]

    colors = ['#1f77b4' if 9 <= h < 18 else '#ff7f0e' if 18 <= h < 22 else '#d62728'
              for h in hours]

    bars = ax.bar(hours, counts, color=colors, alpha=0.7, edgecolor='black', linewidth=0.5)

    ax.set_xlabel('Hour of Day', fontsize=12, fontweight='bold')
    ax.set_ylabel('Number of Activities', fontsize=12, fontweight='bold')
    ax.set_title('Activity by Hour of Day', fontsize=16, fontweight='bold', pad=20)
    ax.set_xticks(hours)
    ax.set_xticklabels([f'{h:02d}:00' for h in hours], rotation=45, ha='right')
    ax.grid(axis='y', alpha=0.3)

    # Add legend
    from matplotlib.patches import Patch
    legend_elements = [
        Patch(facecolor='#1f77b4', alpha=0.7, label='Work Hours (9-18)'),
        Patch(facecolor='#ff7f0e', alpha=0.7, label='Evening (18-22)'),
        Patch(facecolor='#d62728', alpha=0.7, label='Night/Early Morning')
    ]
    ax.legend(handles=legend_elements, loc='upper left')

    plt.tight_layout()
    plt.savefig(output_dir / 'hourly_activity.png', dpi=300, bbox_inches='tight')
    print(f"✓ Saved hourly_activity.png")
    plt.close()


def plot_file_activity_timeline(file_data, output_dir):
    """Create timeline of file modifications."""
    files_by_day = defaultdict(int)
    for file_info in file_data:
        try:
            dt = datetime.fromisoformat(file_info['modified'])
            day = dt.date()
            files_by_day[day] += 1
        except:
            pass

    if not files_by_day:
        print("No file modification data available")
        return

    # Create line plot
    fig, ax = plt.subplots(figsize=(14, 6))

    days = sorted(files_by_day.keys())
    counts = [files_by_day[day] for day in days]

    ax.plot(days, counts, marker='o', linewidth=2, markersize=8, color='#2ca02c')
    ax.fill_between(range(len(days)), counts, alpha=0.3, color='#2ca02c')

    ax.set_xlabel('Date', fontsize=12, fontweight='bold')
    ax.set_ylabel('Files Modified', fontsize=12, fontweight='bold')
    ax.set_title('File Activity Over Time', fontsize=16, fontweight='bold', pad=20)
    ax.grid(True, alpha=0.3)

    # Rotate x-axis labels
    plt.xticks(rotation=45, ha='right')

    plt.tight_layout()
    plt.savefig(output_dir / 'file_activity_timeline.png', dpi=300, bbox_inches='tight')
    print(f"✓ Saved file_activity_timeline.png")
    plt.close()


def plot_project_focus(file_data, output_dir):
    """Create bar chart of most active projects."""
    project_activity = defaultdict(int)

    for file_info in file_data:
        path = Path(file_info['path'])
        if 'GitHub' in path.parts:
            try:
                idx = path.parts.index('GitHub')
                if idx + 1 < len(path.parts):
                    project = path.parts[idx + 1]
                    project_activity[project] += 1
            except:
                pass

    if not project_activity:
        print("No GitHub project data available")
        return

    # Take top 10 projects
    sorted_projects = sorted(project_activity.items(), key=lambda x: x[1], reverse=True)[:10]
    projects, counts = zip(*sorted_projects)

    # Create horizontal bar chart
    fig, ax = plt.subplots(figsize=(12, 8))

    y_pos = np.arange(len(projects))
    colors = sns.color_palette("viridis", len(projects))

    bars = ax.barh(y_pos, counts, color=colors, edgecolor='black', linewidth=0.5)

    ax.set_yticks(y_pos)
    ax.set_yticklabels(projects)
    ax.invert_yaxis()
    ax.set_xlabel('Files Modified', fontsize=12, fontweight='bold')
    ax.set_title('Most Active GitHub Projects', fontsize=16, fontweight='bold', pad=20)
    ax.grid(axis='x', alpha=0.3)

    # Add value labels
    for i, (bar, count) in enumerate(zip(bars, counts)):
        ax.text(count + 0.5, i, str(count), va='center', fontweight='bold')

    plt.tight_layout()
    plt.savefig(output_dir / 'project_focus.png', dpi=300, bbox_inches='tight')
    print(f"✓ Saved project_focus.png")
    plt.close()


def plot_summary_dashboard(chrome_data, safari_data, terminal_data, file_data, output_dir):
    """Create comprehensive dashboard."""
    fig = plt.figure(figsize=(16, 10))
    gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)

    # 1. Activity breakdown (top left)
    ax1 = fig.add_subplot(gs[0:2, 0:2])
    all_browsing = chrome_data + safari_data
    categories = defaultdict(int)
    for entry in all_browsing:
        category = categorize_url(entry['url'], entry.get('title', ''))
        categories[category] += 1

    sorted_cats = sorted(categories.items(), key=lambda x: x[1], reverse=True)[:8]
    if sorted_cats:
        labels, values = zip(*sorted_cats)
        colors = sns.color_palette("husl", len(labels))
        wedges, texts, autotexts = ax1.pie(values, labels=labels, autopct='%1.1f%%',
                                            colors=colors, startangle=90)
        for autotext in autotexts:
            autotext.set_color('white')
            autotext.set_fontweight('bold')
        ax1.set_title('Activity Breakdown', fontsize=14, fontweight='bold')

    # 2. Key metrics (top right)
    ax2 = fig.add_subplot(gs[0, 2])
    ax2.axis('off')

    total_browsing = len(all_browsing)
    total_files = len(file_data)
    total_commands = len(terminal_data)

    # Code file count
    code_files = sum(1 for f in file_data if f['extension'] in
                     ['.py', '.js', '.ts', '.tsx', '.jsx', '.R', '.html', '.css'])

    metrics_text = f"""
KEY METRICS

Browsing Activity:
  {total_browsing:,} page visits

Terminal Activity:
  {total_commands} commands

File Changes:
  {total_files} total files
  {code_files} code files

AI Usage:
  {categories.get('AI Tools', 0)} visits
  ({(categories.get('AI Tools', 0)/total_browsing*100):.1f}% of time)
"""

    ax2.text(0.1, 0.5, metrics_text, fontsize=11, family='monospace',
             verticalalignment='center', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.3))

    # 3. Hourly activity (middle)
    ax3 = fig.add_subplot(gs[1, 2])
    activity_by_hour = defaultdict(int)
    for entry in all_browsing:
        if 'timestamp' in entry:
            try:
                dt = datetime.fromisoformat(entry['timestamp'])
                activity_by_hour[dt.hour] += 1
            except:
                pass

    if activity_by_hour:
        hours = list(range(24))
        counts = [activity_by_hour.get(h, 0) for h in hours]
        ax3.bar(hours, counts, color='steelblue', alpha=0.7, edgecolor='black', linewidth=0.3)
        ax3.set_xlabel('Hour', fontsize=9)
        ax3.set_ylabel('Activity', fontsize=9)
        ax3.set_title('Activity by Hour', fontsize=10, fontweight='bold')
        ax3.tick_params(labelsize=7)
        ax3.grid(axis='y', alpha=0.3)

    # 4. File activity timeline (bottom)
    ax4 = fig.add_subplot(gs[2, :])
    files_by_day = defaultdict(int)
    for file_info in file_data:
        try:
            dt = datetime.fromisoformat(file_info['modified'])
            day = dt.date()
            files_by_day[day] += 1
        except:
            pass

    if files_by_day:
        days = sorted(files_by_day.keys())
        counts = [files_by_day[day] for day in days]
        ax4.plot(days, counts, marker='o', linewidth=2, markersize=6, color='#2ca02c')
        ax4.fill_between(range(len(days)), counts, alpha=0.3, color='#2ca02c')
        ax4.set_xlabel('Date', fontsize=10, fontweight='bold')
        ax4.set_ylabel('Files Modified', fontsize=10, fontweight='bold')
        ax4.set_title('File Modification Timeline', fontsize=12, fontweight='bold')
        ax4.grid(True, alpha=0.3)
        plt.setp(ax4.xaxis.get_majorticklabels(), rotation=45, ha='right')

    fig.suptitle('Time Management Dashboard - Last 2 Weeks', fontsize=18, fontweight='bold', y=0.98)

    plt.savefig(output_dir / 'summary_dashboard.png', dpi=300, bbox_inches='tight')
    print(f"✓ Saved summary_dashboard.png")
    plt.close()


def main():
    data_dir = Path.home() / "Documents/time_analysis"
    output_dir = data_dir

    print("Loading data...")
    chrome_data, safari_data, terminal_data, file_data = load_data(data_dir)

    print("\nGenerating visualizations...")

    plot_activity_breakdown(chrome_data, safari_data, output_dir)
    plot_hourly_activity(chrome_data, safari_data, output_dir)
    plot_file_activity_timeline(file_data, output_dir)
    plot_project_focus(file_data, output_dir)
    plot_summary_dashboard(chrome_data, safari_data, terminal_data, file_data, output_dir)

    print(f"\n✓ All visualizations saved to {output_dir}/")


if __name__ == '__main__':
    main()
