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

    # Attention check questions - choices will be set dynamically via methods
    attention_check_1 = models.StringField(
        label='What is your goal in each round?',
        choices=[
            ['choose_same', 'Coordinate to choose the same letter'],
            ['choose_different', 'Choose a different letter from others'],
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
            ['random_reshuffle', 'You are paired with a different player each round'],
            ['rotate_clockwise', 'Partners rotate in a fixed clockwise pattern']
        ],
        widget=widgets.RadioSelect
    )

    attention_check_3 = models.StringField(
        label='How many rounds will you play in total?',
        choices=[
            ['10_rounds', '10 rounds'],
            ['12_rounds', '12 rounds'],
            ['14_rounds', '14 rounds'],
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

        # Assign condition after consent
        if player.consent:
            # Check if this is the Dyad_Name_Game (always dyadic)
            app_sequence = player.session.config.get('app_sequence', [])
            if 'Dyad_Name_Game' in app_sequence:
                player.participant.vars['condition'] = 'dyadic'
            else:
                # Check if condition is forced in session config (for testing)
                forced_condition = player.session.config.get('force_condition')
                if forced_condition:
                    player.participant.vars['condition'] = forced_condition
                else:
                    # Randomly assign condition (50/50)
                    if random.random() < 0.5:
                        player.participant.vars['condition'] = 'dyadic'
                    else:
                        player.participant.vars['condition'] = 'group'

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

    @staticmethod
    def vars_for_template(player):
        condition = player.participant.vars.get('condition', 'dyadic')
        return {
            'condition': condition
        }


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
    def vars_for_template(player):
        condition = player.participant.vars.get('condition', 'dyadic')

        # Get the choices for this player's condition
        if condition == 'dyadic':
            q1_choices = [
                ['choose_same', 'Coordinate with your partner to choose the same letter'],
                ['choose_different', 'Choose a different letter from your partner'],
                ['choose_fastest', 'Choose your letter as quickly as possible'],
                ['choose_alphabetical', 'Choose letters in alphabetical order']
            ]
            q2_choices = [
                ['stay_same', 'You keep the same partner throughout all rounds'],
                ['choose_partner', 'You can choose your partner each round'],
                ['random_reshuffle', 'Partnerships are randomly reshuffled each round'],
                ['rotate_clockwise', 'Partners rotate in a fixed clockwise pattern']
            ]
        else:
            q1_choices = [
                ['choose_same', 'Coordinate so all 6 players in your group choose the same letter'],
                ['choose_different', 'Choose a different letter from other players'],
                ['choose_fastest', 'Choose your letter as quickly as possible'],
                ['choose_alphabetical', 'Choose letters in alphabetical order']
            ]
            q2_choices = [
                ['stay_same', 'You keep the same group throughout all rounds'],
                ['choose_partner', 'You can choose which group members to coordinate with'],
                ['see_all', 'You have only one partner for all round'],
                ['rotate_clockwise', 'Group members rotate in a fixed pattern']
            ]

        return {
            'condition': condition,
            'attention_check_1_choices': q1_choices,
            'attention_check_2_choices': q2_choices,
        }

    @staticmethod
    def before_next_page(player, timeout_happened):
        player.attention_check_attempts += 1
        condition = player.participant.vars.get('condition', 'dyadic')

        # Set correct answers based on condition
        q1_correct = 'choose_same'  # Both conditions need coordination
        if condition == 'dyadic':
            q2_correct = 'stay_same'
        else:
            q2_correct = 'stay_same'  # Group condition: see all players' choices

        # Check answers and store which ones were wrong
        wrong_questions = []
        if player.attention_check_1 != q1_correct:
            wrong_questions.append('1')
        if player.attention_check_2 != q2_correct:
            wrong_questions.append('2')
        if player.attention_check_3 != '14_rounds':
            wrong_questions.append('3')

        # Store results for the second page
        first_attempt_passed = len(wrong_questions) == 0
        player.participant.vars['first_attempt_passed'] = first_attempt_passed
        player.participant.vars['wrong_questions'] = wrong_questions

        # If they passed on first attempt, ensure attention_check_failed is False
        if first_attempt_passed:
            player.attention_check_failed = False
            player.participant.vars['attention_check_failed'] = False


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
        condition = player.participant.vars.get('condition', 'dyadic')

        # Get the choices for this player's condition
        if condition == 'dyadic':
            q1_choices = [
                ['choose_same', 'Coordinate with your partner to choose the same letter'],
                ['choose_different', 'Choose a different letter from your partner'],
                ['choose_fastest', 'Choose your letter as quickly as possible'],
                ['choose_alphabetical', 'Choose letters in alphabetical order']
            ]
            q2_choices = [
                ['stay_same', 'You keep the same partner throughout all rounds'],
                ['choose_partner', 'You can choose your partner each round'],
                ['random_reshuffle', 'Partnerships are randomly reshuffled each round'],
                ['rotate_clockwise', 'Partners rotate in a fixed clockwise pattern']
            ]
        else:
            q1_choices = [
                ['choose_same', 'Coordinate so all 6 players in your group choose the same letter'],
                ['choose_different', 'Choose a different letter from other players'],
                ['choose_fastest', 'Choose your letter as quickly as possible'],
                ['choose_alphabetical', 'Choose letters in alphabetical order']
            ]
            q2_choices = [
                ['stay_same', 'You keep the same group for all rounds'],
                ['choose_partner', 'You can choose which group members to coordinate with'],
                ['see_all', 'You keep the same partner for all rounds'],
                ['rotate_clockwise', 'Group members rotate in a fixed pattern']
            ]

        return {
            'condition': condition,
            'wrong_questions': player.participant.vars.get('wrong_questions', []),
            'attention_check_1_choices': q1_choices,
            'attention_check_2_choices': q2_choices,
        }

    @staticmethod
    def before_next_page(player, timeout_happened):
        player.attention_check_attempts += 1
        condition = player.participant.vars.get('condition', 'dyadic')

        # Set correct answers based on condition
        q1_correct = 'choose_same'  # Both conditions need coordination
        if condition == 'dyadic':
            q2_correct = 'stay_same'
        else:
            q2_correct = 'stay_same'  # Group condition: see all players' choices

        # Check answers for second attempt
        answers_correct = True
        if player.attention_check_1 != q1_correct:
            answers_correct = False
        if player.attention_check_2 != q2_correct:
            answers_correct = False
        if player.attention_check_3 != '14_rounds':
            answers_correct = False

        # Set attention_check_failed based on result
        if not answers_correct:
            player.attention_check_failed = True
        else:
            player.attention_check_failed = False

        # Store in participant vars for other apps
        player.participant.vars['attention_check_failed'] = player.attention_check_failed


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
            player.subsession.session.config.get('completionLink', '')
        )


def get_page_sequence():
    sequence = [Consent, Prolific, Intro, AttentionCheck, AttentionCheck_2, Start, PaymentInfo]
    return sequence


page_sequence = get_page_sequence()
