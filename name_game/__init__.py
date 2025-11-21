# __init__.py

from otree.api import *
import random

doc = """
UNIFIED NAME GAME: Participants are randomly assigned to either:
- DYADIC CONDITION: Two players work together as a fixed pair throughout all 14 rounds.
- GROUP CONDITION: Four players in a group with partners reshuffled each round.
Random assignment is 50/50 and happens automatically within the same session.
"""


class Constants(BaseConstants):
    name_in_url = 'name_game'
    players_per_group = None  # Flexible group size (controlled by group_by_arrival_time_method or test mode)
    num_rounds = 14

    letter_choices = ['Q', 'M', 'X', 'Y', 'F', 'J', 'P', 'R', 'C', 'D']


class Subsession(BaseSubsession):
    def creating_session(self):
        # In test mode, allow single players (bypass group size requirement)
        if self.session.config.get('test_mode', False):
            # Set players_per_group to None to allow any number of participants
            for group in self.get_groups():
                pass  # Groups already created, no need to modify


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
                # GROUP: Check if all 4 (player + 3 bots) chose the same
                bot_choices = self.participant.vars.get(f'bot_choices_round_{self.round_number}', [])
                if len(bot_choices) != 3:
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
                # GROUP: All 4 players must choose the same letter
                all_players = [p for p in self.group.get_players()
                              if not p.participant.vars.get('timed_out', False)]

                # Need all 4 players to have made a choice
                if len(all_players) != 4:
                    return 0

                # Get all letter choices
                all_choices = [p.letter_choice for p in all_players if p.letter_choice]

                # All players must have chosen
                if len(all_choices) != 4:
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
        # Rounds 8+: J=10 points, M=15 points, others=0
        else:
            if coordinated_letter == 'J':
                return 10
            elif coordinated_letter == 'M':
                return 15
            else:
                return 0

    def get_available_point_values(self):
        """Get point values to display to participants"""
        if self.round_number <= 7:
            return {'J': 10, 'P': 0, 'R': 0, 'C': 0, 'D': 0, 'Q': 0, 'M': 0, 'X': 0, 'Y': 0, 'F': 0}
        else:
            return {'J': 10, 'M': 15, 'P': 0, 'R': 0, 'C': 0, 'D': 0, 'Q': 0, 'X': 0, 'Y': 0, 'F': 0}


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
        """Custom grouping: dyadic players in groups of 2, group players in groups of 4"""

        # Separate by condition
        dyadic_players = [p for p in waiting_players if p.participant.vars.get('condition') == 'dyadic']
        group_players = [p for p in waiting_players if p.participant.vars.get('condition') == 'group']

        groups = []

        # Create dyadic groups (2 players each)
        while len(dyadic_players) >= 2:
            groups.append(dyadic_players[:2])
            dyadic_players = dyadic_players[2:]

        # Create group condition groups (4 players each)
        while len(group_players) >= 4:
            groups.append(group_players[:4])
            group_players = group_players[4:]

        if groups:
            return groups

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
        # Don't show if player timed out, matching timeout, no consent, or failed attention checks
        return (not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    def before_next_page(player, timeout_happened):
        if timeout_happened:
            handle_player_timeout(player)

        # In test mode, simulate bot partner choices
        test_mode = player.session.config.get('test_mode', False)
        if test_mode and player.letter_choice:
            # Store bot choices for this round
            condition = player.participant.vars.get('condition', 'dyadic')

            # 70% chance bots choose the same letter as player (to make it interesting)
            if random.random() < 0.7:
                bot_choice = player.letter_choice
            else:
                # Random choice from available letters
                bot_choice = random.choice(Constants.letter_choices)

            # Store bot choices in participant vars
            if condition == 'dyadic':
                player.participant.vars[f'bot_choice_round_{player.round_number}'] = bot_choice
            else:
                # For group, simulate 3 other players
                player.participant.vars[f'bot_choices_round_{player.round_number}'] = [
                    bot_choice, bot_choice, bot_choice  # All bots make same choice
                ]

    def vars_for_template(player):
        partner = player.group.get_partner(player)

        # Get current point values for display
        point_values = player.get_available_point_values()

        # Calculate current total points
        if player.round_number == 1:
            current_total = 0
        else:
            current_total = sum([p.round_points for p in player.in_all_rounds()[:-1]])

        # Get condition for display
        condition = player.participant.vars.get('condition', 'unknown')

        return {
            'partner_id': partner.id_in_group if partner else None,
            'round_num': player.round_number,
            'point_values': point_values,
            'current_total_points': current_total,
            'condition': condition,
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
        # Check if partner's letter_choice is None (indicating they timed out)
        partner = player.group.get_partner(player)
        if partner and not partner.letter_choice:
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
        condition = player.participant.vars.get('condition', 'dyadic')
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

        # Check if this is the round where M points are revealed (round 8)
        is_new_scoring_round = player.round_number == 8

        # Get partner/bot choices
        if test_mode:
            if condition == 'dyadic':
                partner_choice = player.participant.vars.get(f'bot_choice_round_{player.round_number}')
                all_choices = []
            else:
                # Group condition: show all 4 choices (player + 3 bots)
                bot_choices = player.participant.vars.get(f'bot_choices_round_{player.round_number}', [])
                all_choices = [player.letter_choice] + bot_choices
                partner_choice = bot_choices[0] if bot_choices else None
        else:
            partner = player.group.get_partner(player)
            partner_choice = partner.letter_choice if partner else None

            # For group condition, get all players' choices
            all_choices = []
            if condition == 'group':
                all_players = [p for p in player.group.get_players()
                              if not p.participant.vars.get('timed_out', False)]
                all_choices = [p.letter_choice for p in all_players if p.letter_choice]

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
