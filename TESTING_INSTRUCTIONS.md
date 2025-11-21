# Testing Instructions for name_game_incentivized

## Solo Test Sessions (No Other Participants Needed)

You can test both conditions solo using simulated bot partners.

### 1. Test Dyadic Condition (2-player, fixed partner)

**Session Name:** `test_incentivized_dyadic`

**What to expect:**
- You'll be paired with a simulated bot partner
- Same partner throughout all 14 rounds
- Rounds 1-7: Only letter J available (10 points)
- Rounds 8-14: Letters J (10 pts), M (15 pts), N (15 pts) available
- Bot has 70% chance to coordinate with you
- You need to match your partner's choice to earn points

**To run:**
1. Start oTree server: `otree devserver`
2. Go to: http://localhost:8000
3. Click "test_incentivized_dyadic"
4. Click "Demo"

---

### 2. Test Group Condition (4-player, all must coordinate)

**Session Name:** `test_incentivized_group`

**What to expect:**
- You'll be in a group of 4 (you + 3 simulated bots)
- Partners reshuffle each round (but you won't notice in test mode)
- Rounds 1-7: Only letter J available (10 points)
- Rounds 8-14: Letters J (10 pts), M (15 pts), N (15 pts) available
- Bots have 70% chance to all coordinate with you
- **ALL 4 players must choose the same letter for anyone to earn points**
- Results page shows all 4 players' choices

**To run:**
1. Start oTree server: `otree devserver`
2. Go to: http://localhost:8000
3. Click "test_incentivized_group"
4. Click "Demo"

---

## Key Differences Between Conditions

### Dyadic:
- 2 players total
- Fixed partner all rounds
- Instructions: "coordinate with your partner"
- Only need to match 1 other person

### Group:
- 4 players total
- Partners change each round (not visible in test mode)
- Instructions: "ALL 4 players must choose the same letter"
- Results show all 4 choices
- Need ALL 4 to match for points

---

## New Follow-up Questions (in End_name app)

After completing all rounds, you'll see these new questions:

1. **Following a rule?** (Yes/No)
2. **How important is it that you follow this rule?** (1-7 scale)
3. **To what extent did you follow the same rule from the start?** (1-7 scale)
4. **How many different rules did you follow?** (slider: 0-2)
5. **If you had to tell a new participant what rule to follow, what would you tell them?** (text)

---

## Letter Availability by Round

| Rounds | Available Letters | Point Values |
|--------|------------------|--------------|
| 1-7    | J only           | J = 10 pts   |
| 8-14   | J, M, N          | J = 10 pts, M = 15 pts, N = 15 pts |

All other letters (P, R, C, D, Q, X, Y, F) are worth 0 points.

---

## Troubleshooting

**If the experiment doesn't start:**
- Make sure you clicked "Demo" not "Session-wide link"
- Check that consent is set to "Yes"
- Pass the attention checks (correct answers based on condition shown)

**To reset and try again:**
- In the oTree admin, go to "Sessions"
- Delete the old test session
- Create a new demo session
