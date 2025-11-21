from os import environ

SESSION_CONFIGS = [
    # INCENTIVIZED NAME GAME - New version with J, M, N scoring and group coordination requirement
    dict(
        name='name_game_incentivized',
        display_name='Name Game Incentivized (Live)',
        app_sequence=['Intro', 'name_game_incentivized', 'End_name'],
        num_demo_participants=6,  # Can be 2 (dyadic) or 6 (group)
        use_browser_bots=False,
        use_live=True,
        test_mode=False,
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C13MJARL',
    ),
    # TEST MODE: Solo testing - INCENTIVIZED DYADIC
    dict(
        name='test_incentivized_dyadic',
        display_name='TEST: Incentivized Dyadic',
        app_sequence=['Intro', 'name_game_incentivized', 'End_name'],
        num_demo_participants=1,
        use_browser_bots=False,
        use_live=False,
        test_mode=True,
        force_condition='dyadic',
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
    # TEST MODE: Solo testing - INCENTIVIZED GROUP
    dict(
        name='test_incentivized_group',
        display_name='TEST: Incentivized Group',
        app_sequence=['Intro', 'name_game_incentivized', 'End_name'],
        num_demo_participants=1,
        use_browser_bots=False,
        use_live=False,
        test_mode=True,
        force_condition='group',
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
    # DYAD NAME GAME - Main experiment with fixed pairs (J=10, M=15, Q=15 after round 7)
    dict(
        name='dyad_name_game',
        display_name='Dyad Name Game (Live - 2 Players)',
        app_sequence=['Intro', 'Dyad_Name_Game', 'End_name'],
        num_demo_participants=2,
        use_browser_bots=False,
        use_live=True,
        test_mode=False,
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
    # TEST MODE: Solo with Bot - DYAD NAME GAME
    dict(
        name='test_dyad_bot',
        display_name='TEST: Dyad Name Game (Solo with Bot)',
        app_sequence=['Intro', 'Dyad_Name_Game', 'End_name'],
        num_demo_participants=2,
        use_browser_bots=False,
        use_live=False,
        test_mode=True,  # Bot mode
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
    # TEST MODE: Split-screen testing - DYAD NAME GAME (2 real participants)
    dict(
        name='test_dyad_name_game',
        display_name='TEST: Dyad Name Game (Split Screen)',
        app_sequence=['Intro', 'Dyad_Name_Game', 'End_name'],
        num_demo_participants=2,
        use_browser_bots=False,
        use_live=False,
        test_mode=False,  # Changed to False so both participants play
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
    # TEST MODE: Solo testing - DYADIC (2-player)
    dict(
        name='test_dyadic',
        display_name='TEST: Dyadic (2-Player) Condition',
        app_sequence=['Intro', 'name_game', 'End_name'],
        num_demo_participants=2,  # Changed to 2 to satisfy group size requirement
        use_browser_bots=False,
        use_live=False,
        test_mode=True,
        force_condition='dyadic',  # Force dyadic condition
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
    # TEST MODE: Solo testing - GROUP (4-player)
    dict(
        name='test_group',
        display_name='TEST: Group (4-Player) Condition',
        app_sequence=['Intro', 'name_game', 'End_name'],
        num_demo_participants=1,
        use_browser_bots=False,
        use_live=False,
        test_mode=True,
        force_condition='group',  # Force group condition
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
    # UNIFIED: Random assignment to Dyadic or Group conditions within same session
    dict(
        name='name_game',
        display_name='Name Game - Unified (Random Assignment)',
        app_sequence=['Intro', 'name_game', 'End_name'],
        num_demo_participants=4,  # Must be multiple of 4 (can be 2 dyadic pairs or 1 group of 4)
        use_browser_bots=False,
        use_live=True,
        test_mode=False,  # Normal mode requires real partners
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
]

# if you set a property in SESSION_CONFIG_DEFAULTS, it will be inherited by all configs
# in SESSION_CONFIGS, except those that explicitly override it.
# the session config can be accessed from methods in your apps as self.session.config,
# e.g. self.session.config['participation_fee']

SESSION_CONFIG_DEFAULTS = dict(
    real_world_currency_per_point=1.00, participation_fee=0.00, doc=""
)

ROOMS = [dict(
        name='name_game',
        display_name='Name Game',
        # participant_label_file='_rooms/study.txt',
        # use_secure_urls=True,
    ),
    dict(name='live_demo', display_name='Room for live demo (no participant labels)'),
]
PARTICIPANT_FIELDS = []
SESSION_FIELDS = []

# ISO-639 code
# for example: de, fr, ja, ko, zh-hans
LANGUAGE_CODE = 'en'

# e.g. EUR, GBP, CNY, JPY
REAL_WORLD_CURRENCY_CODE = '£'
USE_POINTS = True
POINTS_CUSTOM_NAME = 'points'
USE_CURRENCY_SYMBOLS = False
POINTS_DECIMAL_PLACES = 0

ADMIN_USERNAME = 'admin'
# for security, best to set admin password in an environment variable
ADMIN_PASSWORD = environ.get('OTREE_ADMIN_PASSWORD')

DEMO_PAGE_INTRO_HTML = """ """

SECRET_KEY = 'my_name_game_fork_2025'
