"""
Extract activity data from Chrome, Safari, file system, and terminal history.
Analyzes last 2 weeks of user activity on macOS.
"""

import sqlite3
import json
import os
from datetime import datetime, timedelta
from pathlib import Path
import shutil
from collections import defaultdict


def get_date_range():
    """Get timestamps for last 2 weeks."""
    now = datetime.now()
    two_weeks_ago = now - timedelta(days=14)
    return two_weeks_ago, now


def extract_chrome_history(output_file):
    """Extract Chrome browsing history from SQLite database."""
    print("\n" + "="*60)
    print("EXTRACTING CHROME HISTORY")
    print("="*60)

    chrome_history_path = Path.home() / "Library/Application Support/Google/Chrome/Default/History"

    if not chrome_history_path.exists():
        print("Chrome history not found")
        return []

    # Copy database to avoid locking issues
    temp_db = "/tmp/chrome_history_copy.db"
    shutil.copy2(chrome_history_path, temp_db)

    two_weeks_ago, now = get_date_range()
    # Chrome uses WebKit timestamp (microseconds since 1601-01-01)
    webkit_epoch = datetime(1601, 1, 1)
    two_weeks_ago_webkit = int((two_weeks_ago - webkit_epoch).total_seconds() * 1000000)

    conn = sqlite3.connect(temp_db)
    cursor = conn.cursor()

    query = """
    SELECT
        url,
        title,
        visit_count,
        last_visit_time
    FROM urls
    WHERE last_visit_time > ?
    ORDER BY last_visit_time DESC
    """

    cursor.execute(query, (two_weeks_ago_webkit,))
    rows = cursor.fetchall()

    history = []
    for url, title, visit_count, webkit_time in rows:
        # Convert WebKit timestamp to Python datetime
        timestamp = webkit_epoch + timedelta(microseconds=webkit_time)
        history.append({
            'browser': 'chrome',
            'url': url,
            'title': title or url,
            'visit_count': visit_count,
            'timestamp': timestamp.isoformat()
        })

    conn.close()
    os.remove(temp_db)

    print(f"Extracted {len(history)} Chrome history entries")

    with open(output_file, 'w') as f:
        json.dump(history, f, indent=2)

    return history


def extract_safari_history(output_file):
    """Extract Safari browsing history from SQLite database."""
    print("\n" + "="*60)
    print("EXTRACTING SAFARI HISTORY")
    print("="*60)

    safari_history_path = Path.home() / "Library/Safari/History.db"

    if not safari_history_path.exists():
        print("Safari history not found")
        return []

    # Copy database to avoid locking issues
    temp_db = "/tmp/safari_history_copy.db"
    shutil.copy2(safari_history_path, temp_db)

    two_weeks_ago, now = get_date_range()
    # Safari uses Core Data timestamp (seconds since 2001-01-01)
    core_data_epoch = datetime(2001, 1, 1)
    two_weeks_ago_core_data = (two_weeks_ago - core_data_epoch).total_seconds()

    conn = sqlite3.connect(temp_db)
    cursor = conn.cursor()

    query = """
    SELECT
        history_items.url,
        history_visits.title,
        history_visits.visit_time
    FROM history_items
    LEFT JOIN history_visits ON history_items.id = history_visits.history_item
    WHERE history_visits.visit_time > ?
    ORDER BY history_visits.visit_time DESC
    """

    cursor.execute(query, (two_weeks_ago_core_data,))
    rows = cursor.fetchall()

    history = []
    for url, title, core_data_time in rows:
        # Convert Core Data timestamp to Python datetime
        timestamp = core_data_epoch + timedelta(seconds=core_data_time)
        history.append({
            'browser': 'safari',
            'url': url,
            'title': title or url,
            'timestamp': timestamp.isoformat()
        })

    conn.close()
    os.remove(temp_db)

    print(f"Extracted {len(history)} Safari history entries")

    with open(output_file, 'w') as f:
        json.dump(history, f, indent=2)

    return history


def extract_terminal_history(output_file):
    """Extract and parse terminal history."""
    print("\n" + "="*60)
    print("EXTRACTING TERMINAL HISTORY")
    print("="*60)

    zsh_history_path = Path.home() / ".zsh_history"

    if not zsh_history_path.exists():
        print("Terminal history not found")
        return []

    commands = []

    with open(zsh_history_path, 'rb') as f:
        content = f.read().decode('utf-8', errors='ignore')

    # Simple extraction - just get commands (no timestamps in this format)
    for line in content.split('\n'):
        line = line.strip()
        if line and not line.startswith('#'):
            commands.append({
                'command': line
            })

    # Take only recent commands (last 1000 or so)
    commands = commands[-1000:]

    print(f"Extracted {len(commands)} terminal commands")

    with open(output_file, 'w') as f:
        json.dump(commands, f, indent=2)

    return commands


def extract_file_activity(output_file, base_paths=None):
    """Extract recently modified files from key directories."""
    print("\n" + "="*60)
    print("EXTRACTING FILE SYSTEM ACTIVITY")
    print("="*60)

    if base_paths is None:
        base_paths = [
            Path.home() / "Documents",
            Path.home() / "Desktop",
            Path.home() / "Downloads"
        ]

    two_weeks_ago, now = get_date_range()
    two_weeks_ago_timestamp = two_weeks_ago.timestamp()

    files = []

    for base_path in base_paths:
        if not base_path.exists():
            continue

        print(f"Scanning {base_path}...")

        for file_path in base_path.rglob('*'):
            # Skip certain directories
            skip_dirs = {'.git', 'node_modules', '__pycache__', '.venv', 'venv',
                        '.DS_Store', '.Trash', 'Library', '.cache'}
            if any(skip in file_path.parts for skip in skip_dirs):
                continue

            if file_path.is_file():
                try:
                    stat = file_path.stat()
                    mtime = stat.st_mtime

                    if mtime >= two_weeks_ago_timestamp:
                        files.append({
                            'path': str(file_path),
                            'size': stat.st_size,
                            'modified': datetime.fromtimestamp(mtime).isoformat(),
                            'extension': file_path.suffix,
                            'name': file_path.name
                        })
                except (PermissionError, OSError):
                    continue

    # Sort by modification time
    files.sort(key=lambda x: x['modified'], reverse=True)

    print(f"Found {len(files)} modified files")

    with open(output_file, 'w') as f:
        json.dump(files, f, indent=2)

    return files


def print_summary(chrome_data, safari_data, terminal_data, file_data):
    """Print summary statistics."""
    print("\n" + "="*60)
    print("DATA EXTRACTION SUMMARY")
    print("="*60)

    print(f"\nChrome history entries: {len(chrome_data)}")
    print(f"Safari history entries: {len(safari_data)}")
    print(f"Terminal commands: {len(terminal_data)}")
    print(f"Modified files: {len(file_data)}")

    # Top domains from browsing
    print("\nTop 10 websites visited:")
    domain_counts = defaultdict(int)
    for entry in chrome_data + safari_data:
        try:
            from urllib.parse import urlparse
            domain = urlparse(entry['url']).netloc
            if domain:
                domain_counts[domain] += 1
        except:
            pass

    for domain, count in sorted(domain_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"  {domain}: {count} visits")

    # File types
    print("\nTop file types modified:")
    ext_counts = defaultdict(int)
    for file in file_data:
        ext = file['extension'] or 'no extension'
        ext_counts[ext] += 1

    for ext, count in sorted(ext_counts.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"  {ext}: {count} files")

    print("\n" + "="*60)


def main():
    # Create output directory
    output_dir = Path.home() / "Documents/time_analysis"
    output_dir.mkdir(exist_ok=True)

    print(f"Analyzing activity from last 2 weeks...")
    two_weeks_ago, now = get_date_range()
    print(f"Date range: {two_weeks_ago.strftime('%Y-%m-%d')} to {now.strftime('%Y-%m-%d')}")

    # Extract all data
    chrome_data = extract_chrome_history(output_dir / "chrome_history.json")
    safari_data = extract_safari_history(output_dir / "safari_history.json")
    terminal_data = extract_terminal_history(output_dir / "terminal_history.json")
    file_data = extract_file_activity(output_dir / "file_activity.json")

    # Print summary
    print_summary(chrome_data, safari_data, terminal_data, file_data)

    print(f"\n✓ All data saved to {output_dir}/")


if __name__ == '__main__':
    main()
