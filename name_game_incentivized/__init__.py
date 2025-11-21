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
    name_in_url = 'name_game_incentivized'
    players_per_group = None  # Flexible group size (controlled by group_by_arrival_time_method or test mode)
    num_rounds = 14

    # Group sizes
    group_size_dyadic = 2
    group_size_group = 6

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

        # Partition by condition
        dyadic_players = [p for p in waiting_players if p.participant.vars.get('condition') == 'dyadic']
        group_players  = [p for p in waiting_players if p.participant.vars.get('condition') == 'group']

        # If we can make a dyadic group, return exactly 2 players
        if len(dyadic_players) >= 2:
            return dyadic_players[:2]

        # If we can make a 6-person group, return exactly 6 players
        if len(group_players) >= 6:
            return group_players[:6]

        # Otherwise, wait for more arrivals
        return None


class Group(BaseGroup):
    def create_initial_partnerships(self):
        # Only work with active players (those who haven't timed out)
        active_players = [p for p in self.get_players() if not p.participant.vars.get('timed_out', False)]

        if len(active_players) < 2:
            return  # Can't form partnerships

        random.shuffle(active_players)

        # Pair them up: 0&1, 2&3, etc.
        for i in range(0, len(active_players), 2):
            if i + 1 < len(active_players):
                player1 = active_players[i]
                player2 = active_players[i + 1]

                # Store partnership in participant.vars
                player1.participant.vars['partner_id'] = player2.participant.id
                player2.participant.vars['partner_id'] = player1.participant.id
                player1.participant.vars['is_active'] = True
                player2.participant.vars['is_active'] = True

                # Also store in exportable fields
                player1.partner_id_in_group = player2.id_in_group
                player2.partner_id_in_group = player1.id_in_group

    def do_reshuffling(self):
        # Only reshuffle for GROUP condition players
        active_players = get_active_players(self)

        if len(active_players) < 2:
            return  # Can't form new partnerships

        # Separate players by condition
        dyadic_players = [p for p in active_players if p.participant.vars.get('condition') == 'dyadic']
        group_players = [p for p in active_players if p.participant.vars.get('condition') == 'group']

        # DYADIC: Keep partnerships fixed (do nothing)
        # GROUP: Reshuffle partnerships
        if len(group_players) >= 2:
            random.shuffle(group_players)

            # Create new partnerships among group condition players
            for i in range(0, len(group_players), 2):
                if i + 1 < len(group_players):
                    player1 = group_players[i]
                    player2 = group_players[i + 1]

                    # Update partnership in participant.vars
                    player1.participant.vars['partner_id'] = player2.participant.id
                    player2.participant.vars['partner_id'] = player1.participant.id

                    # Update exportable fields for next round
                    if self.subsession.round_number < Constants.num_rounds:
                        next_round = self.subsession.round_number + 1
                        player1_next = player1.in_round(next_round)
                        player2_next = player2.in_round(next_round)
                        player1_next.partner_id_in_group = player2.id_in_group
                        player2_next.partner_id_in_group = player1.id_in_group

    def get_partner(self, player):
        # Only return partner if both are still active (haven't timed out)
        if player.participant.vars.get('timed_out', False):
            return None

        partner_id = player.participant.vars.get('partner_id')
        if partner_id:
            for other_player in self.get_players():
                if (other_player.participant.id == partner_id and
                        not other_player.participant.vars.get('timed_out', False)):
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

        condition = self.participant.vars.get('condition', 'dyadic')
        test_mode = self.session.config.get('test_mode', False)

        if test_mode:
            # TEST MODE: Use simulated bot choices
            if condition == 'dyadic':
                bot_choice = self.participant.vars.get(f'bot_choice_round_{self.round_number}')
                if not bot_choice or self.letter_choice != bot_choice:
                    return 0
                coordinated_letter = self.letter_choice
            else:
                # GROUP: Check if all 6 (player + 5 bots) chose the same
                bot_choices = self.participant.vars.get(f'bot_choices_round_{self.round_number}', [])
                if len(bot_choices) != 5:
                    return 0
                # All bots must match each other and the player
                if not all(choice == self.letter_choice for choice in bot_choices):
                    return 0
                coordinated_letter = self.letter_choice
        else:
            # NORMAL MODE: Use real partners
            if condition == 'dyadic':
                # DYADIC: Only need to match with partner
                partner = self.group.get_partner(self)
                if not partner or not partner.letter_choice:
                    return 0

                # Check if player and partner coordinated
                if self.letter_choice != partner.letter_choice:
                    return 0

                coordinated_letter = self.letter_choice
            else:
                # GROUP: All 6 players must choose the same letter
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

    # Only also kick the partner in the DYADIC condition
    if player.participant.vars.get('condition') == 'dyadic':
        partner = player.group.get_partner(player)
        if partner:
            partner.participant.vars['timed_out'] = True
            partner.participant.vars['experiment_ended'] = True
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
    def before_next_page(player, timeout_happened):
        if timeout_happened:
            handle_matching_timeout(player)

    @staticmethod
    def after_all_players_arrive(group):
        # Initialize all players as active and store condition in database
        for player in group.get_players():
            # Initialize as active
            player.participant.vars['is_active'] = True
            player.participant.vars['timed_out'] = False

            # Store condition in database field for export
            player.condition = player.participant.vars.get('condition', 'unknown')

        # Create partnerships within this group
        group.create_initial_partnerships()


class Name_Game(Page):
    form_model = 'player'
    form_fields = ['letter_choice']
    timeout_seconds = 120  # 2 minutes

    def is_displayed(player):
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

            if condition == 'dyadic':
                player.participant.vars[f'bot_choice_round_{player.round_number}'] = bot_choice
            else:
                # 5 bot “teammates” for the 6-person group
                player.participant.vars[f'bot_choices_round_{player.round_number}'] = [bot_choice] * 5

    def vars_for_template(player):
        partner = player.group.get_partner(player)
        point_values = player.get_available_point_values()
        available_letters = player.get_available_letters()
        current_total = 0 if player.round_number == 1 else sum(
            p.round_points for p in player.in_all_rounds()[:-1]
        )
        condition = player.participant.vars.get('condition', 'unknown')
        all_group_members = []
        if condition == 'group':
            all_group_members = [
                p.id_in_group for p in player.group.get_players()
                if not p.participant.vars.get('timed_out', False)
            ]
        return {
            'partner_id': partner.id_in_group if partner else None,
            'round_num': player.round_number,
            'point_values': point_values,
            'available_letters': available_letters,
            'current_total_points': current_total,
            'condition': condition,
            'all_group_members': all_group_members,
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
        if player.session.config.get('test_mode', False):
            return

        # Only apply the partner “kick” logic in the dyadic condition
        if player.participant.vars.get('condition') == 'dyadic':
            partner = player.group.get_partner(player)
            if not partner or not partner.letter_choice:
                player.participant.vars['timed_out'] = True
                player.participant.vars['experiment_ended'] = True
                player.participant.vars['is_active'] = False


    def vars_for_template(player):
        condition = player.participant.vars.get('condition', 'dyadic')
        test_mode = player.session.config.get('test_mode', False)

        player.round_points = player.calculate_points()
        if player.round_number == 1:
            player.total_points = player.round_points
        else:
            player.total_points = sum(p.round_points for p in player.in_all_rounds()[:-1]) + player.round_points
        player.participant.vars['total_points'] = player.total_points

        point_values = player.get_available_point_values()
        is_new_scoring_round = player.round_number == 8

        partner = None  # <-- add this line
        if test_mode:
            if condition == 'dyadic':
                partner_choice = player.participant.vars.get(f'bot_choice_round_{player.round_number}')
                all_choices = []
            else:
                bot_choices = player.participant.vars.get(f'bot_choices_round_{player.round_number}', [])
                all_choices = [player.letter_choice] + bot_choices
                partner_choice = None
        else:
            all_choices = []
            if condition == 'group':
                all_players = [p for p in player.group.get_players()
                               if not p.participant.vars.get('timed_out', False)]
                all_choices = [p.letter_choice for p in all_players if p.letter_choice]
                partner_choice = None
            else:
                partner = player.group.get_partner(player)
                partner_choice = partner.letter_choice if partner else None

        return {
            'my_choice': player.letter_choice,
            'partner_choice': partner_choice,
            'partner_id': 'Bot' if test_mode else (partner.id_in_group if partner else None),
            'my_points': player.round_points,
            'total_points': player.total_points,
            'point_values': point_values,
            'is_new_scoring_round': is_new_scoring_round,
            'round_number': player.round_number,
            'condition': condition,
            'all_choices': all_choices,
            'test_mode': test_mode,
        }



class ReshuffleWaitPage(WaitPage):
    @staticmethod
    def is_displayed(player):
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
        # Only reshuffle if we have active partnerships
        if has_active_partnerships(group):
            group.do_reshuffling()


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
        condition = player.participant.vars.get('condition', 'unknown')
        condition_text = "Dyadic (Fixed Partner)" if condition == 'dyadic' else "Group (Rotating Partners)"

        return {
            'total_rounds': Constants.num_rounds,
            'completion_message': "Thank you for completing the experiment!",
            'condition': condition_text,
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
