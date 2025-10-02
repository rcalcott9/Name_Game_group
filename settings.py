from os import environ

SESSION_CONFIGS = [
    # CONDITION A: Dyadic Coordination (2 players, same partner throughout)
    dict(
        name='name_game_dyadic',
        display_name='Name Game - Dyadic Condition (2 Players)',
        app_sequence=['Intro_dyadic', 'name_game_dyadic', 'End_name'],
        num_demo_participants=2,
        use_browser_bots=False,
        use_live=True,
        # completionLink = 'http://app.prolific.co/submissions/complete?cc=YOUR_CODE_HERE',
    ),

    # CONDITION B: Group Coordination (4 players, reshuffled partners)
    dict(
        name='name_game_group',
        display_name='Name Game - Group Condition (4 Players)',
        app_sequence=['Intro_group', 'name_game_group', 'End_name'],
        num_demo_participants=4,
        use_browser_bots=False,
        use_live=True,
        # completionLink = 'http://app.prolific.co/submissions/complete?cc=YOUR_CODE_HERE',
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
