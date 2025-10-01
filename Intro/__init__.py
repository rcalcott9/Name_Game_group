from otree.api import *
import random


class C(BaseConstants):
    NAME_IN_URL = 'Intro'
    PLAYERS_PER_GROUP = None
    NUM_ROUNDS = 1


class Subsession(BaseSubsession):
    pass


class Group(BaseGroup):
    pass


class Player(BasePlayer):
    consent = models.BooleanField(
        label="I have read all the above and",
        choices=[[True, "I consent to take part in this study"],
                 [False, "I do not wish to participate"]],
    )

    prolific_ID = models.StringField(default=str(" "))

    # Attention check tracking
    attention_check_attempts = models.IntegerField(initial=0)
    attention_check_failed = models.BooleanField(initial=False)

    # Attention check questions
    attention_check_1 = models.StringField(
        label='What is your goal in each round?',
        choices=[
            ['choose_same', 'Choose the same letter as your partner'],
            ['choose_different', 'Choose a different letter from your partner'],
            ['choose_fastest', 'Choose your letter as quickly as possible'],
            ['choose_alphabetical', 'Choose letters in alphabetical order']
        ],
        widget=widgets.RadioSelect
    )

    attention_check_2 = models.StringField(
        label='What happens to partnerships after each round?',
        choices=[
            ['stay_same', 'You keep the same partner throughout all rounds'],
            ['choose_partner', 'You can choose your partner each round'],
            ['random_reshuffle', 'Partnerships are randomly reshuffled each round'],
            ['rotate_clockwise', 'Partners rotate in a fixed clockwise pattern']
        ],
        widget=widgets.RadioSelect
    )

    attention_check_3 = models.StringField(
        label='How many rounds will you play in total?',
        choices=[
            ['5_rounds', '5 rounds'],
            ['10_rounds', '10 rounds'],
            ['15_rounds', '15 rounds'],
            ['16_rounds', '16 rounds']
        ],
        widget=widgets.RadioSelect
    )


# PAGES

class Consent(Page):
    form_model = 'player'
    form_fields = ['consent']

    @staticmethod
    def is_displayed(player):
        return player.round_number == 1

    @staticmethod
    def before_next_page(player, timeout_happened):
        # Store consent in participant vars so other apps can access it
        player.participant.vars['consent'] = player.consent

        # Also store prolific ID if it exists
        if player.participant.label:
            player.participant.vars['prolific_ID'] = player.participant.label


class Prolific(Page):
    form_model = 'player'
    form_fields = ['prolific_ID']

    @staticmethod
    def is_displayed(player):
        return (player.in_round(1).consent == True and
                not player.participant.vars.get('prolific_ID'))


class Intro(Page):
    @staticmethod
    def is_displayed(player):
        return (player.in_round(1).consent == True and
                not player.attention_check_failed)


class AttentionCheck(Page):
    form_model = 'player'
    form_fields = ['attention_check_1', 'attention_check_2', 'attention_check_3']

    @staticmethod
    def is_displayed(player):
        return (player.round_number == 1 and
                player.in_round(1).consent == True and
                not player.attention_check_failed and
                player.attention_check_attempts == 0)

    @staticmethod
    def before_next_page(player, timeout_happened):
        player.attention_check_attempts += 1

        # Check answers and store which ones were wrong
        wrong_questions = []
        if player.attention_check_1 != 'choose_same':
            wrong_questions.append('1')
        if player.attention_check_2 != 'random_reshuffle':
            wrong_questions.append('2')
        if player.attention_check_3 != '15_rounds':
            wrong_questions.append('3')

        # Store results for the second page
        player.participant.vars['first_attempt_passed'] = len(wrong_questions) == 0
        player.participant.vars['wrong_questions'] = wrong_questions


class AttentionCheck_2(Page):
    form_model = 'player'
    form_fields = ['attention_check_1', 'attention_check_2', 'attention_check_3']

    @staticmethod
    def is_displayed(player):
        return (player.round_number == 1 and
                player.in_round(1).consent == True and
                not player.attention_check_failed and
                player.attention_check_attempts == 1 and
                not player.participant.vars.get('first_attempt_passed', True))

    @staticmethod
    def vars_for_template(player):
        return {
            'wrong_questions': player.participant.vars.get('wrong_questions', [])
        }

    @staticmethod
    def before_next_page(player, timeout_happened):
        player.attention_check_attempts += 1

        # Check answers for second attempt
        answers_correct = True
        if player.attention_check_1 != 'choose_same':
            answers_correct = False
        if player.attention_check_2 != 'random_reshuffle':
            answers_correct = False
        if player.attention_check_3 != '15_rounds':
            answers_correct = False

        # If they failed the second attempt, mark as failed
        if not answers_correct:
            player.attention_check_failed = True


class Start(Page):
    @staticmethod
    def is_displayed(player):
        return (player.in_round(1).consent == True and
                not player.attention_check_failed)


class PaymentInfo(Page):
    form_model = 'player'

    @staticmethod
    def is_displayed(player):
        return (player.in_round(1).consent == False or
                player.attention_check_failed)

    @staticmethod
    def js_vars(player):
        return dict(
            completionLink=
            player.subsession.session.config['completionLink']
        )


def get_page_sequence():
    sequence = [Consent, Prolific, Intro, AttentionCheck, AttentionCheck_2, Start, PaymentInfo]
    return sequence


page_sequence = get_page_sequence()