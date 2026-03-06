from otree.api import *
import random


class C(BaseConstants):
    NAME_IN_URL = 'consent'
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
    
    # Treatment assignment field
    treatment = models.StringField()


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

    @staticmethod
    def before_next_page(player, timeout_happened):
        # Store prolific ID
        player.participant.vars['prolific_ID'] = player.prolific_ID


class TreatmentAssignment(Page):
    @staticmethod
    def is_displayed(player):
        return (player.in_round(1).consent == True and
                player.participant.vars.get('prolific_ID') and
                not player.participant.vars.get('treatment'))

    @staticmethod
    def before_next_page(player, timeout_happened):
        # Randomly assign to one of two treatments: feedback or no_feedback
        # 50% to feedback, 50% to no_feedback

        if random.random() < 0.5:
            treatment = 'feedback'
        else:
            treatment = 'no_feedback'

        # Store treatment
        player.treatment = treatment
        player.participant.vars['treatment'] = treatment

        print(f"Participant {player.participant.code} (ID: {player.id_in_subsession}) assigned to treatment: {treatment}")

    timeout_seconds = 5


class PaymentInfo(Page):
    form_model = 'player'

    @staticmethod
    def is_displayed(player):
        return player.in_round(1).consent == False

    @staticmethod
    def js_vars(player):
        return dict(
            completionLink=
            player.subsession.session.config.get('completionLink', '')
        )


page_sequence = [Consent, Prolific, TreatmentAssignment, PaymentInfo]