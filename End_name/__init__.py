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
    # Post-game strategy questions
    developed_rule = models.BooleanField(
        label='Did you develop a rule for which letter you chose?',
        choices=[
            [True, 'Yes'],
            [False, 'No']
        ],
        widget=widgets.RadioSelect
    )

    decision_explanation = models.LongStringField(
        label='Please explain how you decided which letter to choose:',
        blank=True
    )

    moral_wrongness = models.IntegerField(
        label='If your partner stopped choosing the letter that you had coordinated on, how morally wrong would that be?',
        choices=[
            [1, '1 - Not at all morally wrong'],
            [2, '2'],
            [3, '3'],
            [4, '4'],
            [5, '5'],
            [6, '6'],
            [7, '7 - Very morally wrong']
        ],
        widget=widgets.RadioSelect
    )

    additional_comments = models.LongStringField(
        label='Is there anything else you would like to tell the experimenters?',
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
                player.participant.vars.get('timed_out', True) or
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
    form_fields = ['developed_rule', 'decision_explanation', 'moral_wrongness', 'additional_comments']

    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False)) or
                player.participant.vars.get('timed_out', False) or
                player.participant.vars.get('attention_check_failed', False))

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
                 not player.participant.vars.get('attention_check_failed', False)) or
                player.participant.vars.get('timed_out', False) or
                player.participant.vars.get('attention_check_failed', False))


class Debrief(Page):
    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False)) or
                player.participant.vars.get('timed_out', False) or
                player.participant.vars.get('attention_check_failed', False))

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
                 not player.participant.vars.get('attention_check_failed', False)) or
                player.participant.vars.get('timed_out', False) or
                player.participant.vars.get('attention_check_failed', False))

class PaymentInfo(Page):
    form_model = 'player'

    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False)) or
                player.participant.vars.get('timed_out', False) or
                player.participant.vars.get('attention_check_failed', False))

    @staticmethod
    def js_vars(player):
        return dict(
            completionLink=
              player.subsession.session.config['completionLink']
        )
    pass


page_sequence = [End_Section, PostGameQuestions, Demographics, Debrief, PaymentInfo]
