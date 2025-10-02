# __init__.py

from otree.api import *
import random

doc = """
Single player matching game that simulates playing with a partner.
Players see a simulated partner's choice and get feedback as if playing with a real person.
15 rounds total: 3 random, 9 same letter, 3 different letter.
"""

import random


class Constants(BaseConstants):
    name_in_url = 'name_game_no_partner'
    players_per_group = None  # Single player game
    num_rounds = 15

    letter_choices = ['J', 'P', 'R', 'C', 'D']

    # Define the partner sequence patterns for two treatments
    # Treatment 1: Always J (control)
    partner_sequence_control = (
            ['J', 'C', 'R'] +  # Rounds 1-3: some random letters
            ['J'] * 12  # Rounds 4-15: always J
    )
    
    # Treatment 2: J with C in second-to-last round (experimental)
    partner_sequence_experimental = (
            ['J', 'C', 'R'] +  # Rounds 1-3: some random letters
            ['J'] * 10 +  # Rounds 4-13: J
            ['C'] +  # Round 14: different letter (second-to-last)
            ['J']  # Round 15: back to J (last round)
    )


def get_randomized_letters():
    """Get a fresh randomized order of letters for each round"""
    import random
    choices = list(Constants.letter_choices)
    random.shuffle(choices)
    return choices


class Subsession(BaseSubsession):
    pass


class Group(BaseGroup):
    pass


class Player(BasePlayer):
    letter_choice = models.StringField(
        choices=Constants.letter_choices,
        label="Your letter choice:"
    )
    
    treatment = models.StringField(
        choices=[['control', 'Control'], ['experimental', 'Experimental']]
    )

    def get_partner_choice(self):
        """Get the partner's choice for this round from the predefined sequence based on treatment"""
        # Get treatment from participant vars (assigned in round 1)
        treatment = self.participant.vars.get('treatment')
        
        if treatment == 'experimental':
            sequence = Constants.partner_sequence_experimental
        else:
            sequence = Constants.partner_sequence_control
            
        if self.round_number <= len(sequence):
            return sequence[self.round_number - 1]
        return 'J'  # Fallback


# PAGES

class WaitingForPartner(Page):
    """Simulated waiting page with 30 second countdown"""
    timeout_seconds = 20

    def is_displayed(player):
        # Assign treatment when player first arrives (round 1 only)
        if (player.round_number == 1 and
            player.participant.vars.get('consent', False) == True and
            not player.participant.vars.get('attention_check_failed', False)):
            
            # Alternate treatment assignment: odd players get control, even get experimental
            if player.id_in_subsession % 2 == 1:
                treatment = 'control'
            else:
                treatment = 'experimental'
            
            # Store treatment
            player.treatment = treatment
            player.participant.vars['treatment'] = treatment
            
            # Also assign treatment to all rounds for this player
            for round_player in player.in_all_rounds():
                round_player.treatment = treatment
            
            return True
        
        return False


class Name_Game(Page):
    form_model = 'player'
    form_fields = ['letter_choice']

    def is_displayed(player):
        return (player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    def vars_for_template(player):
        # Get treatment from participant vars (assigned in round 1)
        treatment = player.participant.vars.get('treatment')
        if treatment == 'experimental':
            sequence = Constants.partner_sequence_experimental
        else:
            sequence = Constants.partner_sequence_control
            
        # Get partner's choice from previous round (only available from round 2 onwards)
        partner_previous_choice = None
        if player.round_number > 1:
            partner_previous_choice = sequence[player.round_number - 2]

        return {
            'round_num': player.round_number,
            'previous_round': player.round_number - 1 if player.round_number > 1 else None,
            'total_rounds': Constants.num_rounds,
            'randomized_letters': get_randomized_letters()
        }


class WaitingForPartnerAnswer(Page):
    """Simulated waiting page with countdown before results"""
    timeout_seconds = 3

    def is_displayed(player):
        return (player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))


class Results(Page):

    def is_displayed(player):
        return (player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    def vars_for_template(player):
        # Get partner choice for this round
        partner_choice = player.get_partner_choice()
        matched = player.letter_choice == partner_choice

        return {
            'my_choice': player.letter_choice,
            'partner_choice': partner_choice,
            'matched': matched,
            'round_num': player.round_number,
            'total_rounds': Constants.num_rounds
        }


class WaitingForReshuffling(Page):
    """Simulated reshuffling page to make it appear like multiplayer"""
    timeout_seconds = 5

    def is_displayed(player):
        # Show for all rounds except the last one
        return (player.round_number < Constants.num_rounds and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    def vars_for_template(player):
        return {
            'round_num': player.round_number,
            'next_round': player.round_number + 1,
            'total_rounds': Constants.num_rounds
        }


class FinalResults(Page):
    """Final results page showing summary"""

    def is_displayed(player):
        return (player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False) and
                player.round_number == Constants.num_rounds)

    def vars_for_template(player):
        # Get treatment from participant vars (assigned in round 1)
        treatment = player.participant.vars.get('treatment')
        if treatment == 'experimental':
            sequence = Constants.partner_sequence_experimental
        else:
            sequence = Constants.partner_sequence_control
            
        # Calculate statistics across all rounds
        total_matches = 0
        all_my_choices = []
        all_partner_choices = []

        for round_num in range(1, Constants.num_rounds + 1):
            round_player = player.in_round(round_num)
            partner_choice = sequence[round_num - 1]
            all_my_choices.append(round_player.letter_choice)
            all_partner_choices.append(partner_choice)
            if round_player.letter_choice == partner_choice:
                total_matches += 1

        # Create rounds data for the table
        rounds_data = []
        for round_num in range(1, Constants.num_rounds + 1):
            round_player = player.in_round(round_num)
            partner_choice = sequence[round_num - 1]
            
            # Generate fake player choices with realistic variation
            # Player 2: The one who chose 'C' in second-to-last round (if experimental treatment)
            if treatment == 'experimental' and round_num == (Constants.num_rounds - 1):  # Second-to-last round
                player2_choice = 'C'
            elif round_num == 1:
                player2_choice = 'J'
            elif round_num == 2:
                player2_choice = 'P'  # Different from others in round 2
            elif round_num == 3:
                player2_choice = 'R'
            elif round_num == 4:
                player2_choice = 'D'  # Takes longer to converge
            elif round_num == 5:
                player2_choice = 'J'  # Starts converging
            else:
                player2_choice = 'J'  # Converged
            
            # Player 3: Quicker to learn but with some variation
            if round_num == 1:
                player3_choice = 'J'
            elif round_num == 2:
                player3_choice = 'C'
            elif round_num == 3:
                player3_choice = 'J'  # Converges faster than Player 2
            elif round_num == 4:
                player3_choice = 'P'  # One more attempt
            elif round_num == 7:
                player3_choice = 'R'  # Occasional deviation
            else:
                player3_choice = 'J'  # Mostly cooperative
            
            # Player 4: Most cooperative but not identical
            if round_num == 1:
                player4_choice = 'J'
            elif round_num == 2:
                player4_choice = 'C'
            elif round_num == 3:
                player4_choice = 'C'  # Different pattern from others
            elif round_num == 6:
                player4_choice = 'D'  # One deviation
            else:
                player4_choice = 'J'  # Very cooperative
            
            rounds_data.append({
                'round_num': round_num,
                'my_choice': round_player.letter_choice,
                'player2_choice': player2_choice,
                'player3_choice': player3_choice,
                'player4_choice': player4_choice
            })

        return {
            'total_rounds': Constants.num_rounds,
            'total_matches': total_matches,
            'match_rate': round(total_matches / Constants.num_rounds * 100, 1),
            'completion_message': "Thank you for completing the experiment!",
            'rounds_data': rounds_data
        }


page_sequence = [
    WaitingForPartner,
    Name_Game,
    WaitingForPartnerAnswer,
    Results,
    WaitingForReshuffling,
    FinalResults
]