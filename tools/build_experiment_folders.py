"""
Build one self-contained, deployable folder per human-participant experiment.

Each experiment gets:

    experiments/<launch-date>_<slug>/
        code/            <- a COMPLETE oTree project. This is the Cyberduck payload.
        data/            <- raw oTree exports + processed long-format files
        analysis/        <- R / Python analysis for this experiment
        visualizations/  <- figures
        README.md        <- launch date, n, app sequence, how to run/deploy

`code/` is kept clean of analysis scripts on purpose: you upload that folder and
nothing else. settings.py is rewritten to hold ONLY the session configs belonging
to this experiment, so the admin page shows just the relevant ones.

NON-DESTRUCTIVE: only copies. Nothing in the source tree is moved or deleted.
secrets.env is never copied (it holds live API keys); a blanked
secrets.env.example is written instead.

Run:  python3 tools/build_experiment_folders.py [--force]
"""
import os, re, shutil, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_ROOT = os.path.join(ROOT, "experiments")
FORCE = "--force" in sys.argv

# Project-level files every deployable copy needs.
SHARED_FILES = ["requirements.txt", "Procfile"]
SHARED_DIRS = ["_static", "_templates"]
IGNORE = shutil.ignore_patterns("__pycache__", "*.pyc", ".DS_Store", ".Rproj.user")

# --------------------------------------------------------------------------
# Manifest. `date` is the launch date: real participant data where it exists,
# otherwise the date the app was written (flagged never_launched).
# --------------------------------------------------------------------------
EXPERIMENTS = [
    dict(
        date="2025-11-12", slug="name_game_incentivized",
        title="Incentivized Name Game",
        blurb="Group coordination with real incentives; J/M/N scoring, all players "
              "must match to score. Run on Prolific.",
        configs=["name_game_incentivized", "test_incentivized_dyadic", "test_incentivized_group"],
        apps=["Intro", "name_game_incentivized", "End_name"],
        n_participants=200,
        date_basis="200 participants in data/all_apps_wide-2025-11-12.csv",
        data=["data/all_apps_wide-2025-11-12.csv", "data/name_game_long_with_groups.csv"],
        analysis=["analysis/name_game_incentivized.R", "analysis/name_game_incentivized.zip"],
    ),
    dict(
        date="2026-01-12", slug="name_game_feedback_vs_no_feedback",
        title="Name Game - feedback vs no-feedback",
        blurb="The original multi-player Name Game: participants pass through the "
              "feedback and no-feedback variants. Largest human sample collected.",
        configs=[],   # config was later commented out of settings.py; synthesized below
        synth_config=dict(
            name="name_game",
            display_name="Name Game - Unified (Random Assignment)",
            app_sequence=["consent", "Intro", "name_game", "name_game_no_feedback", "End_name"],
            num_demo_participants=4, use_live=True, test_mode=False,
        ),
        apps=["consent", "Intro", "name_game", "name_game_no_feedback", "End_name"],
        n_participants=350,
        date_basis="350 participants in data/all_apps_wide-2026-01-12-6.csv",
        data=["data/all_apps_wide-2026-01-12-6.csv", "data/name_game_long.csv"],
        analysis=["analysis/name_game_analysis_updated.R", "analysis/Name_game_Study2_final.R",
                  "analysis/analyze_data.R", "Name_Game_model.R", "Name_Game_model_comparison.R"],
        # name_game/__init__.py is MISSING from the working tree - only the .html
        # templates survive there, so the app cannot run as-is. Recovered from the
        # last commit that still had it.
        restore_from_git=[("63eaec3", "name_game/__init__.py")],
        caveat="Two reconstructions were needed here. (1) The session config had been "
               "commented out of settings.py; the app sequence was rebuilt from the "
               "export, where all five apps carry substantial participant data. "
               "(2) `name_game/__init__.py` is missing from the working tree - only its "
               "HTML templates remain - so it was restored from git commit 63eaec3 "
               "(2025-11-21), the last commit containing it and the closest available "
               "version predating the 2026-01-12 launch. Check it against your intended "
               "design before relaunching.",
    ),
    dict(
        date="2025-10-14", slug="dyad_name_game",
        title="Dyad Name Game",
        blurb="Two-player fixed-pair version. J=10, then M=15 / Q=15 after round 7.",
        configs=["dyad_name_game", "test_dyad_bot", "test_dyad_name_game"],
        apps=["Intro", "Dyad_Name_Game", "End_name"],
        never_launched=True, date_basis="earliest file date in Dyad_Name_Game/",
    ),
    dict(
        date="2026-04-01", slug="name_game_no_partner",
        title="Name Game No Partner (deception study)",
        blurb="Single player; a bot simulates the partner and introduces a norm shift.",
        configs=["name_game_no_partner"],
        apps=["Intro", "name_game_no_partner", "End_no_partner"],
        never_launched=True, date_basis="earliest file date in name_game_no_partner/",
    ),
    dict(
        date="2026-04-07", slug="coordination_moralization",
        title="Coordination Moralization (third-person)",
        blurb="Observers judge players who break an established convention. Standalone app.",
        configs=["coordination_moralization", "coordination_moralization_solo",
                 "coordination_moralization_coordination"],
        apps=["coordination_moralization"],
        never_launched=True,
        date_basis="100 local test sessions in db.sqlite3, 2026-04-07 to 2026-04-15",
    ),
    dict(
        date="2026-04-15", slug="mutual_observability",
        title="Mutual Observability",
        blurb="Whether precedent gets moralized depends on whether players can see "
              "each other. Companion to the manuscript.",
        configs=["mutual_observability", "test_mutual_observability"],
        apps=["consent", "Intro", "mutual_observability", "End_name"],
        never_launched=True,
        date_basis="earliest file date in mutual_observability/ - never run, not even locally",
    ),
]

SECRETS_EXAMPLE = """\
# Copy to secrets.env and fill in. NEVER commit or upload the filled-in version.
OTREE_ADMIN_PASSWORD=
OTREE_SERVER_URL=
OTREE_REST_KEY=
"""


# --------------------------------------------------------------------------
def config_span(settings_src):
    """Byte span of the SESSION_CONFIGS assignment.

    Both names also appear inside explanatory comments, so anchor on a real
    top-level assignment (start of line, followed by '='), not a bare .index().
    """
    a = re.search(r"^SESSION_CONFIGS\s*=", settings_src, re.M)
    b = re.search(r"^SESSION_CONFIG_DEFAULTS\s*=", settings_src, re.M)
    if not a or not b:
        raise SystemExit("could not locate SESSION_CONFIGS / SESSION_CONFIG_DEFAULTS assignments")
    return a.start(), b.start()


def split_session_configs(settings_src):
    """Return {config_name: source_text} for each top-level dict(...) in SESSION_CONFIGS."""
    start, end = config_span(settings_src)
    body = settings_src[start:end]

    out, i = {}, 0
    while True:
        m = re.compile(r"\bdict\(").search(body, i)
        if not m:
            break
        # skip blocks that are entirely commented out
        line_start = body.rfind("\n", 0, m.start()) + 1
        if body[line_start:m.start()].lstrip().startswith("#"):
            i = m.end()
            continue
        j, depth = m.end(), 1   # m.end() is just past the opening paren
        while j < len(body) and depth:
            if body[j] == "(":
                depth += 1
            elif body[j] == ")":
                depth -= 1
            j += 1
        block = body[m.start():j]
        nm = re.search(r"name\s*=\s*'([^']+)'", block)
        if nm:
            out[nm.group(1)] = block
        i = j
    return out


def render_settings(settings_src, keep_names, synth=None):
    """Rewrite settings.py so SESSION_CONFIGS contains only the wanted configs."""
    blocks = split_session_configs(settings_src)
    chosen = [blocks[n] for n in keep_names if n in blocks]

    if synth is not None:
        lines = [f"    dict("]
        for k, v in synth.items():
            lines.append(f"        {k}={v!r},")
        lines.append("    )")
        chosen.insert(0, "\n".join(lines).strip())

    if not chosen:
        raise SystemExit(f"no session configs matched {keep_names}")

    body = "SESSION_CONFIGS = [\n" + "".join(f"    {b},\n" for b in chosen) + "]\n"
    start, end = config_span(settings_src)
    out = settings_src[:start] + body + "\n\n" + settings_src[end:]
    compile(out, "settings.py", "exec")   # fail loudly rather than ship broken settings
    return out


def copy_into(src_rel, dest_dir):
    src = os.path.join(ROOT, src_rel)
    if not os.path.exists(src):
        return None
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, os.path.basename(src_rel))
    if os.path.isdir(src):
        shutil.copytree(src, dest, ignore=IGNORE, dirs_exist_ok=True)
    else:
        shutil.copy2(src, dest)
    return os.path.basename(src_rel)


def build(exp, settings_src):
    name = f"{exp['date']}_{exp['slug']}"
    base = os.path.join(OUT_ROOT, name)
    if os.path.exists(base):
        if not FORCE:
            print(f"  skip (exists)  {name}")
            return
        shutil.rmtree(base)

    code = os.path.join(base, "code")
    os.makedirs(code, exist_ok=True)

    # --- deployable oTree project -------------------------------------
    for app in exp["apps"]:
        src = os.path.join(ROOT, app)
        if not os.path.isdir(src):
            print(f"    !! missing app {app}")
            continue
        shutil.copytree(src, os.path.join(code, app), ignore=IGNORE, dirs_exist_ok=True)
    for d in SHARED_DIRS:
        if os.path.isdir(os.path.join(ROOT, d)):
            shutil.copytree(os.path.join(ROOT, d), os.path.join(code, d),
                            ignore=IGNORE, dirs_exist_ok=True)
    for f in SHARED_FILES:
        if os.path.exists(os.path.join(ROOT, f)):
            shutil.copy2(os.path.join(ROOT, f), code)

    # Some app files no longer exist in the working tree; pull them back from git
    # so the copied project can actually run.
    for commit, path in exp.get("restore_from_git", []):
        import subprocess
        blob = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=ROOT,
                              capture_output=True, text=True)
        if blob.returncode:
            print(f"    !! could not restore {path} from {commit}")
            continue
        dest = os.path.join(code, path)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w") as fh:
            fh.write(blob.stdout)
        print(f"    restored {path} from {commit}")

    with open(os.path.join(code, "settings.py"), "w") as fh:
        fh.write(render_settings(settings_src, exp["configs"], exp.get("synth_config")))
    with open(os.path.join(code, "secrets.env.example"), "w") as fh:
        fh.write(SECRETS_EXAMPLE)

    # --- data / analysis / visualizations ------------------------------
    got_data = [copy_into(p, os.path.join(base, "data")) for p in exp.get("data", [])]
    got_anal = [copy_into(p, os.path.join(base, "analysis")) for p in exp.get("analysis", [])]
    for sub in ("data", "analysis", "visualizations"):
        os.makedirs(os.path.join(base, sub), exist_ok=True)
        keep = os.path.join(base, sub, ".gitkeep")
        if not os.listdir(os.path.join(base, sub)):
            open(keep, "w").close()

    write_readme(base, exp, [g for g in got_data if g], [g for g in got_anal if g])
    print(f"  built  {name}")


def write_readme(base, exp, data_files, analysis_files):
    seq = exp.get("synth_config", {}).get("app_sequence") or exp["apps"]
    launched = not exp.get("never_launched")
    status = (f"**Launched {exp['date']}** with **{exp['n_participants']} participants**."
              if launched else
              f"**Never launched.** Code complete and runnable; dated {exp['date']} by when it was written.")

    lines = [
        f"# {exp['title']}",
        "",
        f"`{exp['date']}` · {exp['slug']}",
        "",
        status,
        "",
        exp["blurb"],
        "",
        "## Layout",
        "",
        "| folder | contents |",
        "|---|---|",
        "| `code/` | **complete oTree project — this is what you upload** |",
        "| `data/` | raw oTree exports and processed files |",
        "| `analysis/` | R / Python analysis for this experiment |",
        "| `visualizations/` | figures |",
        "",
        "## Session",
        "",
        f"- App sequence: {' → '.join(f'`{a}`' for a in seq)}",
    ]
    if exp["configs"]:
        lines.append(f"- Session configs available: {', '.join(f'`{c}`' for c in exp['configs'])}")
    else:
        lines.append(f"- Session config: `{exp.get('synth_config', {}).get('name', '?')}` (reconstructed)")
    lines += [
        f"- Date basis: {exp['date_basis']}",
        "",
    ]
    if exp.get("caveat"):
        lines += ["> ⚠️ " + exp["caveat"], ""]

    lines += [
        "## Run it locally",
        "",
        "```bash",
        "cd code",
        "pip install -r requirements.txt",
        "cp secrets.env.example secrets.env   # then fill in",
        "otree devserver",
        "```",
        "",
        "## Deploy (Cyberduck)",
        "",
        "Upload the **contents of `code/`** to the server's project directory. It is a",
        "self-contained oTree project — nothing outside `code/` is needed to run.",
        "",
        "`settings.py` here is trimmed to only this experiment's session configs, so the",
        "admin page shows just the relevant ones.",
        "",
        "> `secrets.env` is deliberately **not** included — it holds live API keys. Copy",
        "> `secrets.env.example`, fill it in on the server, and never upload the filled copy.",
        "",
    ]

    if data_files:
        lines += ["## Data", ""] + [f"- `data/{f}`" for f in data_files] + [""]
    else:
        lines += ["## Data", "", "_No participant data — this experiment was never run._", ""]
    if analysis_files:
        lines += ["## Analysis", ""] + [f"- `analysis/{f}`" for f in analysis_files] + [""]

    lines += ["---", "",
              f"_Generated by `tools/build_experiment_folders.py` on "
              f"{datetime.date.today().isoformat()}. Source of truth is the repo root; "
              f"this folder is a copy._", ""]

    with open(os.path.join(base, "README.md"), "w") as fh:
        fh.write("\n".join(lines))


def write_index():
    L = ["# Human-participant Name Game experiments", "",
         "One folder per experiment, named by launch date. Each `code/` folder is a "
         "**complete, self-contained oTree project** — that is the folder you upload "
         "via Cyberduck. `settings.py` in each is trimmed to only that experiment's "
         "session configs.", "",
         "| launched | experiment | participants | status |", "|---|---|---|---|"]
    for exp in sorted(EXPERIMENTS, key=lambda x: x["date"]):
        launched = not exp.get("never_launched")
        n = f"{exp['n_participants']}" if launched else "—"
        status = "collected" if launched else "built, never run"
        L.append(f"| `{exp['date']}` | [{exp['title']}]({exp['date']}_{exp['slug']}/) "
                 f"| {n} | {status} |")
    L += ["", "## Deploying one", "",
          "```bash", "cd <experiment>/code",
          "cp secrets.env.example secrets.env    # fill in on the server",
          "otree zip                             # or upload the folder contents directly",
          "```", "",
          "> `secrets.env` is never included in these folders — it holds live API keys.", "",
          "Rebuild with `python3 tools/build_experiment_folders.py --force`.",
          "Source of truth stays the repo root; these are copies.", ""]
    with open(os.path.join(OUT_ROOT, "README.md"), "w") as fh:
        fh.write("\n".join(L))


def main():
    settings_src = open(os.path.join(ROOT, "settings.py")).read()
    os.makedirs(OUT_ROOT, exist_ok=True)
    print(f"building into {OUT_ROOT}")
    for exp in EXPERIMENTS:
        build(exp, settings_src)
    write_index()
    print("  wrote experiments/README.md")


if __name__ == "__main__":
    main()
