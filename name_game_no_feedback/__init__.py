# __init__.py

from otree.api import *
import random

doc = """
INCENTIVIZED NAME GAME: Participants are randomly assigned to either:
- DYADIC CONDITION: Two players work together as a fixed pair throughout all 14 rounds.
- GROUP CONDITION: Four players in a group - ALL must coordinate (no pairing).

KEY FEATURES:
- Trials 1-7: Only J available (10 points)
- Trials 8+: J (10 points), M (15 points), N (15 points)
- Matching happens AFTER comprehension checks
- Group condition: all 6 members must choose same letter for payoff
"""


class Constants(BaseConstants):
    name_in_url = 'name_game_no_feedback'
    players_per_group = 2  # All groups have 6 players
    num_rounds = 14

    # All possible letters (for display purposes)
    letter_choices = ['Q', 'M', 'N', 'X', 'Y', 'F', 'J', 'P', 'R', 'C', 'D']

    # Letters available in rounds 1-7
    letters_early = ['J']

    # Letters available in rounds 8+
    letters_late = ['J', 'M', 'N']


class Subsession(BaseSubsession):
    def creating_session(self):
        # In test mode, allow single players (bypass group size requirement)
        if self.session.config.get('test_mode', False):
            for player in self.get_players():
                if 'condition' not in player.participant.vars:
                    forced_condition = self.session.config.get('force_condition', 'dyadic')
                    player.participant.vars['condition'] = forced_condition

                if self.round_number == 1:
                    player.participant.vars['is_active'] = True
                    player.participant.vars['timed_out'] = False
                    player.participant.vars['consent'] = True
                    player.participant.vars['attention_check_failed'] = False
                    player.condition = player.participant.vars.get('condition', 'dyadic')

    def group_by_arrival_time_method(self, waiting_players):
        """Return exactly one complete group (flat list of Players) or None."""
        import time

        # Store arrival time for new players
        current_time = time.time()
        for p in waiting_players:
            if 'wait_page_arrival' not in p.participant.vars:
                p.participant.vars['wait_page_arrival'] = current_time

        # Match 6 players together
        if len(waiting_players) >= 6:
            return waiting_players[:6]

        # Check if all waiting players have timed out (waited > 10 minutes)
        if waiting_players:
            timeout_threshold = 600  # 10 minutes in seconds

            # Check if all players have been waiting longer than timeout
            all_timed_out = all(
                (current_time - p.participant.vars.get('wait_page_arrival', current_time)) > timeout_threshold
                for p in waiting_players
            )

            # If all waiting players have timed out, return them so they can proceed
            if all_timed_out:
                return waiting_players

        # Otherwise, wait for more arrivals
        return None


class Group(BaseGroup):
    pass


class Player(BasePlayer):
    letter_choice = models.StringField(
        choices=Constants.letter_choices,
        label="Your letter choice:"
    )
    round_points = models.IntegerField(default=0)
    total_points = models.IntegerField(default=0)
    condition = models.StringField()  # Store condition for export

    def calculate_points(self):
        """Calculate points based on letter choice and round number"""
        if not self.letter_choice:
            return 0

        # All 6 players must choose the same letter to earn points
        all_players = [p for p in self.group.get_players()
                      if not p.participant.vars.get('timed_out', False)]

        # Need all 6 players to have made a choice
        if len(all_players) != 6:
            return 0

        # Get all letter choices
        all_choices = [p.letter_choice for p in all_players if p.letter_choice]

        # All players must have chosen
        if len(all_choices) != 6:
            return 0

        # All choices must be the same
        if len(set(all_choices)) != 1:
            return 0

        coordinated_letter = self.letter_choice

        # Rounds 1-7: Only J=10 points, others=0
        if self.round_number <= 7:
            if coordinated_letter == 'J':
                return 10
            else:
                return 0
        # Rounds 8+: J=10 points, M=15 points, N=15 points, others=0
        else:
            if coordinated_letter == 'J':
                return 10
            elif coordinated_letter == 'M':
                return 15
            elif coordinated_letter == 'N':
                return 15
            else:
                return 0

    def get_available_point_values(self):
        """Get point values to display to participants"""
        if self.round_number <= 7:
            return {'J': 10, 'P': 0, 'R': 0, 'C': 0, 'D': 0, 'Q': 0, 'M': 0, 'N': 0, 'X': 0, 'Y': 0, 'F': 0}
        else:
            return {'J': 10, 'M': 15, 'N': 15, 'P': 0, 'R': 0, 'C': 0, 'D': 0, 'Q': 0, 'X': 0, 'Y': 0, 'F': 0}

    def get_available_letters(self):
        """Get letters available for this round"""
        if self.round_number <= 7:
            return Constants.letters_early
        else:
            return Constants.letters_late


# HELPER FUNCTIONS

def handle_player_timeout(player):
    """Mark a player (and possibly their partner) as timed out and end participation."""
    # Always mark the current player
    player.participant.vars['timed_out'] = True
    player.participant.vars['experiment_ended'] = True
    player.participant.vars['is_active'] = False

    # Mark all group members as timed out
    for other_player in player.group.get_players():
        if other_player.id_in_group != player.id_in_group:
            other_player.participant.vars['timed_out'] = True
            other_player.participant.vars['experiment_ended'] = True
            other_player.participant.vars['is_active'] = False


def handle_matching_timeout(player):
    """Mark player as unable to be matched"""
    player.participant.vars['matching_timeout'] = True
    player.participant.vars['experiment_ended'] = True


def get_active_players(group):
    """Get only players who haven't timed out"""
    return [p for p in group.get_players() if not p.participant.vars.get('timed_out', False)]


# PAGES

class WaitForPlayers(WaitPage):
    group_by_arrival_time = True
    timeout_seconds = 600  # 10 minutes

    @staticmethod
    def is_displayed(player):
        # Only show for no_feedback treatment
        if player.participant.vars.get('treatment') != 'no_feedback':
            return False

        # Skip wait page in test mode
        test_mode = player.session.config.get('test_mode', False)
        if test_mode:
            return False

        return (player.round_number == 1 and
                not player.participant.vars.get('timed_out', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    @staticmethod
    def before_next_page(player, timeout_happened):
        if timeout_happened:
            handle_matching_timeout(player)

    @staticmethod
    def after_all_players_arrive(group):
        # Check if this is a complete group (6 players) or a timeout group (< 6 players)
        group_size = len(group.get_players())

        if group_size < 6:
            # This is a timeout group - mark all players as unable to match
            for player in group.get_players():
                player.participant.vars['matching_timeout'] = True
                player.participant.vars['experiment_ended'] = True
        else:
            # Complete group - initialize normally
            for player in group.get_players():
                # Initialize as active
                player.participant.vars['is_active'] = True
                player.participant.vars['timed_out'] = False

                # Store condition in database field for export
                player.condition = player.participant.vars.get('condition', 'unknown')


class Name_Game(Page):
    form_model = 'player'
    form_fields = ['letter_choice']
    timeout_seconds = 120  # 2 minutes

    def is_displayed(player):
        # Only show for no_feedback treatment
        if player.participant.vars.get('treatment') != 'no_feedback':
            return False

        return (not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    def before_next_page(player, timeout_happened):
        if timeout_happened:
            handle_player_timeout(player)
            return

        # TEST MODE: simulate partner/group choices to allow progression
        test_mode = player.session.config.get('test_mode', False)
        if test_mode and player.letter_choice:
            condition = player.participant.vars.get('condition', 'dyadic')

            # Available letters this round
            available_letters = (Constants.letters_early
                                 if player.round_number <= 7
                                 else Constants.letters_late)

            # 70% chance bots match the player's choice
            if random.random() < 0.7:
                bot_choice = player.letter_choice
            else:
                bot_choice = random.choice(available_letters)

            # 5 bot "teammates" for the 6-person group
            player.participant.vars[f'bot_choices_round_{player.round_number}'] = [bot_choice] * 5

    def vars_for_template(player):
        point_values = player.get_available_point_values()
        available_letters = player.get_available_letters()
        current_total = 0 if player.round_number == 1 else sum(
            p.round_points for p in player.in_all_rounds()[:-1]
        )
        all_group_members = [
            p.id_in_group for p in player.group.get_players()
            if not p.participant.vars.get('timed_out', False)
        ]
        return {
            'round_num': player.round_number,
            'point_values': point_values,
            'available_letters': available_letters,
            'current_total_points': current_total,
            'all_group_members': all_group_members,
        }



class ResultsWaitPage(WaitPage):
    @staticmethod
    def is_displayed(player):
        # Only show for no_feedback treatment
        if player.participant.vars.get('treatment') != 'no_feedback':
            return False

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
        # Calculate points for all players after each round
        active_players = get_active_players(group)
        if len(active_players) < 6:
            return

        # Calculate points for each player
        for p in active_players:
            p.round_points = p.calculate_points()
            if p.round_number == 1:
                p.total_points = p.round_points
            else:
                p.total_points = sum(prev_p.round_points for prev_p in p.in_all_rounds()[:-1]) + p.round_points
            p.participant.vars['total_points'] = p.total_points


class Results(Page):
    timeout_seconds = 60

    def is_displayed(player):
        # Only show for no_feedback treatment
        if player.participant.vars.get('treatment') != 'no_feedback':
            return False

        # Only show in rounds 1-7 and round 14
        if player.round_number >= 8 and player.round_number < 14:
            return False

        return (not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    def before_next_page(player, timeout_happened):
        # Skip partner checks in test mode
        if player.session.config.get('test_mode', False):
            return

        # Check if any group member timed out
        all_players = [p for p in player.group.get_players()
                       if not p.participant.vars.get('timed_out', False)]
        if len(all_players) < 6:
            player.participant.vars['timed_out'] = True
            player.participant.vars['experiment_ended'] = True
            player.participant.vars['is_active'] = False


    def vars_for_template(player):
        test_mode = player.session.config.get('test_mode', False)

        player.round_points = player.calculate_points()
        if player.round_number == 1:
            player.total_points = player.round_points
        else:
            player.total_points = sum(p.round_points for p in player.in_all_rounds()[:-1]) + player.round_points
        player.participant.vars['total_points'] = player.total_points

        point_values = player.get_available_point_values()
        is_new_scoring_round = player.round_number == 8

        if test_mode:
            bot_choices = player.participant.vars.get(f'bot_choices_round_{player.round_number}', [])
            all_choices = [player.letter_choice] + bot_choices
        else:
            all_players = [p for p in player.group.get_players()
                           if not p.participant.vars.get('timed_out', False)]
            all_choices = [p.letter_choice for p in all_players if p.letter_choice]

        return {
            'my_choice': player.letter_choice,
            'my_points': player.round_points,
            'total_points': player.total_points,
            'point_values': point_values,
            'is_new_scoring_round': is_new_scoring_round,
            'round_number': player.round_number,
            'all_choices': all_choices,
            'test_mode': test_mode,
        }



class ReshuffleWaitPage(WaitPage):
    @staticmethod
    def is_displayed(player):
        # Only show for no_feedback treatment
        if player.participant.vars.get('treatment') != 'no_feedback':
            return False

        # Skip in test mode
        test_mode = player.session.config.get('test_mode', False)
        if test_mode:
            return False

        # Don't show after the last round or if timed out
        return (player.round_number < Constants.num_rounds and
                not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    @staticmethod
    def after_all_players_arrive(group):
        # No reshuffling needed - groups stay fixed
        pass


class TimeoutEnd(Page):
    """End page for players who timed out during gameplay"""

    def is_displayed(player):
        # Only show for no_feedback treatment
        if player.participant.vars.get('treatment') != 'no_feedback':
            return False

        return (player.participant.vars.get('timed_out', False) and player.round_number == Constants.num_rounds)


class MatchingTimeoutEnd(Page):
    """End page for players who couldn't be matched"""

    def is_displayed(player):
        # Only show for no_feedback treatment
        if player.participant.vars.get('treatment') != 'no_feedback':
            return False

        return (player.participant.vars.get('matching_timeout', False) and player.round_number == Constants.num_rounds)


class FinalResults(Page):
    """Final results page for players who completed all rounds"""

    def is_displayed(player):
        # Only show for no_feedback treatment
        if player.participant.vars.get('treatment') != 'no_feedback':
            return False

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
    ReshuffleWaitPage,
    TimeoutEnd,
    MatchingTimeoutEnd,
    FinalResults
]
