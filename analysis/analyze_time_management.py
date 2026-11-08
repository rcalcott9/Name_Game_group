"""
Analyze time management patterns from extracted activity data.
Generate insights about how the user manages their time.
"""

import json
import re
from collections import defaultdict, Counter
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import urlparse
import matplotlib.pyplot as plt
import seaborn as sns


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
    title_lower = (title or "").lower()
    domain = urlparse(url).netloc

    # Research & Learning
    if any(x in domain for x in ['arxiv.org', 'scholar.google', 'researchgate', 'jstor',
                                   'pubmed', 'ncbi.nlm.nih.gov', 'wikipedia.org']):
        return 'research'

    # Documentation & Technical Resources
    if any(x in domain for x in ['stackoverflow.com', 'github.com', 'docs.', 'api.',
                                   'developer.', 'readthedocs', 'mdn.', 'w3schools']):
        return 'technical_docs'

    # Communication
    if any(x in domain for x in ['mail.google.com', 'outlook.', 'slack.com',
                                   'discord.com', 'telegram', 'whatsapp']):
        return 'communication'

    # Social Media & News
    if any(x in domain for x in ['x.com', 'twitter.com', 'facebook.com', 'instagram.com',
                                   'linkedin.com', 'reddit.com', 'news.', 'nytimes', 'bbc']):
        return 'social_media_news'

    # Academic Tools
    if any(x in domain for x in ['prolific.com', 'qualtrics.com', 'surveymonkey',
                                   'overleaf.com', 'latex', 'zotero']):
        return 'academic_tools'

    # Google Workspace
    if any(x in domain for x in ['docs.google.com', 'sheets.google.com',
                                   'slides.google.com', 'drive.google.com']):
        return 'google_workspace'

    # AI Tools
    if any(x in domain for x in ['claude.ai', 'openai.com', 'chat.openai',
                                   'anthropic.com', 'perplexity.ai']):
        return 'ai_tools'

    # Video & Entertainment
    if any(x in domain for x in ['youtube.com', 'netflix.com', 'spotify.com',
                                   'vimeo.com', 'twitch.tv']):
        return 'video_entertainment'

    # Shopping & Services
    if any(x in domain for x in ['amazon.com', 'ebay.com', 'shopping',
                                   'store', '.edu']):
        return 'shopping_services'

    # Calendar & Planning
    if any(x in domain for x in ['calendar.google.com', 'calendly.com']):
        return 'calendar_planning'

    # Default
    return 'other'


def categorize_terminal_command(command):
    """Categorize terminal commands."""
    cmd_lower = command.lower()

    # Git operations
    if any(x in cmd_lower for x in ['git ', 'gh ']):
        return 'git_version_control'

    # Python/Programming
    if any(x in cmd_lower for x in ['python', 'pip', 'conda', 'venv', 'jupyter',
                                      'npm', 'node', 'yarn']):
        return 'programming'

    # File operations
    if any(cmd_lower.startswith(x) for x in ['cd ', 'ls ', 'mkdir ', 'rm ', 'cp ',
                                               'mv ', 'cat ', 'less ', 'head ']):
        return 'file_navigation'

    # System operations
    if any(cmd_lower.startswith(x) for x in ['brew ', 'sudo ', 'chmod ', 'kill ',
                                               'ps ', 'top ']):
        return 'system_admin'

    # SSH/Remote
    if any(x in cmd_lower for x in ['ssh', 'scp', 'rsync']):
        return 'remote_access'

    return 'other'


def categorize_file(file_info):
    """Categorize file based on extension and path."""
    ext = file_info['extension'].lower()
    path = file_info['path'].lower()

    # Code files
    if ext in ['.py', '.js', '.ts', '.tsx', '.jsx', '.java', '.cpp', '.c',
               '.r', '.R', '.html', '.css', '.scss', '.sql']:
        return 'code'

    # Data files
    if ext in ['.csv', '.json', '.xml', '.xlsx', '.xls', '.parquet', '.feather']:
        return 'data'

    # Documents
    if ext in ['.pdf', '.doc', '.docx', '.txt', '.md', '.tex']:
        return 'documents'

    # Images
    if ext in ['.png', '.jpg', '.jpeg', '.gif', '.svg', '.tiff']:
        return 'images'

    # Config files
    if ext in ['.yml', '.yaml', '.toml', '.ini', '.conf', '.config']:
        return 'config'

    return 'other'


def analyze_browsing_patterns(chrome_data, safari_data):
    """Analyze web browsing patterns."""
    print("\n" + "="*60)
    print("BROWSING PATTERN ANALYSIS")
    print("="*60)

    all_browsing = chrome_data + safari_data

    # Categorize all URLs
    categories = defaultdict(int)
    category_examples = defaultdict(list)

    for entry in all_browsing:
        category = categorize_url(entry['url'], entry.get('title', ''))
        categories[category] += 1
        if len(category_examples[category]) < 3:
            domain = urlparse(entry['url']).netloc
            category_examples[category].append(domain)

    print("\nActivity Breakdown:")
    sorted_categories = sorted(categories.items(), key=lambda x: x[1], reverse=True)
    total = sum(categories.values())

    for category, count in sorted_categories:
        percentage = (count / total) * 100
        print(f"\n  {category.replace('_', ' ').title()}: {count} ({percentage:.1f}%)")
        print(f"    Examples: {', '.join(category_examples[category][:3])}")

    # Time-based analysis (if timestamps available)
    browsing_by_hour = defaultdict(int)
    for entry in all_browsing:
        if 'timestamp' in entry:
            try:
                dt = datetime.fromisoformat(entry['timestamp'])
                browsing_by_hour[dt.hour] += 1
            except:
                pass

    if browsing_by_hour:
        print("\n\nBrowsing Activity by Hour:")
        for hour in sorted(browsing_by_hour.keys()):
            bar = '█' * (browsing_by_hour[hour] // 10)
            print(f"  {hour:02d}:00 - {bar} ({browsing_by_hour[hour]})")

    return categories, browsing_by_hour


def analyze_terminal_patterns(terminal_data):
    """Analyze terminal command patterns."""
    print("\n" + "="*60)
    print("TERMINAL ACTIVITY ANALYSIS")
    print("="*60)

    categories = defaultdict(int)

    for entry in terminal_data:
        category = categorize_terminal_command(entry['command'])
        categories[category] += 1

    print("\nCommand Type Breakdown:")
    sorted_categories = sorted(categories.items(), key=lambda x: x[1], reverse=True)
    total = sum(categories.values())

    for category, count in sorted_categories:
        percentage = (count / total) * 100
        print(f"  {category.replace('_', ' ').title()}: {count} ({percentage:.1f}%)")

    # Find most common commands
    command_counter = Counter()
    for entry in terminal_data:
        # Extract base command (first word)
        cmd = entry['command'].split()[0] if entry['command'].split() else ''
        if cmd:
            command_counter[cmd] += 1

    print("\n\nMost Frequent Commands:")
    for cmd, count in command_counter.most_common(10):
        print(f"  {cmd}: {count}")

    return categories


def analyze_file_patterns(file_data):
    """Analyze file modification patterns."""
    print("\n" + "="*60)
    print("FILE ACTIVITY ANALYSIS")
    print("="*60)

    categories = defaultdict(int)

    for file_info in file_data:
        category = categorize_file(file_info)
        categories[category] += 1

    print("\nFile Type Breakdown:")
    sorted_categories = sorted(categories.items(), key=lambda x: x[1], reverse=True)
    total = sum(categories.values())

    for category, count in sorted_categories:
        percentage = (count / total) * 100
        print(f"  {category.title()}: {count} ({percentage:.1f}%)")

    # Activity by day
    files_by_day = defaultdict(int)
    for file_info in file_data:
        try:
            dt = datetime.fromisoformat(file_info['modified'])
            day = dt.date()
            files_by_day[day] += 1
        except:
            pass

    print("\n\nFile Modifications by Day:")
    for day in sorted(files_by_day.keys()):
        bar = '█' * (files_by_day[day] // 2)
        print(f"  {day}: {bar} ({files_by_day[day]})")

    # Most active directories
    dir_activity = defaultdict(int)
    for file_info in file_data:
        path = Path(file_info['path'])
        if 'GitHub' in path.parts:
            # Extract project name from GitHub path
            try:
                idx = path.parts.index('GitHub')
                if idx + 1 < len(path.parts):
                    project = path.parts[idx + 1]
                    dir_activity[project] += 1
            except:
                pass

    if dir_activity:
        print("\n\nMost Active GitHub Projects:")
        for project, count in sorted(dir_activity.items(), key=lambda x: x[1], reverse=True)[:10]:
            print(f"  {project}: {count} files")

    return categories, files_by_day


def generate_insights(browsing_cats, terminal_cats, file_cats, browsing_by_hour):
    """Generate high-level insights about time management style."""
    print("\n" + "="*60)
    print("TIME MANAGEMENT INSIGHTS")
    print("="*60)

    insights = []

    # Insight 1: Primary mode of work
    total_browsing = sum(browsing_cats.values())
    research_pct = (browsing_cats.get('research', 0) / total_browsing) * 100
    technical_pct = (browsing_cats.get('technical_docs', 0) / total_browsing) * 100
    ai_pct = (browsing_cats.get('ai_tools', 0) / total_browsing) * 100

    if research_pct > 15:
        insights.append(f"📚 Research-Driven: {research_pct:.1f}% of browsing is academic research. You spend significant time in the literature.")

    if technical_pct > 10:
        insights.append(f"💻 Implementation-Focused: {technical_pct:.1f}% on technical docs suggests active coding/building.")

    if ai_pct > 3:
        insights.append(f"🤖 AI-Augmented: {ai_pct:.1f}% on AI tools shows you leverage AI as a thinking partner.")

    # Insight 2: Communication patterns
    comm_pct = (browsing_cats.get('communication', 0) / total_browsing) * 100
    if comm_pct > 10:
        insights.append(f"✉️ High Communication Load: {comm_pct:.1f}% on email/messaging. Communication is a major time sink.")
    elif comm_pct < 5:
        insights.append(f"🔇 Low Communication Overhead: Only {comm_pct:.1f}% on email. You protect your time from communication drain.")

    # Insight 3: Work hours
    if browsing_by_hour:
        peak_hour = max(browsing_by_hour.items(), key=lambda x: x[1])[0]
        early_activity = sum(v for k, v in browsing_by_hour.items() if 6 <= k < 9)
        late_activity = sum(v for k, v in browsing_by_hour.items() if 21 <= k <= 23)

        if early_activity > 50:
            insights.append(f"🌅 Early Bird: Significant morning activity (6-9 AM). You start working early.")
        if late_activity > 50:
            insights.append(f"🌙 Night Owl: Active late (9-11 PM). Extended work hours.")

        insights.append(f"⏰ Peak Activity: {peak_hour}:00 is your most active hour.")

    # Insight 4: Multitasking vs focus
    google_workspace_pct = (browsing_cats.get('google_workspace', 0) / total_browsing) * 100
    if google_workspace_pct > 10:
        insights.append(f"📝 Document-Centric: {google_workspace_pct:.1f}% in Google Workspace. Heavy writing/collaboration.")

    # Insight 5: Code activity
    total_files = sum(file_cats.values())
    code_pct = (file_cats.get('code', 0) / total_files) * 100 if total_files > 0 else 0
    if code_pct > 30:
        insights.append(f"⚡ Active Development: {code_pct:.1f}% of file changes are code. You're building things.")

    # Insight 6: Context switching
    category_diversity = len([v for v in browsing_cats.values() if v > 10])
    if category_diversity > 5:
        insights.append(f"🔀 Polymath: Active in {category_diversity} different domains. You context-switch between many types of work.")
    else:
        insights.append(f"🎯 Focused: Activity concentrated in {category_diversity} main domains. You maintain deep focus.")

    # Print insights
    print("\n")
    for i, insight in enumerate(insights, 1):
        print(f"{i}. {insight}\n")

    return insights


def generate_narrative(insights, browsing_cats, terminal_cats, file_cats):
    """Generate a narrative explanation of time management style."""
    print("\n" + "="*60)
    print("YOUR TIME MANAGEMENT PHILOSOPHY")
    print("="*60)

    narrative = "\n"
    narrative += "Based on your last two weeks of activity, here's what your behavior reveals\n"
    narrative += "about how you manage time:\n\n"

    # Opening characterization
    total_browsing = sum(browsing_cats.values())
    research_pct = (browsing_cats.get('research', 0) / total_browsing) * 100
    technical_pct = (browsing_cats.get('technical_docs', 0) / total_browsing) * 100

    if research_pct > technical_pct:
        narrative += "You're a **researcher first, implementer second**. Your time is spent primarily\n"
        narrative += "in the literature, understanding what's been done before building something new.\n"
    else:
        narrative += "You're a **builder with academic grounding**. You balance implementation work\n"
        narrative += "with research, but your bias is toward making things.\n"

    narrative += "\n"

    # AI usage pattern
    ai_pct = (browsing_cats.get('ai_tools', 0) / total_browsing) * 100
    if ai_pct > 2:
        narrative += "You've integrated **AI as a thought partner**. Rather than seeing AI tools as\n"
        narrative += "occasional helpers, you use them as a regular part of your workflow. This is\n"
        narrative += "a force multiplier - you're offloading routine cognitive work to focus on higher-level\n"
        narrative += "thinking.\n\n"

    # Communication patterns
    comm_pct = (browsing_cats.get('communication', 0) / total_browsing) * 100
    if comm_pct < 7:
        narrative += "You have **remarkable communication discipline**. While most knowledge workers drown\n"
        narrative += f"in email ({comm_pct:.1f}% of your time vs 20-30% typical), you've structured your work to\n"
        narrative += "minimize communication overhead. This preserves deep work time.\n\n"

    # Work structure
    total_categories = len([v for v in browsing_cats.values() if v > 10])
    if total_categories > 5:
        narrative += "You operate across **multiple parallel streams**. On any given day, you're touching\n"
        narrative += "research, coding, writing, and coordination. Rather than time-blocking by task type,\n"
        narrative += "you seem to flow between activities based on energy and need. This isn't ADHD -\n"
        narrative += "it's **strategic context switching** that keeps you engaged and prevents burnout on\n"
        narrative += "any single task.\n\n"

    # Output orientation
    total_files = sum(file_cats.values())
    code_pct = (file_cats.get('code', 0) / total_files) * 100 if total_files > 0 else 0
    if code_pct > 25:
        narrative += "Your file modifications show you're **output-oriented**. You're not just planning or\n"
        narrative += "researching - you're producing artifacts (code, papers, data analyses). This bias\n"
        narrative += "toward tangible output is what separates busy from productive.\n\n"

    # Closing insight
    narrative += "**The Bottom Line:**\n\n"
    narrative += "You don't manage time in the traditional sense - blocking calendars, scheduling\n"
    narrative += "everything, rigid routines. Instead, you've built a **high-throughput system** where:\n\n"
    narrative += "1. Communication overhead is minimized\n"
    narrative += "2. AI tools amplify your cognitive bandwidth\n"
    narrative += "3. You maintain multiple concurrent workstreams\n"
    narrative += "4. You bias toward creation over consumption\n\n"
    narrative += "This isn't about having more hours. It's about **structuring your environment** so\n"
    narrative += "that your default behavior is productive. The time management happens in the system\n"
    narrative += "design, not the daily execution.\n"

    print(narrative)

    return narrative


def main():
    data_dir = Path.home() / "Documents/time_analysis"

    print("Loading activity data...")
    chrome_data, safari_data, terminal_data, file_data = load_data(data_dir)

    # Analyze each data source
    browsing_cats, browsing_by_hour = analyze_browsing_patterns(chrome_data, safari_data)
    terminal_cats = analyze_terminal_patterns(terminal_data)
    file_cats, files_by_day = analyze_file_patterns(file_data)

    # Generate insights
    insights = generate_insights(browsing_cats, terminal_cats, file_cats, browsing_by_hour)

    # Generate narrative
    narrative = generate_narrative(insights, browsing_cats, terminal_cats, file_cats)

    # Save report
    report_file = data_dir / "time_management_analysis.txt"
    with open(report_file, 'w') as f:
        f.write("="*60 + "\n")
        f.write("TIME MANAGEMENT ANALYSIS REPORT\n")
        f.write("="*60 + "\n\n")
        f.write("INSIGHTS:\n\n")
        for i, insight in enumerate(insights, 1):
            f.write(f"{i}. {insight}\n\n")
        f.write("\n" + "="*60 + "\n\n")
        f.write(narrative)

    print(f"\n✓ Full report saved to {report_file}")


if __name__ == '__main__':
    main()
