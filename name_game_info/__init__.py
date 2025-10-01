# __init__.py

from otree.api import *
import random

doc = """
Simple matching game where players are grouped into teams of 2 within groups of 4,
play a letter choice game, see results, then get reshuffled for 10 rounds.
Handles dropouts by removing both players in a partnership when one times out.
All players receive the information treatment.
"""


class Constants(BaseConstants):
    name_in_url = 'name_game_info'
    players_per_group = 4  # Changed to 4 for easier testing
    num_rounds = 10

    letter_choices = [ 'J', 'P', 'R', 'C', 'D']


class Subsession(BaseSubsession):
    pass


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
        # Only reshuffle active players (those who haven't timed out)
        active_players = get_active_players(self)

        if len(active_players) < 2:
            return  # Can't form new partnerships

        random.shuffle(active_players)

        # Create new partnerships among active players only
        for i in range(0, len(active_players), 2):
            if i + 1 < len(active_players):
                player1 = active_players[i]
                player2 = active_players[i + 1]

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
    treatment = models.StringField()  # Will always be 'info'


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

    def is_displayed(self):
        return (self.round_number == 1 and
                not self.participant.vars.get('timed_out', False) and
                self.participant.vars.get('consent', False) == True and
                not self.participant.vars.get('attention_check_failed', False))

    def before_next_page(player, timeout_happened):
        if timeout_happened:
            handle_matching_timeout(player)

    def after_all_players_arrive(self):
        # Assign information treatment to all players in all groups
        groups = self.subsession.get_groups()

        for group in groups:
            # All players get the 'info' treatment
            for player in group.get_players():
                player.treatment = 'info'
                player.participant.vars['treatment'] = 'info'
                # Initialize as active
                player.participant.vars['is_active'] = True
                player.participant.vars['timed_out'] = False

            # Create partnerships within this group
            group.create_initial_partnerships()


class Name_Game_Info(Page):
    form_model = 'player'
    form_fields = ['letter_choice']
    timeout_seconds = 120  # 2 minutes

    def is_displayed(player):
        # Show for all players (since all get info treatment)
        return (not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

    def before_next_page(player, timeout_happened):
        if timeout_happened:
            handle_player_timeout(player)

    def vars_for_template(player):
        partner = player.group.get_partner(player)

        # Get partner's choice from previous round (only available from round 2 onwards)
        partner_previous_choice = None
        if partner and player.round_number > 1:
            partner_previous = partner.in_round(player.round_number - 1)
            partner_previous_choice = partner_previous.letter_choice

        # Get player's own choice from previous round (only available from round 2 onwards)
        player_previous_choice = None
        if player.round_number > 1:
            player_previous = player.in_round(player.round_number - 1)
            player_previous_choice = player_previous.letter_choice

        return {
            'partner_id': partner.id_in_group if partner else None,
            'partner_previous_choice': partner_previous_choice,
            'player_previous_choice': player_previous_choice,
            'round_num': player.round_number,
            'previous_round': player.round_number - 1 if player.round_number > 1 else None
        }


class ResultsWaitPage(WaitPage):
    def is_displayed(player):
        return (not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

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
        partner = player.group.get_partner(player)

        return {
            'my_choice': player.letter_choice,
            'partner_choice': partner.letter_choice if partner else None,
            'partner_id': partner.id_in_group if partner else None,
        }


class ReshuffleWaitPage(WaitPage):
    def is_displayed(player):
        # Don't show after the last round or if timed out
        return (player.round_number < Constants.num_rounds and
                not player.participant.vars.get('timed_out', False) and
                not player.participant.vars.get('matching_timeout', False) and
                player.participant.vars.get('consent', False) == True and
                not player.participant.vars.get('attention_check_failed', False))

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
        return {
            'total_rounds': Constants.num_rounds,
            'completion_message': "Thank you for completing the experiment!"
        }


page_sequence = [
    WaitForPlayers,
    Name_Game_Info,
    ResultsWaitPage,
    Results,
    ReshuffleWaitPage,
    TimeoutEnd,
    MatchingTimeoutEnd,
    FinalResults
]