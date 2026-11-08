# __init__.py

from otree.api import *
import random

doc = """
Third-person observation of coordination behavior with knowledge manipulation.
Participants observe Sam and Alex playing a coordination game across 10 rounds.
Between-subjects conditions:
- Mutual Knowledge (coordination): Both Sam and Alex know they're coordinating with each other
  Sam's sequence: T, S, J×7, R (chooses J starting round 3, deviates to R in final round)
- Asymmetric Knowledge (solo): Sam knows he's coordinating with Alex, but Alex thinks he's playing a computer game
  Sam's sequence: T, S, J×7, C (chooses J starting round 3, deviates to C in final round)
Alex's sequence (both conditions): C, R, S, J×7 (chooses J starting round 4)
Sam discovers J one round before Alex, making the coordination more realistic.
DV: Moral wrongness, blame, and punishment deservingness of Sam's final-round deviation
"""


class Constants(BaseConstants):
    name_in_url = 'coordination_moralization'
    players_per_group = None  # Single observer
    num_rounds = 10

    letter_choices = ['J', 'C', 'R', 'S', 'T']

    # Point values - matching gives 10 points
    point_values = {'J': 10, 'C': 10, 'R': 10, 'S': 10, 'T': 10}

    # Alex's sequence (same in both conditions): C, R, S, then J for remaining rounds (starts J on round 4)
    player_b_sequence = ['C', 'R', 'S', 'J', 'J', 'J', 'J', 'J', 'J', 'J']

    # Sam's sequences vary by condition
    # Sam chooses J one round before Alex (starts J on round 3)
    # Solo (asymmetric knowledge): Sam knows he's coordinating, Alex doesn't - Sam deviates to C in final round
    player_a_sequence_solo = ['T', 'S', 'J', 'J', 'J', 'J', 'J', 'J', 'J', 'C']

    # Coordination (mutual knowledge): Both know - Sam deviates to R in final round
    player_a_sequence_coordination = ['T', 'S', 'J', 'J', 'J', 'J', 'J', 'J', 'J', 'R']


class Subsession(BaseSubsession):
    def creating_session(self):
        if self.round_number == 1:
            import time
            for player in self.get_players():
                # Random assignment (for live sessions)
                if 'condition' not in player.participant.vars:
                    random.seed(time.time() + player.id_in_subsession)
                    condition = random.choice(['solo', 'coordination'])

                    print(f"Player {player.id_in_subsession} assigned to: {condition}")

                    player.condition = condition
                    player.participant.vars['condition'] = condition

                    # Assign to all rounds
                    for round_player in player.in_all_rounds():
                        round_player.condition = condition


class Group(BaseGroup):
    pass


class Player(BasePlayer):
    # Condition assignment
    condition = models.StringField(
        choices=[['solo', 'Solo Game'], ['coordination', 'Coordination']]
    )

    # Comprehension check questions
    comp_what_sam_thinks = models.StringField(
        label="What does Sam think about the game?",
        widget=widgets.RadioSelect,
        choices=[
            ['coordination', 'Sam thinks he is coordinating with another person'],
            ['algorithm', 'Sam thinks he is playing an algorithm'],
            ['neither', 'Sam doesn\'t know what kind of game he is playing']
        ],
        blank=True
    )

    comp_what_alex_thinks = models.StringField(
        label="What does Alex think about the game?",
        widget=widgets.RadioSelect,
        choices=[
            ['coordination', 'Alex thinks he is coordinating with another person'],
            ['algorithm', 'Alex thinks he is playing an algorithm'],
            ['neither', 'Alex doesn\'t know what kind of game he is playing']
        ],
        blank=True
    )

    comp_visibility = models.StringField(
        label="What can the players see?",
        widget=widgets.RadioSelect,
        choices=[
            ['see_choices', 'Both players can see each other\'s letter choices before making their own'],
            ['see_points', 'Neither player can see the other\'s choice, only the points earned'],
            ['see_nothing', 'Neither player can see anything about the other player']
        ],
        blank=True
    )

    # Moral judgment questions (final round only)
    moral_wrongness = models.IntegerField(
        label="How morally wrong was Sam's choice in the final round?",
        choices=[1, 2, 3, 4, 5, 6, 7],
        widget=widgets.RadioSelectHorizontal,
        blank=True
    )

    blame = models.IntegerField(
        label="How much do you blame Sam for their choice in the final round?",
        choices=[1, 2, 3, 4, 5, 6, 7],
        widget=widgets.RadioSelectHorizontal,
        blank=True
    )

    deserves_punishment = models.IntegerField(
        label="To what extent does Sam deserve to be punished for their choice?",
        choices=[1, 2, 3, 4, 5, 6, 7],
        widget=widgets.RadioSelectHorizontal,
        blank=True
    )

    def get_player_a_choice(self):
        """Get Sam's choice for this round (varies by condition)"""
        condition = self.participant.vars.get('condition')
        if condition == 'solo':
            return Constants.player_a_sequence_solo[self.round_number - 1]
        else:
            return Constants.player_a_sequence_coordination[self.round_number - 1]

    def get_player_b_choice(self):
        """Get Alex's choice for this round (same in both conditions)"""
        return Constants.player_b_sequence[self.round_number - 1]

    def get_points_earned(self):
        """Calculate points earned this round - matching gives 10 points"""
        player_a_choice = self.get_player_a_choice()
        player_b_choice = self.get_player_b_choice()

        # Both conditions now require coordination for points
        if player_a_choice == player_b_choice:
            return Constants.point_values[player_a_choice]
        else:
            return 0

    def get_history(self):
        """Get all previous rounds' data for display"""
        history = []
        condition = self.participant.vars.get('condition')

        for round_num in range(1, self.round_number + 1):
            round_player = self.in_round(round_num)

            # Get Sam's choice (varies by condition)
            if condition == 'solo':
                player_a = Constants.player_a_sequence_solo[round_num - 1]
            else:
                player_a = Constants.player_a_sequence_coordination[round_num - 1]

            # Get Alex's choice (same in both conditions)
            player_b = Constants.player_b_sequence[round_num - 1]

            # Calculate points - matching gives 10 points
            points = Constants.point_values[player_a] if player_a == player_b else 0

            history.append({
                'round': round_num,
                'player_a': player_a,
                'player_b': player_b,
                'points': points
            })

        return history


# PAGES

class Introduction(Page):
    """Introduction page - basic cover story"""

    def is_displayed(player):
        return player.round_number == 1

    def vars_for_template(player):
        # Set condition if not already set
        if 'condition' not in player.participant.vars:
            # Check if session config specifies a condition
            session_condition = player.session.config.get('condition', None)

            if session_condition in ['solo', 'coordination']:
                condition = session_condition
            else:
                # Random assignment
                import time
                random.seed(time.time())
                condition = random.choice(['solo', 'coordination'])

            player.participant.vars['condition'] = condition
            player.condition = condition
            # Assign to all rounds
            for round_player in player.in_all_rounds():
                round_player.condition = condition

        return {
            'condition': player.participant.vars.get('condition')
        }


class GameRules(Page):
    """Explain basic game mechanics"""

    def is_displayed(player):
        return player.round_number == 1

    def vars_for_template(player):
        return {
            'condition': player.participant.vars.get('condition')
        }


class KnowledgeStructure(Page):
    """Visual demonstration of who knows what"""

    def is_displayed(player):
        return player.round_number == 1

    def vars_for_template(player):
        return {
            'condition': player.participant.vars.get('condition')
        }


class ComprehensionCheck(Page):
    """Comprehension check to ensure participant understands the knowledge structure"""
    form_model = 'player'
    form_fields = ['comp_what_sam_thinks', 'comp_what_alex_thinks', 'comp_visibility']

    def is_displayed(player):
        return player.round_number == 1

    def error_message(player, values):
        condition = player.participant.vars.get('condition')
        errors = {}

        # Sam always thinks he's coordinating
        if values['comp_what_sam_thinks'] != 'coordination':
            errors['comp_what_sam_thinks'] = 'Incorrect. Please review the instructions.'

        # Alex thinks coordination or algorithm depending on condition
        if condition == 'solo':
            if values['comp_what_alex_thinks'] != 'algorithm':
                errors['comp_what_alex_thinks'] = 'Incorrect. Please review the instructions.'
        else:  # coordination
            if values['comp_what_alex_thinks'] != 'coordination':
                errors['comp_what_alex_thinks'] = 'Incorrect. Please review the instructions.'

        # Players can only see points, not each other's choices
        if values['comp_visibility'] != 'see_points':
            errors['comp_visibility'] = 'Incorrect. Please review the instructions.'

        if errors:
            return errors

    def vars_for_template(player):
        return {
            'condition': player.participant.vars.get('condition')
        }


class Observation(Page):
    """Show Player A's choice this round with history"""

    def is_displayed(player):
        return player.round_number <= Constants.num_rounds

    def vars_for_template(player):
        condition = player.participant.vars.get('condition')
        player_a_choice = player.get_player_a_choice()
        player_b_choice = player.get_player_b_choice()  # Always get Alex's choice in both conditions
        points_earned = player.get_points_earned()

        # Calculate total points so far
        total_points = sum([p.get_points_earned() for p in player.in_all_rounds()])

        # Get history
        history = player.get_history()

        # Get point values for current choices
        player_a_points = Constants.point_values.get(player_a_choice, 0)
        player_b_points = Constants.point_values.get(player_b_choice, 0)

        return {
            'condition': condition,
            'round_num': player.round_number,
            'total_rounds': Constants.num_rounds,
            'player_a_choice': player_a_choice,
            'player_b_choice': player_b_choice,
            'player_a_points': player_a_points,
            'player_b_points': player_b_points,
            'points_earned': points_earned,
            'total_points': total_points,
            'history': history,
            'is_final_round': player.round_number == Constants.num_rounds
        }


class MoralJudgment(Page):
    """Moral evaluation of Player A (final round only)"""
    form_model = 'player'
    form_fields = ['moral_wrongness', 'blame', 'deserves_punishment']

    def is_displayed(player):
        return player.round_number == Constants.num_rounds

    def vars_for_template(player):
        condition = player.participant.vars.get('condition')
        history = player.get_history()
        total_points = sum([h['points'] for h in history])

        return {
            'condition': condition,
            'history': history,
            'total_points': total_points
        }


class Results(Page):
    """Final summary"""

    def is_displayed(player):
        return player.round_number == Constants.num_rounds

    def vars_for_template(player):
        condition = player.participant.vars.get('condition')
        history = player.get_history()
        total_points = sum([h['points'] for h in history])
        each_player_gets = total_points // 2
        total_pay = f"${total_points / 100:.2f}"

        return {
            'condition': condition,
            'history': history,
            'total_points': total_points,
            'each_player_gets': each_player_gets,
            'total_pay': total_pay
        }


page_sequence = [
    Introduction,
    GameRules,
    KnowledgeStructure,
    ComprehensionCheck,
    Observation,
    MoralJudgment,
    Results
]
