from otree.api import *


class C(BaseConstants):
    NAME_IN_URL = 'End_name'
    PLAYERS_PER_GROUP = None
    NUM_ROUNDS = 1


class Subsession(BaseSubsession):
    pass


class Group(BaseGroup):
    pass


class Player(BasePlayer):
    # Rule-following questions
    following_rule = models.BooleanField(
        label='When you picked letters, were you following a rule?',
        choices=[
            [True, 'Yes'],
            [False, 'No']
        ],
        widget=widgets.RadioSelect
    )

    what_rule = models.LongStringField(
        label='What rule were you following?',
        blank=True
    )

    rule_importance = models.IntegerField(
        label='How important was it for you to follow this rule?',
        choices=[
            [1, '1 - Not at all important'],
            [2, '2'],
            [3, '3'],
            [4, '4'],
            [5, '5'],
            [6, '6'],
            [7, '7 - Extremely important']
        ],
        widget=widgets.RadioSelect,
        blank=True
    )

    same_rule_from_start = models.IntegerField(
        label='To what extent did you follow the same rule from the start?',
        choices=[
            [1, '1 - Not at all'],
            [2, '2'],
            [3, '3'],
            [4, '4'],
            [5, '5'],
            [6, '6'],
            [7, '7 - Completely']
        ],
        widget=widgets.RadioSelect,
        blank=True
    )

    num_rules_followed = models.IntegerField(
        label='How many different rules did you follow?',
        choices=[
            [0, '0 - Zero rules'],
            [1, '1 - One rule'],
            [2, '2 - Two rules']
        ],
        widget=widgets.RadioSelect,
        blank=True
    )

    rule_advice = models.LongStringField(
        label='If you had to tell a new participant what rule to follow to succeed at this game, what would you tell them?',
        blank=True
    )

    feedback = models.StringField(
        label='Your Feedback:',
        blank=True
    )

    gender = models.StringField(
        label='What is your gender?',
        choices=[
            [1, 'Male'],
            [2, 'Female'],
            [2, 'Non-binary'],
            [2, 'Other'],
            [3, 'Prefer not to say'],
        ],
        widget=widgets.RadioSelect
    )

    age = models.IntegerField(
        label='What is your age? (Enter a number, or leave blank if you prefer not to say)',
        min=18,
        max=100,
        blank=True
    )


# PAGES

class End_Section(Page):

    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False)) or
                player.participant.vars.get('timed_out', False) or
                player.participant.vars.get('matching_timeout', False) or
                player.participant.vars.get('attention_check_failed', False))

    @staticmethod
    def vars_for_template(player):
        # Get total points from participant vars
        total_points = player.participant.vars.get('total_points', 0)

        # Convert points to dollars and format properly
        total_pay = f"${total_points / 100:.2f}"

        return {
            'total_points': total_points,
            'total_pay': total_pay  # This will show $0.20 instead of $0.2
        }

class PostGameQuestions(Page):
    form_model = 'player'
    form_fields = ['following_rule', 'what_rule', 'rule_importance', 'same_rule_from_start', 'num_rules_followed', 'rule_advice']

    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False) and
                 not player.participant.vars.get('matching_timeout', False)) or
                player.participant.vars.get('timed_out', False))

    @staticmethod
    def vars_for_template(player):
        # Determine condition based on session config name
        session_config_name = player.session.config['name']
        is_dyadic = 'dyadic' in session_config_name
        is_group = 'group' in session_config_name

        return {
            'is_dyadic': is_dyadic,
            'is_group': is_group
        }


class Attitudes (Page):
    form_model = 'player'
    form_fields = ['feedback']

    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False) and
                 not player.participant.vars.get('matching_timeout', False)) or
                player.participant.vars.get('timed_out', False))


class Debrief(Page):
    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False) and
                 not player.participant.vars.get('matching_timeout', False)) or
                player.participant.vars.get('timed_out', False))

    @staticmethod
    def vars_for_template(player):
        # Get total points from participant vars (stored by abstract app)
        total_points = player.participant.vars.get('total_points', 0)

        # Convert points to dollars and format as string
        total_pay = f"${total_points / 100:.2f}"

        return {
            'total_points': total_points,
            'total_pay': total_pay
        }


class Demographics (Page):
    form_model = 'player'
    form_fields = ['age', 'gender']

    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False) and
                 not player.participant.vars.get('matching_timeout', False)) or
                player.participant.vars.get('timed_out', False))

class PaymentInfo(Page):
    form_model = 'player'

    @staticmethod
    def is_displayed(player):
        return (player.participant.vars.get('consent', False) == True or
                player.participant.vars.get('timed_out', False) or
                player.participant.vars.get('matching_timeout', False) or
                player.participant.vars.get('attention_check_failed', False))

    @staticmethod
    def js_vars(player):
        return dict(
            completionLink=
              player.subsession.session.config['completionLink']
        )
    pass


page_sequence = [End_Section, PostGameQuestions, Demographics, Debrief, PaymentInfo]
