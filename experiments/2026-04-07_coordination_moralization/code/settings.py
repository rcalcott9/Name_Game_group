from os import environ

SESSION_CONFIGS = [
    dict(
        name='coordination_moralization',
        display_name='Coordination Moralization (Third-Person)',
        app_sequence=['coordination_moralization'],
        num_demo_participants=1,
        use_browser_bots=False,
        use_live=False,
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
    dict(
        name='coordination_moralization_solo',
        display_name='Coordination Moralization - Solo',
        app_sequence=['coordination_moralization'],
        num_demo_participants=1,
        use_browser_bots=False,
        use_live=False,
        condition='solo',
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
    dict(
        name='coordination_moralization_coordination',
        display_name='Coordination Moralization - Coordination',
        app_sequence=['coordination_moralization'],
        num_demo_participants=1,
        use_browser_bots=False,
        use_live=False,
        condition='coordination',
        completionLink = 'https://app.prolific.com/submissions/complete?cc=C1G9K0Z2',
    ),
]


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
