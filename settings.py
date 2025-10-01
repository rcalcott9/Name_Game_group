from os import environ

SESSION_CONFIGS = [
    # dict(
    #     name='public_goods',
    #     app_sequence=['public_goods'],
    #     num_demo_participants=3,
    # ),

dict(
        name='name_game',
        display_name='My Name Game - Custom Version',
        app_sequence=['Intro', 'name_game', 'End_name'],
        num_demo_participants=2,
        use_browser_bots=False,
        use_live=True,
    # completionLink = 'http://app.prolific.co/submissions/complete?cc=C1BZCVDU',  # Update this for your study
    ),

dict(
    name='name_game_no_partner',
        display_name='Name Game No Partner ',
        app_sequence=['Intro', 'name_game_no_partner', 'End_no_partner'],
        num_demo_participants=2,
        use_browser_bots=False,
        use_live=True,
    # completionLink = 'http://app.prolific.co/submissions/complete?cc=C1BZCVDU',  # Update this for your study
    ),

dict(
    name='name_game_4',
        display_name='Name Game Treatments ',
        app_sequence=['Intro' ,'name_game_4', 'End'],
        num_demo_participants=2,
        use_browser_bots=False,
        use_live=True,
    # completionLink = 'http://app.prolific.co/submissions/complete?cc=C1BZCVDU',  # Update this for your study
    ),

dict(
    name='name_game_simple',
        display_name='Name Game Simple ',
        app_sequence=['Intro_simple' ,'name_game_simple', 'End_name'],
        num_demo_participants=2,
        use_browser_bots=False,
        use_live=True,
    # completionLink = 'http://app.prolific.co/submissions/complete?cc=C1BZCVDU',  # Update this for your study
    ),

dict(
    name='name_game_info',
        display_name='Name Game Test ',
        app_sequence=['Intro_simple' ,'name_game_info', 'End_name'],
        num_demo_participants=2,
        use_browser_bots=False,
        use_live=True,
    # completionLink = 'http://app.prolific.co/submissions/complete?cc=C1BZCVDU',  # Update this for your study
    ),

dict(
    name='name_game_test',
        display_name='Name Game Test Actual ',
        app_sequence=['Intro_simple' ,'name_game_4', 'End'],
        num_demo_participants=2,
        use_browser_bots=False,
        use_live=True,
    # completionLink = 'http://app.prolific.co/submissions/complete?cc=C1BZCVDU',  # Update this for your study
    )
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
