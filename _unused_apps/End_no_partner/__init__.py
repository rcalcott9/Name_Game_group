from otree.api import *


class C(BaseConstants):
    NAME_IN_URL = 'End_no_partner'
    PLAYERS_PER_GROUP = None
    NUM_ROUNDS = 1


class Subsession(BaseSubsession):
    pass


class Group(BaseGroup):
    pass


class Player(BasePlayer):
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

    # Player evaluation questions - moral appropriateness for rounds 13, 14, 15
    player2_moral_appropriate_r13 = models.IntegerField(
        label='How morally appropriate were Player 2\'s letter choices in round 13?',
        min=0, max=100
    )
    
    player2_moral_appropriate_r14 = models.IntegerField(
        label='How morally appropriate were Player 2\'s letter choices in round 14?',
        min=0, max=100
    )
    
    player2_moral_appropriate_r15 = models.IntegerField(
        label='How morally appropriate were Player 2\'s letter choices in round 15?',
        min=0, max=100
    )
    
    player3_moral_appropriate_r13 = models.IntegerField(
        label='How morally appropriate were Player 3\'s letter choices in round 13?',
        min=0, max=100
    )
    
    player3_moral_appropriate_r14 = models.IntegerField(
        label='How morally appropriate were Player 3\'s letter choices in round 14?',
        min=0, max=100
    )
    
    player3_moral_appropriate_r15 = models.IntegerField(
        label='How morally appropriate were Player 3\'s letter choices in round 15?',
        min=0, max=100
    )
    
    player4_moral_appropriate_r13 = models.IntegerField(
        label='How morally appropriate were Player 4\'s letter choices in round 13?',
        min=0, max=100
    )
    
    player4_moral_appropriate_r14 = models.IntegerField(
        label='How morally appropriate were Player 4\'s letter choices in round 14?',
        min=0, max=100
    )
    
    player4_moral_appropriate_r15 = models.IntegerField(
        label='How morally appropriate were Player 4\'s letter choices in round 15?',
        min=0, max=100
    )

    # Player evaluation questions - cooperation
    player2_cooperative = models.IntegerField(
        label='Overall, how cooperative was Player 2?',
        min=0, max=100
    )
    
    player3_cooperative = models.IntegerField(
        label='Overall, how cooperative was Player 3?',
        min=0, max=100
    )
    
    player4_cooperative = models.IntegerField(
        label='Overall, how cooperative was Player 4?',
        min=0, max=100
    )

    # Partner authenticity confidence
    partner_authenticity_confidence = models.IntegerField(
        label='How confident were you that you were playing with actual human partners (rather than computer-generated responses)?',
        min=0, max=100
    )


# PAGES

class PartnerEvaluation(Page):
    form_model = 'player'
    form_fields = [
        'player2_moral_appropriate_r13', 'player2_moral_appropriate_r14', 'player2_moral_appropriate_r15',
        'player3_moral_appropriate_r13', 'player3_moral_appropriate_r14', 'player3_moral_appropriate_r15',
        'player4_moral_appropriate_r13', 'player4_moral_appropriate_r14', 'player4_moral_appropriate_r15'
    ]

    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False)) or
                player.participant.vars.get('timed_out', False) or
                player.participant.vars.get('attention_check_failed', False))

    @staticmethod
    def vars_for_template(player):
        # Get treatment from participant vars
        treatment = player.participant.vars.get('treatment')
        
        # Get the total number of rounds from name_game_no_partner
        from name_game_no_partner import Constants as NameGameConstants
        total_rounds = NameGameConstants.num_rounds
        
        # Create rounds data for the table (same logic as FinalResults)
        if treatment == 'experimental':
            sequence = NameGameConstants.partner_sequence_experimental
        else:
            sequence = NameGameConstants.partner_sequence_control
            
        rounds_data = []
        for round_num in range(1, total_rounds + 1):
            # Get player's choice from that round
            try:
                round_player = player.participant._get_player_for_round(round_num, 'name_game_no_partner')
                my_choice = round_player.letter_choice if round_player else 'N/A'
            except:
                my_choice = 'N/A'
            
            # Generate fake player choices (same logic as FinalResults)
            if treatment == 'experimental' and round_num == (total_rounds - 1):  # Second-to-last round
                player2_choice = 'C'
            elif round_num == 1:
                player2_choice = 'J'
            elif round_num == 2:
                player2_choice = 'P'
            elif round_num == 3:
                player2_choice = 'R'
            elif round_num == 4:
                player2_choice = 'D'
            elif round_num == 5:
                player2_choice = 'J'
            else:
                player2_choice = 'J'
            
            # Player 3: Quicker to learn but with some variation
            if round_num == 1:
                player3_choice = 'J'
            elif round_num == 2:
                player3_choice = 'C'
            elif round_num == 3:
                player3_choice = 'J'
            elif round_num == 4:
                player3_choice = 'P'
            elif round_num == 7:
                player3_choice = 'R'
            else:
                player3_choice = 'J'
            
            # Player 4: Most cooperative but not identical
            if round_num == 1:
                player4_choice = 'J'
            elif round_num == 2:
                player4_choice = 'C'
            elif round_num == 3:
                player4_choice = 'C'
            elif round_num == 6:
                player4_choice = 'D'
            else:
                player4_choice = 'J'
            
            rounds_data.append({
                'round_num': round_num,
                'my_choice': my_choice,
                'player2_choice': player2_choice,
                'player3_choice': player3_choice,
                'player4_choice': player4_choice
            })

        return {
            'rounds_data': rounds_data,
            'total_rounds': total_rounds
        }

class PartnerCooperation(Page):
    form_model = 'player'
    form_fields = [
        'player2_cooperative', 
        'player3_cooperative', 
        'player4_cooperative'
    ]

    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False)) or
                player.participant.vars.get('timed_out', False) or
                player.participant.vars.get('attention_check_failed', False))

    @staticmethod
    def vars_for_template(player):
        # Get treatment from participant vars
        treatment = player.participant.vars.get('treatment')
        
        # Get the total number of rounds from name_game_no_partner
        from name_game_no_partner import Constants as NameGameConstants
        total_rounds = NameGameConstants.num_rounds
        
        # Create rounds data for the table (same logic as PartnerEvaluation)
        if treatment == 'experimental':
            sequence = NameGameConstants.partner_sequence_experimental
        else:
            sequence = NameGameConstants.partner_sequence_control
            
        rounds_data = []
        for round_num in range(1, total_rounds + 1):
            # Generate fake player choices (same logic as PartnerEvaluation)
            if treatment == 'experimental' and round_num == (total_rounds - 1):  # Second-to-last round
                player2_choice = 'C'
            elif round_num == 1:
                player2_choice = 'J'
            elif round_num == 2:
                player2_choice = 'P'
            elif round_num == 3:
                player2_choice = 'R'
            elif round_num == 4:
                player2_choice = 'D'
            elif round_num == 5:
                player2_choice = 'J'
            else:
                player2_choice = 'J'
            
            # Player 3: Quicker to learn but with some variation
            if round_num == 1:
                player3_choice = 'J'
            elif round_num == 2:
                player3_choice = 'C'
            elif round_num == 3:
                player3_choice = 'J'
            elif round_num == 4:
                player3_choice = 'P'
            elif round_num == 7:
                player3_choice = 'R'
            else:
                player3_choice = 'J'
            
            # Player 4: Most cooperative but not identical
            if round_num == 1:
                player4_choice = 'J'
            elif round_num == 2:
                player4_choice = 'C'
            elif round_num == 3:
                player4_choice = 'C'
            elif round_num == 6:
                player4_choice = 'D'
            else:
                player4_choice = 'J'
            
            rounds_data.append({
                'round_num': round_num,
                'player2_choice': player2_choice,
                'player3_choice': player3_choice,
                'player4_choice': player4_choice
            })

        return {
            'rounds_data': rounds_data,
            'total_rounds': total_rounds
        }

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


class PartnerAuthenticity(Page):
    form_model = 'player'
    form_fields = ['partner_authenticity_confidence']

    @staticmethod
    def is_displayed(player):
        return ((player.participant.vars.get('consent', False) == True and
                 not player.participant.vars.get('attention_check_failed', False)) or
                player.participant.vars.get('timed_out', False) or
                player.participant.vars.get('attention_check_failed', False))

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


page_sequence = [PartnerEvaluation, PartnerCooperation, Attitudes, PartnerAuthenticity, Demographics, Debrief, PaymentInfo]
