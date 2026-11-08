# __init__.py

from otree.api import *
import random

doc = """
DYAD NAME GAME: Two players work together as a fixed pair throughout all 14 rounds.
Players coordinate to choose the same letter to earn points.
"""


class Constants(BaseConstants):
    name_in_url = 'dyad_name_game'
    players_per_group = 2  # Fixed pairs only
    num_rounds = 14

    letter_choices = ['Q', 'M', 'X', 'Y', 'F', 'J', 'P', 'R', 'C', 'D']


class Subsession(BaseSubsession):
    pass


class Group(BaseGroup):
    def get_partner(self, player):
        # In dyadic game, partner is simply the other player in the group
        if player.participant.vars.get('timed_out', False):
            return None

        for other_player in self.get_players():
            if other_player.id_in_group != player.id_in_group and not other_player.participant.vars.get('timed_out', False):
                return other_player
        return None


class Player(BasePlayer):
    letter_choice = models.StringField(
        choices=Constants.letter_choices,
        label="Your letter choice:"
    )
    partner_id_in_group = models.IntegerField(blank=True)
    round_points = models.IntegerField(default=0)
    total_points = models.IntegerField(default=0)
    condition = models.StringField()  # Store condition for export

    def calculate_points(self):
        """Calculate points based on letter choice and round number"""
        if not self.letter_choice:
            return 0

        test_mode = self.session.config.get('test_mode', False)

        if test_mode:
            # TEST MODE: Use simulated bot choice
            bot_choice = self.participant.vars.get(f'bot_choice_round_{self.round_number}')
            if not bot_choice or self.letter_choice != bot_choice:
                return 0
            coordinated_letter = self.letter_choice
        else:
            # NORMAL MODE: Check if both players chose the same letter
            partner = self.group.get_partner(self)
            if not partner or not partner.letter_choice:
                return 0

            # Check if player and partner coordinated
            if self.letter_choice != partner.letter_choice:
                return 0

            coordinated_letter = self.letter_choice

        # Rounds 1-7: Only J=10 points, others=0
        if self.round_number <= 7:
            if coordinated_letter == 'J':
                return 10
            else:
                return 0
        # Rounds 8+: J=10 points, M=15 points, Q=15 points, others=0
        else:
            if coordinated_letter == 'J':
                return 10
            elif coordinated_letter == 'M':
                return 15
            elif coordinated_letter == 'Q':
                return 15
            else:
                return 0

    def get_available_point_values(self):
        """Get point values to display to participants"""
        if self.round_number <= 7:
            return {'J': 10, 'Q': 0, 'P': 0, 'R': 0, 'C': 0, 'D': 0, 'M': 0, 'X': 0, 'Y': 0, 'F': 0}
        else:
            return {'J': 10, 'M': 15, 'Q': 15, 'P': 0, 'R': 0, 'C': 0, 'D': 0, 'X': 0, 'Y': 0, 'F': 0}


# HELPER FUNCTIONS

def handle_player_timeout(player):
    """Mark both players in partnership as timed out and redirect to end"""
    # Mark current player as timed out
    player.participant.vars['timed_out'] = True
    player.participant.vars['experiment_ended'] = True

    # Find and mark partner as timed out too
    partner = player.group.get_partner(player)
    if partner:
        partner.participant.vars['timed_out'] = True
        partner.participant.vars['experiment_ended'] = True

    # Mark both players as inactive for future rounds
    player.participant.vars['is_active'] = False
    if partner:
        partner.participant.vars['is_active'] = False


def handle_matching_timeout(player):
    """Mark player as unable to be matched"""
    player.participant.vars['matching_timeout'] = True
    player.participant.vars['experiment_ended'] = True


def get_active_players(group):
    """Get only players who haven't timed out"""
    return [p for p in group.get_players() if not p.participant.vars.get('timed_out', False)]


def has_active_partnerships(group):
    """Check if group has any complete active partnerships"""
    active_players = get_active_players(group)
    return len(active_players) >= 2 and len(active_players) % 2 == 0


# PAGES

class WaitForPlayers(WaitPage):
    group_by_arrival_time = True
    timeout_seconds = 600  # 10 minutes

    @staticmethod
    def is_displayed(player):
        # Skip wait page in test mode
        test_mode = player.session.config.get('test_mode', False)
        if test_mode:
            return False

        return (player.round_number == 1 and
                not player.participant.vars.get('timed_out', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    @staticmethod
    def group_by_arrival_time_method(subsession, waiting_players):
        """Group players into pairs of 2"""
        if len(waiting_players) >= 2:
            return [waiting_players[:2]]

    @staticmethod
    def before_next_page(player, timeout_happened):
        if timeout_happened:
            handle_matching_timeout(player)

    @staticmethod
    def after_all_players_arrive(group):
        # Initialize all players as active
        for player in group.get_players():
            player.participant.vars['is_active'] = True
            player.participant.vars['timed_out'] = False


class Name_Game(Page):
    form_model = 'player'
    form_fields = ['letter_choice']
    timeout_seconds = 120  # 2 minutes

    def is_displayed(player):
        # Don't show if player timed out, matching timeout, no consent, or failed attention checks
        return (not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    def before_next_page(player, timeout_happened):
        if timeout_happened:
            handle_player_timeout(player)

        # In test mode, simulate bot partner choice
        test_mode = player.session.config.get('test_mode', False)
        if test_mode and player.letter_choice:
            # 70% chance bot chooses the same letter as player (to make it interesting)
            if random.random() < 0.7:
                bot_choice = player.letter_choice
            else:
                # Random choice from available letters
                bot_choice = random.choice(Constants.letter_choices)

            player.participant.vars[f'bot_choice_round_{player.round_number}'] = bot_choice

    def vars_for_template(player):
        partner = player.group.get_partner(player)

        # Get current point values for display
        point_values = player.get_available_point_values()

        # Calculate current total points
        if player.round_number == 1:
            current_total = 0
        else:
            current_total = sum([p.round_points for p in player.in_all_rounds()[:-1]])

        return {
            'partner_id': partner.id_in_group if partner else None,
            'round_num': player.round_number,
            'point_values': point_values,
            'current_total_points': current_total,
        }


class ResultsWaitPage(WaitPage):
    @staticmethod
    def is_displayed(player):
        # Skip in test mode
        test_mode = player.session.config.get('test_mode', False)
        if test_mode:
            return False

        return (not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    @staticmethod
    def after_all_players_arrive(group):
        # Only process if we have active partnerships
        if not has_active_partnerships(group):
            return


class Results(Page):
    timeout_seconds = 60

    def is_displayed(player):
        return (not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    def before_next_page(player, timeout_happened):
        # Skip partner checks in test mode
        test_mode = player.session.config.get('test_mode', False)
        if test_mode:
            return

        # Check if partner's letter_choice is None (indicating they timed out)
        partner = player.group.get_partner(player)
        if partner and not partner.field_maybe_none('letter_choice'):
            # Partner exists but has no letter choice - they probably timed out
            player.participant.vars['timed_out'] = True
            player.participant.vars['experiment_ended'] = True
            player.participant.vars['is_active'] = False
        elif not partner:
            # No partner found at all - also kick out this player
            player.participant.vars['timed_out'] = True
            player.participant.vars['experiment_ended'] = True
            player.participant.vars['is_active'] = False

    def vars_for_template(player):
        test_mode = player.session.config.get('test_mode', False)

        # Calculate points for this round
        player.round_points = player.calculate_points()

        # Update total points
        if player.round_number == 1:
            player.total_points = player.round_points
        else:
            previous_rounds_total = sum([p.round_points for p in player.in_all_rounds()[:-1]])
            player.total_points = previous_rounds_total + player.round_points

        # Get point values to show
        point_values = player.get_available_point_values()

        # Check if this is the round where M and N points are revealed (round 8)
        is_new_scoring_round = player.round_number == 8

        # Get partner/bot choice
        if test_mode:
            partner_choice = player.participant.vars.get(f'bot_choice_round_{player.round_number}')
            partner_id = 'Bot'
        else:
            partner = player.group.get_partner(player)
            partner_choice = partner.letter_choice if partner else None
            partner_id = partner.id_in_group if partner else None

        return {
            'my_choice': player.letter_choice,
            'partner_choice': partner_choice,
            'partner_id': partner_id,
            'my_points': player.round_points,
            'total_points': player.total_points,
            'point_values': point_values,
            'is_new_scoring_round': is_new_scoring_round,
            'round_number': player.round_number,
            'test_mode': test_mode,
        }


class TimeoutEnd(Page):
    """End page for players who timed out during gameplay"""

    def is_displayed(player):
        return (player.participant.vars.get('timed_out', False) and player.round_number == Constants.num_rounds)


class MatchingTimeoutEnd(Page):
    """End page for players who couldn't be matched"""

    def is_displayed(player):
        return (player.participant.vars.get('matching_timeout', False) and player.round_number == Constants.num_rounds)


class FinalResults(Page):
    """Final results page for players who completed all rounds"""

    def is_displayed(player):
        return (not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False) and
                player.round_number == Constants.num_rounds)

    def vars_for_template(player):
        return {
            'total_rounds': Constants.num_rounds,
            'completion_message': "Thank you for completing the experiment!",
        }


page_sequence = [
    WaitForPlayers,
    Name_Game,
    ResultsWaitPage,
    Results,
    TimeoutEnd,
    MatchingTimeoutEnd,
    FinalResults
]
