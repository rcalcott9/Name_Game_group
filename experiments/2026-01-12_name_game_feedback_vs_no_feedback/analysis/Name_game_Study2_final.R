# Name Game - Data Analysis Script
# This script converts the wide-format oTree data to long format
# and extracts key variables for analysis

library(tidyverse)
library(lme4)  # For mixed-effects models
library(lmerTest)  # For p-values in mixed models
library(effects)  # For effect plots

# Read the data
data <- read_csv("data/all_apps_wide-2026-01-12-6.csv")

# Extract participant-level variables (constant across rounds)
# Note: treatment is already in round data, so don't include it here to avoid duplication
participant_info <- data %>%
  dplyr::select(
    participant_id = `participant.code`,
    prolific_id = `participant.label`,
    consent = `consent.1.player.consent`,
    # treatment = `consent.1.player.treatment`,  # Already in long_data
    comprehension_check_attempts = `Intro.1.player.comprehension_check_attempts`,
    comprehension_check_failed = `Intro.1.player.comprehension_check_failed`,
    # Post-survey questions
    following_rule = `End_name.1.player.following_rule`,
    what_rule = `End_name.1.player.what_rule`,
    rule_importance = `End_name.1.player.rule_importance`,
    same_rule_from_start = `End_name.1.player.same_rule_from_start`,
    num_rules_followed = `End_name.1.player.num_rules_followed`,
    rule_advice = `End_name.1.player.rule_advice`,
    # New moral/punishment questions
    moral_always_j = `End_name.1.player.moral_always_j`,
    moral_j_then_m = `End_name.1.player.moral_j_then_m`,
    moral_j_then_n = `End_name.1.player.moral_j_then_n`,
    punish_always_j = `End_name.1.player.punish_always_j`,
    punish_j_then_m = `End_name.1.player.punish_j_then_m`,
    punish_j_then_n = `End_name.1.player.punish_j_then_n`,
    teammate_moral_always_j = `End_name.1.player.teammate_moral_always_j`,
    teammate_moral_j_then_m = `End_name.1.player.teammate_moral_j_then_m`,
    teammate_moral_j_then_n = `End_name.1.player.teammate_moral_j_then_n`,
    feedback = `End_name.1.player.feedback`,
    gender = `End_name.1.player.gender`,
    age = `End_name.1.player.age`
  )

# Extract round-by-round data (long format)
# Create a list to store data from each round
# NOTE: There are TWO apps - name_game (feedback) and name_game_no_feedback
round_data_list <- list()

for (round in 1:14) {
  # Build column names for FEEDBACK condition (name_game app)
  col_letter_fb <- paste0("name_game.", round, ".player.letter_choice")
  col_round_points_fb <- paste0("name_game.", round, ".player.round_points")
  col_total_points_fb <- paste0("name_game.", round, ".player.total_points")
  col_group_fb <- paste0("name_game.", round, ".group.id_in_subsession")
  col_id_in_group_fb <- paste0("name_game.", round, ".player.id_in_group")

  # Build column names for NO_FEEDBACK condition (name_game_no_feedback app)
  col_letter_nfb <- paste0("name_game_no_feedback.", round, ".player.letter_choice")
  col_round_points_nfb <- paste0("name_game_no_feedback.", round, ".player.round_points")
  col_total_points_nfb <- paste0("name_game_no_feedback.", round, ".player.total_points")
  col_group_nfb <- paste0("name_game_no_feedback.", round, ".group.id_in_subsession")
  col_id_in_group_nfb <- paste0("name_game_no_feedback.", round, ".player.id_in_group")

  # Extract feedback data
  round_data_fb <- data %>%
    select(
      participant_id = `participant.code`,
      treatment = `consent.1.player.treatment`,
      letter_choice = !!sym(col_letter_fb),
      id_in_group = !!sym(col_id_in_group_fb),
      round_points = !!sym(col_round_points_fb),
      total_points = !!sym(col_total_points_fb),
      group_id = !!sym(col_group_fb)
    ) %>%
    filter(!is.na(letter_choice) & letter_choice != "") %>%
    mutate(round = round)

  # Extract no_feedback data
  round_data_nfb <- data %>%
    select(
      participant_id = `participant.code`,
      treatment = `consent.1.player.treatment`,
      letter_choice = !!sym(col_letter_nfb),
      id_in_group = !!sym(col_id_in_group_nfb),
      round_points = !!sym(col_round_points_nfb),
      total_points = !!sym(col_total_points_nfb),
      group_id = !!sym(col_group_nfb)
    ) %>%
    filter(!is.na(letter_choice) & letter_choice != "") %>%
    mutate(round = round)

  # Combine both conditions for this round
  round_data_list[[round]] <- bind_rows(round_data_fb, round_data_nfb)
}

# Combine all rounds
long_data <- bind_rows(round_data_list)

# Create coordination indicator and convert treatment to factor
# For each participant-round, check if they coordinated (got points > 0)
long_data <- long_data %>%
  mutate(
    coordinated = round_points > 0,
    # Identify phase (rounds 1-7 vs 8-14)
    phase = ifelse(round <= 7, "early", "late"),
    # Convert treatment to factor with explicit levels
    treatment = factor(treatment, levels = c("no_feedback", "feedback"))
  )

# Merge participant info with round data
final_data <- long_data %>%
  left_join(participant_info, by = "participant_id") %>%
  # Reorder columns for clarity
  select(
    participant_id,
    prolific_id,
    treatment,  # Already correctly set from long_data
    round,
    phase,
    letter_choice,
    coordinated,
    round_points,
    total_points,
    id_in_group,
    group_id,
    # Post-survey questions
    following_rule,
    what_rule,
    rule_importance,
    same_rule_from_start,
    num_rules_followed,
    rule_advice,
    # Moral/punishment questions
    moral_always_j,
    moral_j_then_m,
    moral_j_then_n,
    punish_always_j,
    punish_j_then_m,
    punish_j_then_n,
    teammate_moral_always_j,
    teammate_moral_j_then_m,
    teammate_moral_j_then_n,
    feedback,
    gender,
    age,
    # Consent and comprehension checks
    consent,
    comprehension_check_attempts,
    comprehension_check_failed
  )

# Check data before filtering
cat("\n=== DATA CHECK ===\n")
cat("Total participants who played:", n_distinct(long_data$participant_id), "\n")
cat("Participants with treatment data:", sum(!is.na(long_data$treatment) & long_data$treatment != ""), "\n")
cat("Total observations (participant-rounds):", nrow(long_data), "\n")
cat("\nParticipants by treatment:\n")
print(table(unique(long_data[c("participant_id", "treatment")])$treatment))
cat("\n")

# Data is already filtered during extraction (only rows with letter_choice)
# No additional filtering needed

# Save the long-format data
write_csv(final_data, "~/Documents/GitHub/Group_Name_Game/name_game_long.csv")

# Print summary statistics
cat("\n=== DATA SUMMARY ===\n\n")

cat("Total participants who played:", n_distinct(final_data$participant_id), "\n")
cat("Total observations (participant-rounds):", nrow(final_data), "\n\n")

cat("Participants by treatment:\n")
print(table(unique(final_data[c("participant_id", "treatment")])$treatment))

cat("\n\nCoordination rates by treatment and phase:\n")
coord_summary <- final_data %>%
  group_by(treatment, phase) %>%
  summarise(
    n_rounds = n(),
    n_coordinated = sum(coordinated, na.rm = TRUE),
    coord_rate = mean(coordinated, na.rm = TRUE),
    mean_points = mean(round_points, na.rm = TRUE),
    .groups = "drop"
  )
print(coord_summary)

cat("\n\nLetter choices by treatment and phase:\n")
letter_summary <- final_data %>%
  filter(!is.na(letter_choice) & letter_choice != "") %>%
  group_by(treatment, phase, letter_choice) %>%
  summarise(
    count = n(),
    .groups = "drop"
  ) %>%
  arrange(treatment, phase, desc(count))
print(letter_summary)

cat("\n\nTotal points earned by treatment:\n")
points_summary <- final_data %>%
  filter(round == 14) %>%  # Final round total_points
  group_by(treatment) %>%
  summarise(
    n = n(),
    mean_total_points = mean(total_points, na.rm = TRUE),
    median_total_points = median(total_points, na.rm = TRUE),
    sd_total_points = sd(total_points, na.rm = TRUE),
    min_points = min(total_points, na.rm = TRUE),
    max_points = max(total_points, na.rm = TRUE),
    .groups = "drop"
  )
print(points_summary)

cat("\n\n=== PREREGISTERED ANALYSES ===\n\n")

# =============================================================================
# H1: ATTEMPTED SWITCHING (Behavioral Analysis)
# =============================================================================

# Create attempted switching variable for rounds 8-14
# Attempted switching = 1 if chose letter other than J, 0 if chose J
switching_data <- final_data %>%
  filter(round >= 8 & round <= 14) %>%
  mutate(
    attempted_switch = ifelse(letter_choice != "J", 1, 0)
  )

cat("H1: Attempted Switching Analysis\n")
cat("Testing whether feedback condition increases switching away from J in rounds 8-14\n\n")

# Mixed-effects logistic regression
# Model: AttemptSwitch ~ treatment + (1|participantID) + (1|groupID)
h1_model <- glmer(attempted_switch ~ treatment + (1 | participant_id) + (1 | group_id),
                  data = switching_data,
                  family = binomial(link = "logit"))

cat("Mixed-effects logistic regression results:\n")
print(summary(h1_model))

cat("\nEffect plot:\n")
plot(allEffects(h1_model))

# Descriptive statistics by condition
switch_descriptives <- switching_data %>%
  group_by(treatment) %>%
  summarise(
    n_obs = n(),
    n_participants = n_distinct(participant_id),
    n_switches = sum(attempted_switch),
    switch_rate = mean(attempted_switch),
    .groups = "drop"
  )

cat("\n\nDescriptive statistics - Attempted switching by condition:\n")
print(switch_descriptives)

# =============================================================================
# H2: MORAL APPROPRIATENESS OF ALWAYS CHOOSING J
# =============================================================================

cat("\n\n" ,rep("=", 80), "\n", sep = "")
cat("H2: Moral Appropriateness of Always Choosing J\n")
cat("Testing whether feedback condition decreases moral appropriateness ratings\n\n")

# Create participant-level dataset for moral evaluations
moral_data <- final_data %>%
  group_by(participant_id) %>%
  slice(1) %>%
  ungroup()

# Linear mixed-effects model
# Model: moral_always_j ~ treatment + (1|groupID)
h2_model <- lmer(moral_always_j ~ treatment + (1 | group_id),
                 data = moral_data)

cat("Linear mixed-effects model results:\n")
print(summary(h2_model))

cat("\nEffect plot:\n")
plot(allEffects(h2_model))

# Descriptive statistics
h2_descriptives <- moral_data %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    mean_moral_j = mean(moral_always_j, na.rm = TRUE),
    sd_moral_j = sd(moral_always_j, na.rm = TRUE),
    median_moral_j = median(moral_always_j, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n\nDescriptive statistics - Moral appropriateness of always J:\n")
print(h2_descriptives)

# =============================================================================
# H3: PUNISHMENT OF ALWAYS CHOOSING J
# =============================================================================

cat("\n\n", rep("=", 80), "\n", sep = "")
cat("H3: Punishment of Always Choosing J\n")
cat("Testing whether feedback condition increases punishment ratings\n\n")

# Linear mixed-effects model
# Model: punish_always_j ~ treatment + (1|groupID)
h3_model <- lmer(punish_always_j ~ treatment + (1 | group_id),
                 data = moral_data)

cat("Linear mixed-effects model results:\n")
print(summary(h3_model))

cat("\nEffect plot:\n")
plot(allEffects(h3_model))

# Descriptive statistics
h3_descriptives <- moral_data %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    mean_punish_j = mean(punish_always_j, na.rm = TRUE),
    sd_punish_j = sd(punish_always_j, na.rm = TRUE),
    median_punish_j = median(punish_always_j, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n\nDescriptive statistics - Punishment of always J:\n")
print(h3_descriptives)

# =============================================================================
# H4: TEAMMATE MORAL EVALUATION OF ALWAYS CHOOSING J
# =============================================================================

cat("\n\n", rep("=", 80), "\n", sep = "")
cat("H4: Teammate Moral Evaluation (Blameworthiness/Praiseworthiness) of Always J\n")
cat("Testing whether feedback condition affects teammate moral evaluations\n\n")

# Linear mixed-effects model
# Model: teammate_moral_always_j ~ treatment + (1|groupID)
h4_model <- lmer(teammate_moral_always_j ~ treatment + (1 | group_id),
                 data = moral_data)

cat("Linear mixed-effects model results:\n")
print(summary(h4_model))

cat("\nEffect plot:\n")
plot(allEffects(h4_model))

# Descriptive statistics
h4_descriptives <- moral_data %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    mean_teammate_j = mean(teammate_moral_always_j, na.rm = TRUE),
    sd_teammate_j = sd(teammate_moral_always_j, na.rm = TRUE),
    median_teammate_j = median(teammate_moral_always_j, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n\nDescriptive statistics - Teammate moral evaluation of always J:\n")
print(h4_descriptives)

# =============================================================================
# EXPLORATORY ANALYSES: M and N
# =============================================================================

cat("\n\n", rep("=", 80), "\n", sep = "")
cat("EXPLORATORY ANALYSES: Moral Evaluations for M and N\n\n")

# Moral appropriateness of M
cat("Moral appropriateness of always choosing M:\n")
exp_m_moral <- lmer(moral_j_then_m ~ treatment + (1 | group_id),
                    data = moral_data)
print(summary(exp_m_moral))
plot(allEffects(exp_m_moral))

exp_m_desc <- moral_data %>%
  group_by(treatment) %>%
  summarise(
    mean_moral_m = mean(moral_j_then_m, na.rm = TRUE),
    sd_moral_m = sd(moral_j_then_m, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_m_desc)

# Punishment of M
cat("\n\nPunishment of always choosing M:\n")
exp_m_punish <- lmer(punish_j_then_m ~ treatment + (1 | group_id),
                     data = moral_data)
print(summary(exp_m_punish))
plot(allEffects(exp_m_punish))

exp_m_punish_desc <- moral_data %>%
  group_by(treatment) %>%
  summarise(
    mean_punish_m = mean(punish_j_then_m, na.rm = TRUE),
    sd_punish_m = sd(punish_j_then_m, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_m_punish_desc)

# Teammate evaluation of M
cat("\n\nTeammate moral evaluation of always choosing M:\n")
exp_m_teammate <- lmer(teammate_moral_j_then_m ~ treatment + (1 | group_id),
                       data = moral_data)
print(summary(exp_m_teammate))
plot(allEffects(exp_m_teammate))

exp_m_teammate_desc <- moral_data %>%
  group_by(treatment) %>%
  summarise(
    mean_teammate_m = mean(teammate_moral_j_then_m, na.rm = TRUE),
    sd_teammate_m = sd(teammate_moral_j_then_m, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_m_teammate_desc)

# Moral appropriateness of N
cat("\n\n", rep("-", 80), "\n", sep = "")
cat("Moral appropriateness of always choosing N:\n")
exp_n_moral <- lmer(moral_j_then_n ~ treatment + (1 | group_id),
                    data = moral_data)
print(summary(exp_n_moral))
plot(allEffects(exp_n_moral))

exp_n_desc <- moral_data %>%
  group_by(treatment) %>%
  summarise(
    mean_moral_n = mean(moral_j_then_n, na.rm = TRUE),
    sd_moral_n = sd(moral_j_then_n, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_n_desc)

# Punishment of N
cat("\n\nPunishment of always choosing N:\n")
exp_n_punish <- lmer(punish_j_then_n ~ treatment + (1 | group_id),
                     data = moral_data)
print(summary(exp_n_punish))
plot(allEffects(exp_n_punish))

exp_n_punish_desc <- moral_data %>%
  group_by(treatment) %>%
  summarise(
    mean_punish_n = mean(punish_j_then_n, na.rm = TRUE),
    sd_punish_n = sd(punish_j_then_n, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_n_punish_desc)

# Teammate evaluation of N
cat("\n\nTeammate moral evaluation of always choosing N:\n")
exp_n_teammate <- lmer(teammate_moral_j_then_n ~ treatment + (1 | group_id),
                       data = moral_data)
print(summary(exp_n_teammate))
plot(allEffects(exp_n_teammate))

exp_n_teammate_desc <- moral_data %>%
  group_by(treatment) %>%
  summarise(
    mean_teammate_n = mean(teammate_moral_j_then_n, na.rm = TRUE),
    sd_teammate_n = sd(teammate_moral_j_then_n, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_n_teammate_desc)

# =============================================================================
# EXPLORATORY: RULE-FOLLOWING QUESTIONS
# =============================================================================

cat("\n\n", rep("=", 80), "\n", sep = "")
cat("EXPLORATORY: Rule-Following Questions\n\n")

rule_summary <- moral_data %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    prop_following_rule = mean(following_rule == "yes", na.rm = TRUE),
    mean_rule_importance = mean(rule_importance, na.rm = TRUE),
    sd_rule_importance = sd(rule_importance, na.rm = TRUE),
    mean_same_rule = mean(same_rule_from_start, na.rm = TRUE),
    sd_same_rule = sd(same_rule_from_start, na.rm = TRUE),
    .groups = "drop"
  )

cat("Rule-following summary by condition:\n")
print(rule_summary)

cat("\n\n=== PREREGISTERED ANALYSES COMPLETE ===\n")
cat("Long-format data saved to: ~/Documents/GitHub/Group_Name_Game/name_game_long.csv\n")

# =============================================================================
# VISUALIZATIONS
# =============================================================================

cat("\n\n=== CREATING VISUALIZATIONS ===\n")

# Check all letter choices in the data
cat("\nAll letter choices in dataset:\n")
print(table(final_data$letter_choice, useNA = "ifany"))

cat("\nLetter choices by round:\n")
print(table(final_data$round, final_data$letter_choice, useNA = "ifany"))

# Filter to only J, M, N choices for visualization
jmn_data <- final_data %>%
  filter(letter_choice %in% c("J", "M", "N"))

cat("\nRows after filtering to J, M, N:\n")
cat("Total rows:", nrow(jmn_data), "\n")
cat("Rounds represented:", paste(unique(jmn_data$round), collapse = ", "), "\n")

# 1. Letter choice proportions by round and treatment
letter_proportions <- jmn_data %>%
  group_by(treatment, round, letter_choice) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(treatment, round) %>%
  mutate(proportion = count / sum(count))

# Plot 1: Letter choice proportions over time by treatment
p1 <- ggplot(letter_proportions, aes(x = round, y = proportion, color = letter_choice)) +
  geom_line(aes(group = letter_choice), size = 1.2) +
  geom_point(size = 3) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = 7.5, y = 1, label = "M & N introduced",
           hjust = -0.1, vjust = 1, color = "red", size = 3.5) +
  facet_wrap(~treatment, ncol = 1) +
  scale_color_manual(values = c("J" = "#2E86AB", "M" = "#A23B72", "N" = "#F18F01"),
                     name = "Letter") +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format()) +
  labs(
    title = "Letter Choice Proportions Across Rounds",
    subtitle = "Red line indicates introduction of M & N (15 points each)",
    x = "Round",
    y = "Proportion of Choices",
    caption = paste("Only J, M, and N choices shown | N =", n_distinct(final_data$participant_id), "participants")
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    strip.text = element_text(face = "bold", size = 12),
    legend.position = "bottom"
  )

ggsave("~/Documents/GitHub/Group_Name_Game/letter_choice_proportions.png",
       plot = p1, width = 10, height = 8, dpi = 300)
cat("Saved: letter_choice_proportions.png\n")
print(p1)

# Plot 2: Raw counts of letter choices
letter_counts <- jmn_data %>%
  group_by(treatment, round, letter_choice) %>%
  summarise(count = n(), .groups = "drop")

p2 <- ggplot(letter_counts, aes(x = round, y = count, color = letter_choice)) +
  geom_line(aes(group = letter_choice), size = 1.2) +
  geom_point(size = 3) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = 7.5, y = max(letter_counts$count), label = "M & N introduced",
           hjust = -0.1, vjust = 1, color = "red", size = 3.5) +
  facet_wrap(~treatment, ncol = 1, scales = "free_y") +
  scale_color_manual(values = c("J" = "#2E86AB", "M" = "#A23B72", "N" = "#F18F01"),
                     name = "Letter") +
  scale_x_continuous(breaks = 1:14) +
  labs(
    title = "Letter Choice Counts Across Rounds",
    subtitle = "Red line indicates introduction of M & N (15 points each)",
    x = "Round",
    y = "Number of Participants",
    caption = paste("Only J, M, and N choices shown | N =", n_distinct(final_data$participant_id), "participants")
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    strip.text = element_text(face = "bold", size = 12),
    legend.position = "bottom"
  )

ggsave("~/Documents/GitHub/Group_Name_Game/letter_choice_counts.png",
       plot = p2, width = 10, height = 8, dpi = 300)
cat("Saved: letter_choice_counts.png\n")
print(p2)

# Plot 3: Stacked area chart
p3 <- ggplot(letter_proportions, aes(x = round, y = proportion, fill = letter_choice)) +
  geom_area(alpha = 0.7, position = "stack") +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = 7.5, y = 1, label = "M & N introduced",
           hjust = -0.1, vjust = 1, color = "red", size = 3.5) +
  facet_wrap(~treatment, ncol = 1) +
  scale_fill_manual(values = c("J" = "#2E86AB", "M" = "#A23B72", "N" = "#F18F01"),
                    name = "Letter") +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format()) +
  labs(
    title = "Letter Choice Distribution Across Rounds (Stacked)",
    subtitle = "Red line indicates introduction of M & N (15 points each)",
    x = "Round",
    y = "Proportion of Choices",
    caption = "Only J, M, and N choices shown"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    strip.text = element_text(face = "bold", size = 12),
    legend.position = "bottom"
  )

ggsave("~/Documents/GitHub/Group_Name_Game/letter_choice_stacked.png",
       plot = p3, width = 10, height = 8, dpi = 300)
cat("Saved: letter_choice_stacked.png\n")
print(p3)

# Plot 4: Coordination rates over time
coord_by_round <- final_data %>%
  group_by(treatment, round) %>%
  summarise(
    coord_rate = mean(coordinated, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

p4 <- ggplot(coord_by_round, aes(x = round, y = coord_rate, color = treatment)) +
  geom_line(aes(group = treatment), size = 1.2) +
  geom_point(size = 3) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = 7.5, y = 1, label = "M & N introduced",
           hjust = -0.1, vjust = 1, color = "red", size = 3.5) +
  scale_color_manual(values = c("feedback" = "#6A4C93", "no_feedback" = "#1982C4"),
                     labels = c("feedback", "no feedback"),
                     name = "Treatment") +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Coordination Rate Across Rounds by Condition",
    subtitle = "Red line indicates introduction of M & N (15 points each)",
    x = "Round",
    y = "Coordination Rate",
    caption = paste("N =", n_distinct(final_data$participant_id), "participants")
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  )

ggsave("~/Documents/GitHub/Group_Name_Game/coordination_rates.png",
       plot = p4, width = 10, height = 6, dpi = 300)
cat("Saved: coordination_rates.png\n")
print(p4)

# Plot 5: Switching rates by round and condition (all rounds 1-14)
# Calculate switching for ALL rounds
switch_all_rounds <- final_data %>%
  mutate(
    attempted_switch = ifelse(letter_choice != "J", 1, 0)
  ) %>%
  group_by(treatment, round) %>%
  summarise(
    n = n(),
    n_switches = sum(attempted_switch),
    switch_rate = mean(attempted_switch),
    .groups = "drop"
  )

p5 <- ggplot(switch_all_rounds, aes(x = round, y = switch_rate, color = treatment,
                                     linetype = treatment, shape = treatment)) +
  geom_line(linewidth = 1.3) +
  geom_point(size = 3.5) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", linewidth = 1) +
  annotate("text", x = 7.5, y = 0.95, label = "M & N introduced",
           hjust = -0.1, vjust = 1, color = "red", size = 3.5) +
  scale_color_manual(values = c("no_feedback" = "#1982C4", "feedback" = "#6A4C93"),
                     labels = c("no feedback", "feedback"),
                     name = "Condition") +
  scale_linetype_manual(values = c("no_feedback" = "solid", "feedback" = "dashed"),
                        labels = c("no feedback", "feedback"),
                        name = "Condition") +
  scale_shape_manual(values = c("no_feedback" = 16, "feedback" = 17),
                     labels = c("no feedback", "feedback"),
                     name = "Condition") +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Attempted switching by condition",
    subtitle = "Proportion of choices where participants switched away from J",
    x = "Round",
    y = "Switching Rate",
    caption = paste("N =", n_distinct(final_data$participant_id), "participants")
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  )

ggsave("~/Documents/GitHub/Group_Name_Game/switching_rates.png",
       plot = p5, width = 10, height = 6, dpi = 300)
cat("Saved: switching_rates.png\n")
print(p5)

# Plot 6: Moral evaluations - preregistered Always J DVs only
# Prepare data with individual observations
moral_plot_data <- moral_data %>%
  select(treatment, moral_always_j, punish_always_j, teammate_moral_always_j) %>%
  pivot_longer(
    cols = c(moral_always_j, punish_always_j, teammate_moral_always_j),
    names_to = "measure",
    values_to = "rating"
  ) %>%
  mutate(
    measure_label = case_when(
      measure == "moral_always_j" ~ "Moral Appropriateness",
      measure == "punish_always_j" ~ "Punishment",
      measure == "teammate_moral_always_j" ~ "Praiseworthiness"
    )
  )

# Calculate summary statistics for confidence intervals
moral_summary_ci <- moral_plot_data %>%
  group_by(treatment, measure_label) %>%
  summarise(
    mean = mean(rating, na.rm = TRUE),
    se = sd(rating, na.rm = TRUE) / sqrt(sum(!is.na(rating))),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  )

# Reorder for better visualization
moral_plot_data$measure_label <- factor(moral_plot_data$measure_label,
                                         levels = c("Moral Appropriateness", "Punishment", "Praiseworthiness"))
moral_summary_ci$measure_label <- factor(moral_summary_ci$measure_label,
                                         levels = c("Moral Appropriateness", "Punishment", "Praiseworthiness"))

p6 <- ggplot(moral_plot_data, aes(x = treatment, y = rating, color = treatment)) +
  # Add jittered individual data points with transparency
  geom_jitter(width = 0.2, alpha = 0.2, size = 1.5) +
  # Add confidence intervals
  geom_pointrange(data = moral_summary_ci,
                  aes(y = mean, ymin = ci_lower, ymax = ci_upper),
                  size = 0.8, linewidth = 1.2, fatten = 3) +
  facet_wrap(~measure_label, ncol = 3) +
  scale_color_manual(values = c("no_feedback" = "#1982C4", "feedback" = "#6A4C93"),
                     labels = c("no feedback", "feedback"),
                     name = "Condition") +
  scale_y_continuous(limits = c(0, 100)) +
  labs(
    title = "Moralization of always choosing J by condition",
    x = "Condition",
    y = "Rating (0-100)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    strip.text = element_text(face = "bold", size = 11),
    legend.position = "bottom",
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank()
  )

ggsave("~/Documents/GitHub/Group_Name_Game/moral_evaluations.png",
       plot = p6, width = 12, height = 5, dpi = 300)
cat("Saved: moral_evaluations.png\n")
print(p6)

cat("\n=== VISUALIZATION COMPLETE ===\n")
cat("All plots saved to: ~/Documents/GitHub/Group_Name_Game/\n")

# Feedback groups only
p_heatmap_fb <- heatmap_data %>%
  filter(treatment == "feedback") %>%
  ggplot(aes(x = round, y = as.factor(participant_num), fill = letter_choice)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "black", linewidth = 0.8) +
  facet_wrap(~ group_label, ncol = 4, scales = "free_y") +
  scale_fill_manual(values = letter_colors, name = "Letter") +
  scale_x_continuous(breaks = seq(2, 14, 2), expand = c(0.01, 0.01)) +
  scale_y_discrete(expand = c(0.01, 0.01)) +
  labs(
    title = "Letter choices Feedback Condition",
    x = "Round",
    y = "Participant"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    strip.text = element_text(face = "bold", size = 9),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid = element_blank(),
    panel.spacing = unit(0.5, "lines"),
    legend.position = "right"
  )

p_heatmap_fb
ggsave("~/Documents/GitHub/Group_Name_Game/heatmap_feedback.png",
       plot = p_heatmap_fb, width = 12, height = 10, dpi = 300)

# No feedback groups only
p_heatmap_nf <- heatmap_data %>%
  filter(treatment == "no_feedback") %>%
  ggplot(aes(x = round, y = as.factor(participant_num), fill = letter_choice)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "black", linewidth = 0.8) +
  facet_wrap(~ group_label, ncol = 4, scales = "free_y") +
  scale_fill_manual(values = letter_colors, name = "Letter") +
  scale_x_continuous(breaks = seq(2, 14, 2), expand = c(0.01, 0.01)) +
  scale_y_discrete(expand = c(0.01, 0.01)) +
  labs(
    title = "Letter choice No Feedback Condition",
    x = "Round",
    y = "Participant"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    strip.text = element_text(face = "bold", size = 9),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    panel.grid = element_blank(),
    panel.spacing = unit(0.5, "lines"),
    legend.position = "right"
  )

p_heatmap_nf
ggsave("~/Documents/GitHub/Group_Name_Game/heatmap_no_feedback.png",
       plot = p_heatmap_nf, width = 12, height = 10, dpi = 300)
