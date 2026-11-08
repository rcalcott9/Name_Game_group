# Name Game - Data Analysis Script
# This script converts the wide-format oTree data to long format
# and extracts key variables for analysis

library(tidyverse)
library(lme4)  # For mixed-effects models
library(lmerTest)  # For p-values in mixed models
library(effects)  # For effect plots

# Read the data
data <- read_csv("~/Downloads/all_apps_wide-2026-01-12-6.csv")

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
    dplyr::select(
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
    dplyr::select(
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
  dplyr::select(
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
#write_csv(final_data, "~/Documents/GitHub/Group_Name_Game/name_game_long.csv")

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
final_data

# Total unique participants in final_data
cat("Total participants in final_data:", n_distinct(final_data$participant_id), "\n")

# By treatment
cat("\nBy treatment:\n")
final_data %>%
  distinct(participant_id, treatment) %>%
  count(treatment)

# Exclude the incomplete group
final_data <- final_data %>%
  filter(!(treatment == "feedback" & group_id == 4))

#gender
final_data %>%
  distinct(participant_id, gender) %>%
  count(gender)

# Verify clean data
cat("Total participants:", n_distinct(final_data$participant_id), "\n")
cat("Should be divisible by 6:", n_distinct(final_data$participant_id) %% 6 == 0, "\n")

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

p5 <- ggplot(switch_all_rounds, aes(x = round, y = switch_rate, color = treatment)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2.5) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "gray40", linewidth = 0.6) +
  annotate("text", x = 7.7, y = 0.92, label = "Higher payoffs introduced",
           hjust = 0, color = "gray30", size = 3, family = "serif") +
  scale_color_manual(values = c("no_feedback" = "gray60", "feedback" = "black"),
                     labels = c("No Common Knowledge", "Common Knowledge"),
                     name = NULL) +
  scale_shape_manual(values = c("no_feedback" = 16, "feedback" = 17),
                     labels = c("No Feedback", "Feedback"),
                     name = NULL) +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1), limits = c(0, 1)) +
  labs(
    title = "Percentage of Switching (Non-J) Choices by Condition",
    x = "Round",
    y = "Percent of Choices Switching from J"
  ) +
  theme_classic(base_size = 12, base_family = "serif") +
  theme(
    plot.title = element_text(size = 15, hjust = 0.5, face = "bold"),
    legend.position = c(0.85, 0.15),
    legend.background = element_rect(fill = "white", color = NA),
    legend.key.size = unit(1.2, "lines"),
    axis.title = element_text(size = 12, face = "bold"),
    axis.text = element_text(size = 12, color = "black"),
    panel.grid.major.y = element_line(color = "gray90", linewidth = 0.3)
  )

p5

0# Plot 6: Moral evaluations - preregistered Always J DVs only
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


# Prepare data with individual observations
moral_plot_data <- moral_data %>%
  select(treatment, moral_always_j, punish_always_j, teammate_moral_always_j) %>%
  mutate(
    teammate_moral_always_j = 100 - teammate_moral_always_j  # Reverse code
  ) %>%
  pivot_longer(
    cols = c(moral_always_j, punish_always_j, teammate_moral_always_j),
    names_to = "measure",
    values_to = "rating"
  ) %>%
  mutate(
    measure_label = case_when(
      measure == "moral_always_j" ~ "Moral Appropriateness",
      measure == "punish_always_j" ~ "Intent to Punish",
      measure == "teammate_moral_always_j" ~ "Blameworthiness"
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
                                        levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness"))
moral_summary_ci$measure_label <- factor(moral_summary_ci$measure_label,
                                         levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness"))

# Calculate p-values for each measure
sig_tests <- moral_plot_data %>%
  group_by(measure_label) %>%
  summarise(
    p_value = t.test(rating ~ treatment)$p.value,
    .groups = "drop"
  ) %>%
  mutate(
    stars = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ "ns"
    )
  )

p6 <- ggplot(moral_plot_data, aes(x = treatment, y = rating, color = treatment)) +
  geom_jitter(width = 0.15, alpha = 0.15, size = 1, shape = 16) +
  geom_pointrange(data = moral_summary_ci,
                  aes(y = mean, ymin = ci_lower, ymax = ci_upper),
                  size = 0.6, linewidth = 0.8, fatten = 3) +
  geom_segment(data = sig_tests,
               aes(x = 1, xend = 2, y = 95, yend = 95),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests,
               aes(x = 1, xend = 1, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests,
               aes(x = 2, xend = 2, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_text(data = sig_tests,
            aes(x = 1.5, y = 98, label = stars),
            color = "black", size = 4, family = "serif", inherit.aes = FALSE) +
  facet_wrap(~measure_label, ncol = 3) +
  scale_color_manual(values = c("no_feedback" = "gray60", "feedback" = "black"),
                     labels = c("No Feedback", "Feedback"),
                     name = NULL) +
  scale_x_discrete(labels = c("no_feedback" = "NCK", "feedback" = "CK")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
  labs(
    title = "Moral Evaluations of Always Choosing Precedent (J)",
    x = NULL,
    y = "Rating (0–100)"
  ) +
  theme_classic(base_size = 14, base_family = "serif") +
  theme(
    plot.title = element_text(size = 14, hjust = 0.5, face = "bold"),
    strip.text = element_text(size = 12, face = "bold"),
    strip.background = element_blank(),
    legend.position = "none",
    axis.text.x = element_text(size = 12, color = "black"),
    axis.text.y = element_text(size = 12, color = "black"),
    axis.title.y = element_text(size = 12),
    panel.spacing = unit(1.5, "lines")
  )

p6

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

## exploratory ##

# =============================================================================
# EXPLORATORY ANALYSES: MORALIZATION OF M AND N
# Subsetting to M/N choosers in FEEDBACK condition only
# (No-feedback condition: all participants included)
# =============================================================================

cat("\n\n", rep("=", 80), "\n", sep = "")
cat("EXPLORATORY: Moralization of M/N\n")
cat("Feedback condition: subset to participants who chose that letter\n")
cat("No-feedback condition: all participants\n\n")

# Identify participants who chose M or N in rounds 8-14
m_choosers <- final_data %>%
  filter(round >= 8 & round <= 14, letter_choice == "M") %>%
  pull(participant_id) %>%
  unique()

n_choosers <- final_data %>%
  filter(round >= 8 & round <= 14, letter_choice == "N") %>%
  pull(participant_id) %>%
  unique()

cat("Total M choosers (rounds 8-14):", length(m_choosers), "\n")
cat("Total N choosers (rounds 8-14):", length(n_choosers), "\n\n")

# Create subsetted datasets:
# - No-feedback: ALL participants
# - Feedback: only those who chose that letter

moral_data_m_analysis <- moral_data %>%
  filter(treatment == "no_feedback" | 
           (treatment == "feedback" & participant_id %in% m_choosers))

moral_data_n_analysis <- moral_data %>%
  filter(treatment == "no_feedback" | 
           (treatment == "feedback" & participant_id %in% n_choosers))

# Check sample sizes by condition
cat("M analysis sample by condition:\n")
print(table(moral_data_m_analysis$treatment))

cat("\nN analysis sample by condition:\n")
print(table(moral_data_n_analysis$treatment))

# -----------------------------------------------------------------------------
# MORALIZATION OF M
# -----------------------------------------------------------------------------

cat("\n\n", rep("-", 80), "\n", sep = "")
cat("Moral evaluations of M\n")
cat("(Feedback: M-choosers only | No-feedback: all participants)\n\n")

# Moral appropriateness of M
cat("H2-exploratory: Moral appropriateness of choosing M:\n")
exp_m_moral <- tryCatch({
  lmer(moral_j_then_m ~ treatment + (1 | group_id), data = moral_data_m_analysis)
}, error = function(e) {
  cat("Mixed model failed, using linear model\n")
  lm(moral_j_then_m ~ treatment, data = moral_data_m_analysis)
})
print(summary(exp_m_moral))

exp_m_moral_desc <- moral_data_m_analysis %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    mean = mean(moral_j_then_m, na.rm = TRUE),
    sd = sd(moral_j_then_m, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_m_moral_desc)

# Punishment of M
cat("\n\nH3-exploratory: Punishment of choosing M:\n")
exp_m_punish <- tryCatch({
  lmer(punish_j_then_m ~ treatment + (1 | group_id), data = moral_data_m_analysis)
}, error = function(e) {
  lm(punish_j_then_m ~ treatment, data = moral_data_m_analysis)
})
print(summary(exp_m_punish))

exp_m_punish_desc <- moral_data_m_analysis %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    mean = mean(punish_j_then_m, na.rm = TRUE),
    sd = sd(punish_j_then_m, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_m_punish_desc)

# Teammate evaluation of M
cat("\n\nH4-exploratory: Teammate moral evaluation of choosing M:\n")
exp_m_teammate <- tryCatch({
  lmer(teammate_moral_j_then_m ~ treatment + (1 | group_id), data = moral_data_m_analysis)
}, error = function(e) {
  lm(teammate_moral_j_then_m ~ treatment, data = moral_data_m_analysis)
})
print(summary(exp_m_teammate))

exp_m_teammate_desc <- moral_data_m_analysis %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    mean = mean(teammate_moral_j_then_m, na.rm = TRUE),
    sd = sd(teammate_moral_j_then_m, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_m_teammate_desc)



# -----------------------------------------------------------------------------
# VISUALIZATION: MORALIZATION OF M
# -----------------------------------------------------------------------------

# Prepare data for M visualization
moral_m_plot_data <- moral_data_m_analysis %>%
  select(treatment, moral_j_then_m, punish_j_then_m, teammate_moral_j_then_m) %>%
  mutate(
    teammate_moral_j_then_m = 100 - teammate_moral_j_then_m  # Reverse code for blameworthiness
  ) %>%
  pivot_longer(
    cols = c(moral_j_then_m, punish_j_then_m, teammate_moral_j_then_m),
    names_to = "measure",
    values_to = "rating"
  ) %>%
  mutate(
    measure_label = case_when(
      measure == "moral_j_then_m" ~ "Moral Appropriateness",
      measure == "punish_j_then_m" ~ "Intent to Punish",
      measure == "teammate_moral_j_then_m" ~ "Blameworthiness"
    )
  )

# Calculate summary statistics
moral_m_summary <- moral_m_plot_data %>%
  group_by(treatment, measure_label) %>%
  summarise(
    mean = mean(rating, na.rm = TRUE),
    se = sd(rating, na.rm = TRUE) / sqrt(sum(!is.na(rating))),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  )

# Set factor levels
moral_m_plot_data$measure_label <- factor(moral_m_plot_data$measure_label,
                                          levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness"))
moral_m_summary$measure_label <- factor(moral_m_summary$measure_label,
                                        levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness"))

# Calculate p-values for M
sig_tests_m <- moral_m_plot_data %>%
  group_by(measure_label) %>%
  summarise(
    p_value = tryCatch(t.test(rating ~ treatment)$p.value, error = function(e) NA),
    .groups = "drop"
  ) %>%
  mutate(
    stars = case_when(
      is.na(p_value) ~ "",
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ "ns"
    )
  )

# Plot for M
p_moral_m <- ggplot(moral_m_plot_data, aes(x = treatment, y = rating, color = treatment)) +
  geom_jitter(width = 0.15, alpha = 0.15, size = 1, shape = 16) +
  geom_pointrange(data = moral_m_summary,
                  aes(y = mean, ymin = ci_lower, ymax = ci_upper),
                  size = 0.6, linewidth = 0.8, fatten = 3) +
  geom_segment(data = sig_tests_m,
               aes(x = 1, xend = 2, y = 95, yend = 95),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_m,
               aes(x = 1, xend = 1, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_m,
               aes(x = 2, xend = 2, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_text(data = sig_tests_m,
            aes(x = 1.5, y = 98, label = stars),
            color = "black", size = 4, family = "serif", inherit.aes = FALSE) +
  facet_wrap(~measure_label, ncol = 3) +
  scale_color_manual(values = c("no_feedback" = "gray60", "feedback" = "#A23B72"),
                     labels = c("No Feedback", "Feedback"),
                     name = NULL) +
  scale_x_discrete(labels = c("no_feedback" = "NCK", "feedback" = "CK")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
  labs(
    title = "Moral Evaluations of Switching to M",
    subtitle = "CK condition: M-choosers only | NCK condition: all participants",
    x = NULL,
    y = "Rating (0–100)"
  ) +
  theme_classic(base_size = 14, base_family = "serif") +
  theme(
    plot.title = element_text(size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray40"),
    strip.text = element_text(size = 12),
    strip.background = element_blank(),
    legend.position = "none",
    axis.text.x = element_text(size = 12, color = "black"),
    axis.text.y = element_text(size = 12, color = "black"),
    axis.title.y = element_text(size = 12),
    panel.spacing = unit(1.5, "lines")
  )

print(p_moral_m)
ggsave("~/Documents/GitHub/Group_Name_Game/moral_evaluations_M_exploratory.png",
       plot = p_moral_m, width = 10, height = 5, dpi = 300)
cat("\nSaved: moral_evaluations_M_exploratory.png\n")

# -----------------------------------------------------------------------------
# MORALIZATION OF N
# -----------------------------------------------------------------------------

cat("\n\n", rep("-", 80), "\n", sep = "")
cat("Moral evaluations of N\n")
cat("(Feedback: N-choosers only | No-feedback: all participants)\n\n")

# Moral appropriateness of N
cat("H2-exploratory: Moral appropriateness of choosing N:\n")
exp_n_moral <- tryCatch({
  lmer(moral_j_then_n ~ treatment + (1 | group_id), data = moral_data_n_analysis)
}, error = function(e) {
  lm(moral_j_then_n ~ treatment, data = moral_data_n_analysis)
})
print(summary(exp_n_moral))

exp_n_moral_desc <- moral_data_n_analysis %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    mean = mean(moral_j_then_n, na.rm = TRUE),
    sd = sd(moral_j_then_n, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_n_moral_desc)

# Punishment of N
cat("\n\nH3-exploratory: Punishment of choosing N:\n")
exp_n_punish <- tryCatch({
  lmer(punish_j_then_n ~ treatment + (1 | group_id), data = moral_data_n_analysis)
}, error = function(e) {
  lm(punish_j_then_n ~ treatment, data = moral_data_n_analysis)
})
print(summary(exp_n_punish))

exp_n_punish_desc <- moral_data_n_analysis %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    mean = mean(punish_j_then_n, na.rm = TRUE),
    sd = sd(punish_j_then_n, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_n_punish_desc)

# Teammate evaluation of N
cat("\n\nH4-exploratory: Teammate moral evaluation of choosing N:\n")
exp_n_teammate <- tryCatch({
  lmer(teammate_moral_j_then_n ~ treatment + (1 | group_id), data = moral_data_n_analysis)
}, error = function(e) {
  lm(teammate_moral_j_then_n ~ treatment, data = moral_data_n_analysis)
})
print(summary(exp_n_teammate))

exp_n_teammate_desc <- moral_data_n_analysis %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    mean = mean(teammate_moral_j_then_n, na.rm = TRUE),
    sd = sd(teammate_moral_j_then_n, na.rm = TRUE),
    .groups = "drop"
  )
cat("\nDescriptives:\n")
print(exp_n_teammate_desc)

# -----------------------------------------------------------------------------
# VISUALIZATION: MORALIZATION OF N
# -----------------------------------------------------------------------------

# Prepare data for N visualization
moral_n_plot_data <- moral_data_n_analysis %>%
  select(treatment, moral_j_then_n, punish_j_then_n, teammate_moral_j_then_n) %>%
  mutate(
    teammate_moral_j_then_n = 100 - teammate_moral_j_then_n  # Reverse code for blameworthiness
  ) %>%
  pivot_longer(
    cols = c(moral_j_then_n, punish_j_then_n, teammate_moral_j_then_n),
    names_to = "measure",
    values_to = "rating"
  ) %>%
  mutate(
    measure_label = case_when(
      measure == "moral_j_then_n" ~ "Moral Appropriateness",
      measure == "punish_j_then_n" ~ "Intent to Punish",
      measure == "teammate_moral_j_then_n" ~ "Blameworthiness"
    )
  )

# Calculate summary statistics
moral_n_summary <- moral_n_plot_data %>%
  group_by(treatment, measure_label) %>%
  summarise(
    mean = mean(rating, na.rm = TRUE),
    se = sd(rating, na.rm = TRUE) / sqrt(sum(!is.na(rating))),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  )

# Set factor levels
moral_n_plot_data$measure_label <- factor(moral_n_plot_data$measure_label,
                                          levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness"))
moral_n_summary$measure_label <- factor(moral_n_summary$measure_label,
                                        levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness"))

# Calculate p-values for N
sig_tests_n <- moral_n_plot_data %>%
  group_by(measure_label) %>%
  summarise(
    p_value = tryCatch(t.test(rating ~ treatment)$p.value, error = function(e) NA),
    .groups = "drop"
  ) %>%
  mutate(
    stars = case_when(
      is.na(p_value) ~ "",
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ "ns"
    )
  )

# Plot for N
p_moral_n <- ggplot(moral_n_plot_data, aes(x = treatment, y = rating, color = treatment)) +
  geom_jitter(width = 0.15, alpha = 0.15, size = 1, shape = 16) +
  geom_pointrange(data = moral_n_summary,
                  aes(y = mean, ymin = ci_lower, ymax = ci_upper),
                  size = 0.6, linewidth = 0.8, fatten = 3) +
  geom_segment(data = sig_tests_n,
               aes(x = 1, xend = 2, y = 95, yend = 95),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_n,
               aes(x = 1, xend = 1, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_n,
               aes(x = 2, xend = 2, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_text(data = sig_tests_n,
            aes(x = 1.5, y = 98, label = stars),
            color = "black", size = 4, family = "serif", inherit.aes = FALSE) +
  facet_wrap(~measure_label, ncol = 3) +
  scale_color_manual(values = c("no_feedback" = "gray60", "feedback" = "#F18F01"),
                     labels = c("No Feedback", "Feedback"),
                     name = NULL) +
  scale_x_discrete(labels = c("no_feedback" = "NCK", "feedback" = "CK")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
  labs(
    title = "Moral Evaluations of Switching to N",
    subtitle = "CK condition: N-choosers only | NCK condition: all participants",
    x = NULL,
    y = "Rating (0–100)"
  ) +
  theme_classic(base_size = 14, base_family = "serif") +
  theme(
    plot.title = element_text(size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray40"),
    strip.text = element_text(size = 12),
    strip.background = element_blank(),
    legend.position = "none",
    axis.text.x = element_text(size = 12, color = "black"),
    axis.text.y = element_text(size = 12, color = "black"),
    axis.title.y = element_text(size = 12),
    panel.spacing = unit(1.5, "lines")
  )

print(p_moral_n)

cat("\nSaved: moral_evaluations_N_exploratory.png\n")

# -----------------------------------------------------------------------------
# COMBINED VISUALIZATION: M AND N SIDE BY SIDE
# -----------------------------------------------------------------------------

# Add letter indicator to each dataset
moral_m_plot_data$letter <- "M"
moral_n_plot_data$letter <- "N"

# Combine
moral_mn_combined <- bind_rows(moral_m_plot_data, moral_n_plot_data)

# Calculate combined summary
moral_mn_summary <- moral_mn_combined %>%
  group_by(letter, treatment, measure_label) %>%
  summarise(
    mean = mean(rating, na.rm = TRUE),
    se = sd(rating, na.rm = TRUE) / sqrt(sum(!is.na(rating))),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  )

# Calculate p-values for combined
sig_tests_combined <- moral_mn_combined %>%
  group_by(letter, measure_label) %>%
  summarise(
    p_value = tryCatch(t.test(rating ~ treatment)$p.value, error = function(e) NA),
    .groups = "drop"
  ) %>%
  mutate(
    stars = case_when(
      is.na(p_value) ~ "",
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ "ns"
    )
  )

# Combined plot
p_moral_mn <- ggplot(moral_mn_combined, aes(x = treatment, y = rating, color = treatment)) +
  geom_jitter(width = 0.15, alpha = 0.12, size = 0.8, shape = 16) +
  geom_pointrange(data = moral_mn_summary,
                  aes(y = mean, ymin = ci_lower, ymax = ci_upper),
                  size = 0.5, linewidth = 0.7, fatten = 2.5) +
  geom_segment(data = sig_tests_combined,
               aes(x = 1, xend = 2, y = 95, yend = 95),
               color = "black", linewidth = 0.3, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_combined,
               aes(x = 1, xend = 1, y = 95, yend = 92),
               color = "black", linewidth = 0.3, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_combined,
               aes(x = 2, xend = 2, y = 95, yend = 92),
               color = "black", linewidth = 0.3, inherit.aes = FALSE) +
  geom_text(data = sig_tests_combined,
            aes(x = 1.5, y = 98, label = stars),
            color = "black", size = 3.5, family = "serif", inherit.aes = FALSE) +
  facet_grid(letter ~ measure_label) +
  scale_color_manual(values = c("no_feedback" = "gray60", "feedback" = "black"),
                     labels = c("No Feedback", "Feedback"),
                     name = NULL) +
  scale_x_discrete(labels = c("no_feedback" = "NCK", "feedback" = "CK")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
  labs(
    title = "Moral Evaluations of Switching to Higher-Payoff Options (M and N)",
    subtitle = "CK condition: letter-choosers only | NCK condition: all participants",
    x = NULL,
    y = "Rating (0–100)"
  ) +
  theme_classic(base_size = 12, base_family = "serif") +
  theme(
    plot.title = element_text(size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray40"),
    strip.text = element_text(size = 11),
    strip.background = element_blank(),
    legend.position = "none",
    axis.text.x = element_text(size = 11, color = "black"),
    axis.text.y = element_text(size = 11, color = "black"),
    axis.title.y = element_text(size = 11),
    panel.spacing = unit(1, "lines")
  )

print(p_moral_mn)
ggsave("~/Documents/GitHub/Group_Name_Game/moral_evaluations_MN_combined.png",
       plot = p_moral_mn, width = 10, height = 7, dpi = 300)
cat("\nSaved: moral_evaluations_MN_combined.png\n")
cat("M-choosers in feedback:", sum(moral_data_m_analysis$treatment == "feedback"), "\n")
cat("N-choosers in feedback:", sum(moral_data_n_analysis$treatment == "feedback"), "\n")

final_data %>%
  filter(round >= 8 & round <= 14, letter_choice %in% c("M", "N")) %>%
  group_by(letter_choice) %>%
  summarise(
    n_attempts = n(),
    n_coordinated = sum(coordinated),
    success_rate = mean(coordinated)
  )

# Which letter "won" in each group that successfully switched?
final_data %>%
  filter(round >= 8 & round <= 14, treatment == "feedback", coordinated == TRUE) %>%
  count(group_id, letter_choice) %>%
  group_by(group_id) %>%
  slice_max(n, n = 1)

# Classify groups by their dominant coordination outcome
group_outcomes <- final_data %>%
  filter(round >= 8 & round <= 14, treatment == "feedback", coordinated == TRUE) %>%
  count(group_id, letter_choice) %>%
  group_by(group_id) %>%
  slice_max(n, n = 1) %>%
  ungroup() %>%
  select(group_id, group_outcome = letter_choice)

# ============================================================================
# M-GROUPS: Evaluations of M and J (NCK vs CK)
# ============================================================================

# Subset to NCK (all) and CK M-outcome groups
m_group_comparison <- bind_rows(
  moral_data %>%
    filter(treatment == "no_feedback") %>%
    mutate(condition = "NCK"),
  moral_data_with_outcome %>%
    filter(treatment == "feedback", group_outcome == "M") %>%
    mutate(condition = "CK")
) %>%
  select(participant_id, condition, 
         moral_j_then_m, punish_j_then_m, teammate_moral_j_then_m,
         moral_always_j, punish_always_j, teammate_moral_always_j) %>%
  mutate(
    blame_m = 100 - teammate_moral_j_then_m,
    blame_j = 100 - teammate_moral_always_j
  ) %>%
  pivot_longer(
    cols = c(moral_j_then_m, punish_j_then_m, blame_m,
             moral_always_j, punish_always_j, blame_j),
    names_to = "measure",
    values_to = "rating"
  ) %>%
  mutate(
    target_letter = case_when(
      grepl("_m$", measure) | grepl("j_then_m", measure) ~ "M",
      grepl("_j$", measure) | grepl("always_j", measure) ~ "J"
    ),
    measure_type = case_when(
      grepl("^moral", measure) ~ "Moral Appropriateness",
      grepl("^punish", measure) ~ "Intent to Punish",
      grepl("^blame", measure) ~ "Blameworthiness"
    ),
    measure_type = factor(measure_type, levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness")),
    condition = factor(condition, levels = c("NCK", "CK")),
    target_letter = factor(target_letter, levels = c("J", "M"))
  )

# Summary stats
m_group_summary <- m_group_comparison %>%
  group_by(target_letter, condition, measure_type) %>%
  summarise(
    n = n(),
    mean = mean(rating, na.rm = TRUE),
    se = sd(rating, na.rm = TRUE) / sqrt(sum(!is.na(rating))),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  )

# Significance tests
sig_tests_m_group <- m_group_comparison %>%
  group_by(target_letter, measure_type) %>%
  summarise(
    p_value = tryCatch(t.test(rating ~ condition)$p.value, error = function(e) NA),
    .groups = "drop"
  ) %>%
  mutate(
    stars = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ "ns"
    )
  )

# Plot
p_m_groups <- ggplot(m_group_comparison, aes(x = condition, y = rating, color = condition)) +
  geom_jitter(width = 0.15, alpha = 0.15, size = 1, shape = 16) +
  geom_pointrange(data = m_group_summary,
                  aes(y = mean, ymin = ci_lower, ymax = ci_upper),
                  size = 0.6, linewidth = 0.8, fatten = 3) +
  geom_segment(data = sig_tests_m_group,
               aes(x = 1, xend = 2, y = 95, yend = 95),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_m_group,
               aes(x = 1, xend = 1, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_m_group,
               aes(x = 2, xend = 2, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_text(data = sig_tests_m_group,
            aes(x = 1.5, y = 98, label = stars),
            color = "black", size = 4, family = "serif", inherit.aes = FALSE) +
  facet_grid(target_letter ~ measure_type) +
  scale_color_manual(values = c("NCK" = "gray60", "CK" = "#A23B72")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
  labs(
    title = "Moral Evaluations: Groups that Switched to M",
    subtitle = "CK: M-outcome groups only | NCK: all participants",
    x = NULL,
    y = "Rating (0–100)"
  ) +
  theme_classic(base_size = 14, base_family = "serif") +
  theme(
    plot.title = element_text(size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray40"),
    strip.text = element_text(size = 12),
    strip.background = element_blank(),
    legend.position = "none",
    axis.text.x = element_text(size = 12, color = "black"),
    axis.text.y = element_text(size = 12, color = "black"),
    axis.title.y = element_text(size = 12),
    panel.spacing = unit(1.5, "lines")
  )

print(p_m_groups)
ggsave("~/Documents/GitHub/Group_Name_Game/moral_evaluations_M_groups_vs_NCK.png",
       plot = p_m_groups, width = 10, height = 6, dpi = 300)

# ============================================================================
# N-GROUPS: Evaluations of N and J (NCK vs CK)
# ============================================================================

n_group_comparison <- bind_rows(
  moral_data %>%
    filter(treatment == "no_feedback") %>%
    mutate(condition = "NCK"),
  moral_data_with_outcome %>%
    filter(treatment == "feedback", group_outcome == "N") %>%
    mutate(condition = "CK")
) %>%
  select(participant_id, condition, 
         moral_j_then_n, punish_j_then_n, teammate_moral_j_then_n,
         moral_always_j, punish_always_j, teammate_moral_always_j) %>%
  mutate(
    blame_n = 100 - teammate_moral_j_then_n,
    blame_j = 100 - teammate_moral_always_j
  ) %>%
  pivot_longer(
    cols = c(moral_j_then_n, punish_j_then_n, blame_n,
             moral_always_j, punish_always_j, blame_j),
    names_to = "measure",
    values_to = "rating"
  ) %>%
  mutate(
    target_letter = case_when(
      grepl("_n$", measure) | grepl("j_then_n", measure) ~ "N",
      grepl("_j$", measure) | grepl("always_j", measure) ~ "J"
    ),
    measure_type = case_when(
      grepl("^moral", measure) ~ "Moral Appropriateness",
      grepl("^punish", measure) ~ "Intent to Punish",
      grepl("^blame", measure) ~ "Blameworthiness"
    ),
    measure_type = factor(measure_type, levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness")),
    condition = factor(condition, levels = c("NCK", "CK")),
    target_letter = factor(target_letter, levels = c("J", "N"))
  )

# Summary stats
n_group_summary <- n_group_comparison %>%
  group_by(target_letter, condition, measure_type) %>%
  summarise(
    n = n(),
    mean = mean(rating, na.rm = TRUE),
    se = sd(rating, na.rm = TRUE) / sqrt(sum(!is.na(rating))),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  )

# Significance tests
sig_tests_n_group <- n_group_comparison %>%
  group_by(target_letter, measure_type) %>%
  summarise(
    p_value = tryCatch(t.test(rating ~ condition)$p.value, error = function(e) NA),
    .groups = "drop"
  ) %>%
  mutate(
    stars = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ "ns"
    )
  )

# Plot
p_n_groups <- ggplot(n_group_comparison, aes(x = condition, y = rating, color = condition)) +
  geom_jitter(width = 0.15, alpha = 0.15, size = 1, shape = 16) +
  geom_pointrange(data = n_group_summary,
                  aes(y = mean, ymin = ci_lower, ymax = ci_upper),
                  size = 0.6, linewidth = 0.8, fatten = 3) +
  geom_segment(data = sig_tests_n_group,
               aes(x = 1, xend = 2, y = 95, yend = 95),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_n_group,
               aes(x = 1, xend = 1, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_n_group,
               aes(x = 2, xend = 2, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_text(data = sig_tests_n_group,
            aes(x = 1.5, y = 98, label = stars),
            color = "black", size = 4, family = "serif", inherit.aes = FALSE) +
  facet_grid(target_letter ~ measure_type) +
  scale_color_manual(values = c("NCK" = "gray60", "CK" = "#F18F01")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
  labs(
    title = "Moral Evaluations: Groups that Switched to N",
    subtitle = "CK: N-outcome groups only | NCK: all participants",
    x = NULL,
    y = "Rating (0–100)"
  ) +
  theme_classic(base_size = 14, base_family = "serif") +
  theme(
    plot.title = element_text(size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray40"),
    strip.text = element_text(size = 12),
    strip.background = element_blank(),
    legend.position = "none",
    axis.text.x = element_text(size = 12, color = "black"),
    axis.text.y = element_text(size = 12, color = "black"),
    axis.title.y = element_text(size = 12),
    panel.spacing = unit(1.5, "lines")
  )

print(p_n_groups)
ggsave("~/Documents/GitHub/Group_Name_Game/moral_evaluations_N_groups_vs_NCK.png",
       plot = p_n_groups, width = 10, height = 6, dpi = 300)

# Print significance tests
cat("\n=== M-GROUPS: Significance Tests ===\n")
print(sig_tests_m_group)
# ============================================================================
# M-GROUPS: Preregistered mixed-effects models
# ============================================================================

# Subset to NCK (all) and CK M-outcome groups
m_group_data <- bind_rows(
  moral_data %>%
    filter(treatment == "no_feedback") %>%
    mutate(condition = "NCK"),
  moral_data_with_outcome %>%
    filter(treatment == "feedback", group_outcome == "M") %>%
    mutate(condition = "CK")
) %>%
  mutate(
    condition = factor(condition, levels = c("NCK", "CK")),
    blame_m = 100 - teammate_moral_j_then_m,
    blame_j = 100 - teammate_moral_always_j
  )

cat("\n=== M-GROUPS: Preregistered Mixed-Effects Models ===\n")
cat("NCK: all participants | CK: M-outcome groups only\n\n")

# Moral appropriateness of J
cat("--- Moral Appropriateness of J ---\n")
m_group_moral_j <- lmer(moral_always_j ~ condition + (1 | group_id), data = m_group_data)
print(summary(m_group_moral_j))

# Punishment of J
cat("\n--- Punishment of J ---\n")
m_group_punish_j <- lmer(punish_always_j ~ condition + (1 | group_id), data = m_group_data)
print(summary(m_group_punish_j))

# Blameworthiness of J
cat("\n--- Blameworthiness of J ---\n")
m_group_blame_j <- lmer(blame_j ~ condition + (1 | group_id), data = m_group_data)
print(summary(m_group_blame_j))

# Moral appropriateness of M
cat("\n--- Moral Appropriateness of M ---\n")
m_group_moral_m <- lmer(moral_j_then_m ~ condition + (1 | group_id), data = m_group_data)
print(summary(m_group_moral_m))

# Punishment of M
cat("\n--- Punishment of M ---\n")
m_group_punish_m <- lmer(punish_j_then_m ~ condition + (1 | group_id), data = m_group_data)
print(summary(m_group_punish_m))

# Blameworthiness of M
cat("\n--- Blameworthiness of M ---\n")
m_group_blame_m <- lmer(blame_m ~ condition + (1 | group_id), data = m_group_data)
print(summary(m_group_blame_m))

# ============================================================================
# N-GROUPS: Preregistered mixed-effects models
# ============================================================================

n_group_data <- bind_rows(
  moral_data %>%
    filter(treatment == "no_feedback") %>%
    mutate(condition = "NCK"),
  moral_data_with_outcome %>%
    filter(treatment == "feedback", group_outcome == "N") %>%
    mutate(condition = "CK")
) %>%
  mutate(
    condition = factor(condition, levels = c("NCK", "CK")),
    blame_n = 100 - teammate_moral_j_then_n,
    blame_j = 100 - teammate_moral_always_j
  )

cat("\n\n=== N-GROUPS: Preregistered Mixed-Effects Models ===\n")
cat("NCK: all participants | CK: N-outcome groups only\n\n")

# Moral appropriateness of J
cat("--- Moral Appropriateness of J ---\n")
n_group_moral_j <- lmer(moral_always_j ~ condition + (1 | group_id), data = n_group_data)
print(summary(n_group_moral_j))

# Punishment of J
cat("\n--- Punishment of J ---\n")
n_group_punish_j <- lmer(punish_always_j ~ condition + (1 | group_id), data = n_group_data)
print(summary(n_group_punish_j))

# Blameworthiness of J
cat("\n--- Blameworthiness of J ---\n")
n_group_blame_j <- lmer(blame_j ~ condition + (1 | group_id), data = n_group_data)
print(summary(n_group_blame_j))

# Moral appropriateness of N
cat("\n--- Moral Appropriateness of N ---\n")
n_group_moral_n <- lmer(moral_j_then_n ~ condition, data = n_group_data)
print(summary(n_group_moral_n))

# Punishment of N
cat("\n--- Punishment of N ---\n")
n_group_punish_n <- lmer(punish_j_then_n ~ condition + (1|group_id), data = n_group_data)
print(summary(n_group_punish_n))

# Blameworthiness of N
cat("\n--- Blameworthiness of N ---\n")
n_group_blame_n <- lmer(blame_n ~ condition + (1 | group_id), data = n_group_data)
print(summary(n_group_blame_n))

# ============================================================================
# Extract p-values for visualization
# ============================================================================

# Function to extract p-value from lmer model
get_lmer_p <- function(model) {
  coefs <- summary(model)$coefficients
  if(nrow(coefs) >= 2) {
    return(coefs[2, "Pr(>|t|)"])
  } else {
    return(NA)
  }
}

sig_tests_m_group <- data.frame(
  target_letter = factor(c("J", "J", "J", "M", "M", "M"), levels = c("J", "M")),
  measure_type = factor(rep(c("Moral Appropriateness", "Intent to Punish", "Blameworthiness"), 2),
                        levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness")),
  p_value = c(
    get_lmer_p(m_group_moral_j),
    get_lmer_p(m_group_punish_j),
    get_lmer_p(m_group_blame_j),
    get_lmer_p(m_group_moral_m),
    get_lmer_p(m_group_punish_m),
    get_lmer_p(m_group_blame_m)
  )
) %>%
  mutate(
    stars = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ "ns"
    )
  )

sig_tests_n_group <- data.frame(
  target_letter = factor(c("J", "J", "J", "N", "N", "N"), levels = c("J", "N")),
  measure_type = factor(rep(c("Moral Appropriateness", "Intent to Punish", "Blameworthiness"), 2),
                        levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness")),
  p_value = c(
    get_lmer_p(n_group_moral_j),
    get_lmer_p(n_group_punish_j),
    get_lmer_p(n_group_blame_j),
    get_lmer_p(n_group_moral_n),
    get_lmer_p(n_group_punish_n),
    get_lmer_p(n_group_blame_n)
  )
) %>%
  mutate(
    stars = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ "ns"
    )
  )

cat("\n=== M-GROUPS: Summary of p-values (mixed-effects models) ===\n")
print(sig_tests_m_group)

cat("\n=== N-GROUPS: Summary of p-values (mixed-effects models) ===\n")
print(sig_tests_n_group)

# ============================================================================
# M-GROUPS VISUALIZATION (with preregistered model p-values)
# ============================================================================

m_group_plot_data <- m_group_data %>%
  select(participant_id, condition, 
         moral_j_then_m, punish_j_then_m, blame_m,
         moral_always_j, punish_always_j, blame_j) %>%
  pivot_longer(
    cols = c(moral_j_then_m, punish_j_then_m, blame_m,
             moral_always_j, punish_always_j, blame_j),
    names_to = "measure",
    values_to = "rating"
  ) %>%
  mutate(
    target_letter = case_when(
      measure %in% c("moral_j_then_m", "punish_j_then_m", "blame_m") ~ "M",
      measure %in% c("moral_always_j", "punish_always_j", "blame_j") ~ "J"
    ),
    measure_type = case_when(
      measure %in% c("moral_j_then_m", "moral_always_j") ~ "Moral Appropriateness",
      measure %in% c("punish_j_then_m", "punish_always_j") ~ "Intent to Punish",
      measure %in% c("blame_m", "blame_j") ~ "Blameworthiness"
    ),
    measure_type = factor(measure_type, levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness")),
    target_letter = factor(target_letter, levels = c("J", "M")),
    condition = factor(condition, levels = c("NCK", "CK"))
  )

m_group_summary <- m_group_plot_data %>%
  group_by(target_letter, condition, measure_type) %>%
  summarise(
    n = n(),
    mean = mean(rating, na.rm = TRUE),
    se = sd(rating, na.rm = TRUE) / sqrt(sum(!is.na(rating))),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  )

p_m_groups <- ggplot(m_group_plot_data, aes(x = condition, y = rating, color = condition)) +
  geom_jitter(width = 0.15, alpha = 0.15, size = 1, shape = 16) +
  geom_pointrange(data = m_group_summary,
                  aes(y = mean, ymin = ci_lower, ymax = ci_upper),
                  size = 0.6, linewidth = 0.8, fatten = 3) +
  geom_segment(data = sig_tests_m_group,
               aes(x = 1, xend = 2, y = 95, yend = 95),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_m_group,
               aes(x = 1, xend = 1, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_m_group,
               aes(x = 2, xend = 2, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_text(data = sig_tests_m_group,
            aes(x = 1.5, y = 98, label = stars),
            color = "black", size = 4, family = "serif", inherit.aes = FALSE) +
  facet_grid(target_letter ~ measure_type) +
  scale_color_manual(values = c("NCK" = "gray60", "CK" = "#A23B72")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
  labs(
    title = "Moral Evaluations: Groups that Switched to M",
    subtitle = "CK: M-outcome groups | NCK: all participants | Mixed-effects models",
    x = NULL,
    y = "Rating (0–100)"
  ) +
  theme_classic(base_size = 14, base_family = "serif") +
  theme(
    plot.title = element_text(size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray40"),
    strip.text = element_text(size = 12),
    strip.background = element_blank(),
    legend.position = "none",
    axis.text.x = element_text(size = 12, color = "black"),
    axis.text.y = element_text(size = 12, color = "black"),
    axis.title.y = element_text(size = 12),
    panel.spacing = unit(1.5, "lines")
  )

print(p_m_groups)


# ============================================================================
# N-GROUPS VISUALIZATION (with preregistered model p-values)
# ============================================================================

n_group_plot_data <- n_group_data %>%
  select(participant_id, condition, 
         moral_j_then_n, punish_j_then_n, blame_n,
         moral_always_j, punish_always_j, blame_j) %>%
  pivot_longer(
    cols = c(moral_j_then_n, punish_j_then_n, blame_n,
             moral_always_j, punish_always_j, blame_j),
    names_to = "measure",
    values_to = "rating"
  ) %>%
  mutate(
    target_letter = case_when(
      measure %in% c("moral_j_then_n", "punish_j_then_n", "blame_n") ~ "N",
      measure %in% c("moral_always_j", "punish_always_j", "blame_j") ~ "J"
    ),
    measure_type = case_when(
      measure %in% c("moral_j_then_n", "moral_always_j") ~ "Moral Appropriateness",
      measure %in% c("punish_j_then_n", "punish_always_j") ~ "Intent to Punish",
      measure %in% c("blame_n", "blame_j") ~ "Blameworthiness"
    ),
    measure_type = factor(measure_type, levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness")),
    target_letter = factor(target_letter, levels = c("J", "N")),
    condition = factor(condition, levels = c("NCK", "CK"))
  )

n_group_summary <- n_group_plot_data %>%
  group_by(target_letter, condition, measure_type) %>%
  summarise(
    n = n(),
    mean = mean(rating, na.rm = TRUE),
    se = sd(rating, na.rm = TRUE) / sqrt(sum(!is.na(rating))),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  )

p_n_groups <- ggplot(n_group_plot_data, aes(x = condition, y = rating, color = condition)) +
  geom_jitter(width = 0.15, alpha = 0.15, size = 1, shape = 16) +
  geom_pointrange(data = n_group_summary,
                  aes(y = mean, ymin = ci_lower, ymax = ci_upper),
                  size = 0.6, linewidth = 0.8, fatten = 3) +
  geom_segment(data = sig_tests_n_group,
               aes(x = 1, xend = 2, y = 95, yend = 95),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_n_group,
               aes(x = 1, xend = 1, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_n_group,
               aes(x = 2, xend = 2, y = 95, yend = 92),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_text(data = sig_tests_n_group,
            aes(x = 1.5, y = 98, label = stars),
            color = "black", size = 4, family = "serif", inherit.aes = FALSE) +
  facet_grid(target_letter ~ measure_type) +
  scale_color_manual(values = c("NCK" = "gray60", "CK" = "#F18F01")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 25)) +
  labs(
    title = "Moral Evaluations: Groups that Switched to N",
    subtitle = "CK: N-outcome groups | NCK: all participants | Mixed-effects models",
    x = NULL,
    y = "Rating (0–100)"
  ) +
  theme_classic(base_size = 14, base_family = "serif") +
  theme(
    plot.title = element_text(size = 14, hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray40"),
    strip.text = element_text(size = 12),
    strip.background = element_blank(),
    legend.position = "none",
    axis.text.x = element_text(size = 12, color = "black"),
    axis.text.y = element_text(size = 12, color = "black"),
    axis.title.y = element_text(size = 12),
    panel.spacing = unit(1.5, "lines")
  )

print(p_n_groups)
ggsave("~/Documents/GitHub/Group_Name_Game/moral_evaluations_N_groups_vs_NCK.png",
       plot = p_n_groups, width = 10, height = 6, dpi = 300)

### table ####

# Combine the summary stats and p-values for M-groups
m_table <- m_group_summary %>%
  pivot_wider(
    names_from = condition,
    values_from = c(n, mean, se, ci_lower, ci_upper),
    names_glue = "{condition}_{.value}"
  ) %>%
  left_join(sig_tests_m_group, by = c("target_letter", "measure_type")) %>%
  mutate(comparison = "M-groups vs NCK") %>%
  select(comparison, target_letter, measure_type, 
         NCK_n, NCK_mean, NCK_se, CK_n, CK_mean, CK_se, p_value, stars)

# Combine the summary stats and p-values for N-groups
n_table <- n_group_summary %>%
  pivot_wider(
    names_from = condition,
    values_from = c(n, mean, se, ci_lower, ci_upper),
    names_glue = "{condition}_{.value}"
  ) %>%
  left_join(sig_tests_n_group, by = c("target_letter", "measure_type")) %>%
  mutate(comparison = "N-groups vs NCK") %>%
  select(comparison, target_letter, measure_type, 
         NCK_n, NCK_mean, NCK_se, CK_n, CK_mean, CK_se, p_value, stars)

# Combine into one table
full_table <- bind_rows(m_table, n_table) %>%
  mutate(
    NCK_mean = round(NCK_mean, 2),
    NCK_se = round(NCK_se, 2),
    CK_mean = round(CK_mean, 2),
    CK_se = round(CK_se, 2),
    p_value = round(p_value, 3)
  )

print(full_table, n = Inf)

# For a cleaner formatted version:
full_table %>%
  mutate(
    NCK = paste0(NCK_mean, " (", NCK_se, ")"),
    CK = paste0(CK_mean, " (", CK_se, ")"),
    p = ifelse(p_value < 0.001, "< .001", as.character(p_value))
  ) %>%
  select(comparison, target_letter, measure_type, NCK, CK, p, stars)

library(gt)

# Create clean table
full_table %>%
  mutate(
    NCK = paste0(sprintf("%.2f", NCK_mean), " (", sprintf("%.2f", NCK_se), ")"),
    CK = paste0(sprintf("%.2f", CK_mean), " (", sprintf("%.2f", CK_se), ")"),
    p = case_when(
      p_value < 0.001 ~ "< .001",
      p_value < 0.01 ~ paste0(sprintf("%.3f", p_value)),
      TRUE ~ sprintf("%.3f", p_value)
    )
  ) %>%
  select(comparison, target_letter, measure_type, NCK, CK, p) %>%
  rename(
    `Comparison` = comparison,
    `Target` = target_letter,
    `Measure` = measure_type,
    `NCK M (SE)` = NCK,
    `CK M (SE)` = CK,
    `p` = p
  ) %>%
  gt(groupname_col = "Comparison") %>%
  tab_header(
    title = "Moral Evaluations for Switching versus Precedent",
    subtitle = "CK = Common Knowledge condition (outcome-specific groups); NCK = No Common Knowledge (all participants)"
  ) %>%
  tab_spanner(
    label = "Condition",
    columns = c(`NCK M (SE)`, `CK M (SE)`)
  ) %>%
  cols_align(align = "center", columns = c(`NCK M (SE)`, `CK M (SE)`, p)) %>%
  cols_align(align = "left", columns = c(Target, Measure)) %>%
  tab_footnote(
    footnote = "p-values from linear mixed-effects models with random intercept for group."
  ) %>%
  tab_options(
    table.font.size = 12,
    heading.title.font.size = 14,
    heading.subtitle.font.size = 11,
    row_group.font.weight = "bold"
  )

library(gt)

# Filter to just M and N targets, combine tables
bind_rows(
  m_table %>% filter(target_letter == "M"),
  n_table %>% filter(target_letter == "N")
) %>%
  mutate(
    NCK = paste0(sprintf("%.2f", NCK_mean), " (", sprintf("%.2f", NCK_se), ")"),
    CK = paste0(sprintf("%.2f", CK_mean), " (", sprintf("%.2f", CK_se), ")"),
    p = case_when(
      p_value < 0.001 ~ "< .001",
      p_value < 0.01 ~ sprintf("%.3f", p_value),
      TRUE ~ sprintf("%.3f", p_value)
    )
  ) %>%
  select(target_letter, measure_type, NCK, CK, p) %>%
  rename(
    `Target` = target_letter,
    `Measure` = measure_type,
    `NCK M (SE)` = NCK,
    `CK M (SE)` = CK,
    `p` = p
  ) %>%
  gt(groupname_col = "Target") %>%
  tab_header(
    title = "Moral Evaluations of Higher-Payoff Choices",
    subtitle = "CK: groups that successfully coordinated on that letter; NCK: all participants"
  ) %>%
  tab_spanner(
    label = "Condition",
    columns = c(`NCK M (SE)`, `CK M (SE)`)
  ) %>%
  cols_align(align = "center", columns = c(`NCK M (SE)`, `CK M (SE)`, p)) %>%
  cols_align(align = "left", columns = Measure) %>%
  tab_footnote(
    footnote = "p-values from linear mixed-effects models with random intercept for group."
  ) %>%
  tab_options(
    table.font.size = 12,
    heading.title.font.size = 14,
    heading.subtitle.font.size = 11,
    row_group.font.weight = "bold"
  )

group_outcomes %>%
  count(group_outcome)

# Or from the full data:
final_data %>%
  filter(treatment == "feedback", round == 14) %>%
  distinct(group_id, .keep_all = TRUE) %>%
  count(letter_choice)

# Within CK: Compare J-outcome vs M-outcome vs N-outcome groups
ck_data <- moral_data_with_outcome %>%
  filter(treatment == "feedback")

# How do M-switchers evaluate M vs how J-stayers evaluate M?
mod1 <- lmer(moral_j_then_m ~ group_outcome + (1|group_id), data = ck_data)
summary(mod1)

mod2 <- lmer(moral_j_then_n ~ group_outcome + (1|group_id), data = ck_data) %>% summary()
summary(mod2)

# Create combined dataset
# For each participant, use their evaluation of the letter their group chose (M or N)

# CK participants: use their group's outcome letter
ck_combined <- moral_data_with_outcome %>%
  filter(treatment == "feedback", group_outcome %in% c("M", "N")) %>%
  mutate(
    moral_higher_payoff = ifelse(group_outcome == "M", moral_j_then_m, moral_j_then_n),
    punish_higher_payoff = ifelse(group_outcome == "M", punish_j_then_m, punish_j_then_n),
    blame_higher_payoff = ifelse(group_outcome == "M", 100 - teammate_moral_j_then_m, 100 - teammate_moral_j_then_n),
    condition = "CK"
  )

# NCK participants: average of M and N evaluations (or pick one consistently)
nck_combined <- moral_data %>%
  filter(treatment == "no_feedback") %>%
  mutate(
    moral_higher_payoff = (moral_j_then_m + moral_j_then_n) / 2,
    punish_higher_payoff = (punish_j_then_m + punish_j_then_n) / 2,
    blame_higher_payoff = (100 - teammate_moral_j_then_m + 100 - teammate_moral_j_then_n) / 2,
    condition = "NCK"
  )

# Combine
combined_data <- bind_rows(
  ck_combined %>% select(participant_id, group_id, condition, moral_higher_payoff, punish_higher_payoff, blame_higher_payoff),
  nck_combined %>% select(participant_id, group_id, condition, moral_higher_payoff, punish_higher_payoff, blame_higher_payoff)
) %>%
  mutate(condition = factor(condition, levels = c("NCK", "CK")))

# Models
lmer(moral_higher_payoff ~ condition + (1|group_id), data = combined_data) %>% summary()
lm(punish_higher_payoff ~ condition, data = combined_data) %>% summary()
lmer(blame_higher_payoff ~ condition + (1|group_id), data = combined_data) %>% summary()

# Prepare data for visualization
combined_plot_data <- combined_data %>%
  pivot_longer(
    cols = c(moral_higher_payoff, punish_higher_payoff, blame_higher_payoff),
    names_to = "measure",
    values_to = "rating"
  ) %>%
  mutate(
    measure_label = case_when(
      measure == "moral_higher_payoff" ~ "Moral Appropriateness",
      measure == "punish_higher_payoff" ~ "Intent to Punish",
      measure == "blame_higher_payoff" ~ "Blameworthiness"
    ),
    measure_label = factor(measure_label, 
                           levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness"))
  )

# Summary statistics
combined_summary <- combined_plot_data %>%
  group_by(condition, measure_label) %>%
  summarise(
    n = n(),
    mean = mean(rating, na.rm = TRUE),
    se = sd(rating, na.rm = TRUE) / sqrt(sum(!is.na(rating))),
    ci_lower = mean - 1.96 * se,
    ci_upper = mean + 1.96 * se,
    .groups = "drop"
  )

# Significance tests (from your model outputs)
sig_tests_combined <- data.frame(
  measure_label = factor(c("Moral Appropriateness", "Intent to Punish", "Blameworthiness"),
                         levels = c("Moral Appropriateness", "Intent to Punish", "Blameworthiness")),
  p_value = c(0.000566, 0.0506, 2.41e-07),
  stars = c("***", "†", "***")
)

# Plot
p_combined <- ggplot(combined_plot_data, aes(x = condition, y = rating, color = condition)) +
  geom_jitter(width = 0.15, alpha = 0.2, size = 1.5, shape = 16) +
  geom_pointrange(data = combined_summary,
                  aes(y = mean, ymin = ci_lower, ymax = ci_upper),
                  size = 0.7, linewidth = 0.9, fatten = 3) +
  geom_segment(data = sig_tests_combined,
               aes(x = 1, xend = 2, y = 97, yend = 97),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_combined,
               aes(x = 1, xend = 1, y = 97, yend = 94),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_segment(data = sig_tests_combined,
               aes(x = 2, xend = 2, y = 97, yend = 94),
               color = "black", linewidth = 0.4, inherit.aes = FALSE) +
  geom_text(data = sig_tests_combined,
            aes(x = 1.5, y = 100, label = stars),
            color = "black", size = 5, family = "serif", inherit.aes = FALSE) +
  facet_wrap(~measure_label, ncol = 3) +
  scale_color_manual(values = c("NCK" = "gray50", "CK" = "black")) +
  scale_y_continuous(limits = c(0, 105), breaks = seq(0, 100, 25)) +
  labs(
    title = "Moral Evaluations of Higher-Payoff Choices",
    subtitle = "Common Knowledge (CK): groups that switched to M or N\nNo Common Knowledge (NCK): all participants",
    x = NULL,
    y = "Rating (0–100)",
    caption = "Error bars = 95% CI. *** p < .001, † p = .051"
  ) +
  theme_classic(base_size = 14, base_family = "serif") +
  theme(
    plot.title = element_text(size = 15, hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(size = 11, hjust = 0.5, color = "gray40"),
    plot.caption = element_text(size = 10, hjust = 0.5, color = "gray50"),
    strip.text = element_text(size = 12, face = "bold"),
    strip.background = element_blank(),
    legend.position = "none",
    axis.text = element_text(size = 12, color = "black"),
    axis.title.y = element_text(size = 12),
    panel.spacing = unit(1.5, "lines")
  )

print(p_combined)

ggsave("~/Documents/GitHub/Group_Name_Game/moral_evaluations_combined.png",
       plot = p_combined, width = 10, height = 5, dpi = 300)

# Compare models
library(lmerTest)

# With random intercept
m1 <- lmer(moral_higher_payoff ~ condition + (1|group_id), data = combined_data)

# Without
m0 <- lm(moral_higher_payoff ~ condition, data = combined_data)

# Check if random effect is needed
summary(m1)$varcor  # Is group variance meaningful?

# Compare results
summary(m0)

# Final models
moral_model <- lm(moral_higher_payoff ~ condition, data = combined_data)
punish_model <- lm(punish_higher_payoff ~ condition, data = combined_data)
blame_model <- lm(blame_higher_payoff ~ condition, data = combined_data)

summary(moral_model)
summary(punish_model)
summary(blame_model)
# =============================================================================
# IDENTIFY REPRESENTATIVE GROUPS (4 per condition)
# =============================================================================

library(tidyverse)

# -----------------------------------------------------------------------------
# Analyze CK (feedback) group outcomes
# -----------------------------------------------------------------------------

ck_group_outcomes <- final_data %>%
  filter(treatment == "feedback", round >= 8) %>%
  group_by(group_id) %>%
  summarise(
    n_total = n(),
    n_J = sum(letter_choice == "J"),
    n_M = sum(letter_choice == "M"),
    n_N = sum(letter_choice == "N"),
    prop_J = n_J / n_total,
    prop_M = n_M / n_total,
    prop_N = n_N / n_total,
    prop_switch = (n_M + n_N) / n_total,
    dominant = case_when(
      prop_M >= prop_N & prop_M >= prop_J ~ "M",
      prop_N > prop_M & prop_N >= prop_J ~ "N",
      TRUE ~ "J"
    ),
    .groups = "drop"
  ) %>%
  arrange(desc(prop_switch))

cat("\n=== CK (FEEDBACK) GROUP OUTCOMES ===\n")
print(ck_group_outcomes, n = 20)

# -----------------------------------------------------------------------------
# Analyze NCK (no_feedback) group outcomes  
# -----------------------------------------------------------------------------

nck_group_outcomes <- final_data %>%
  filter(treatment == "no_feedback", round >= 8) %>%
  group_by(group_id) %>%
  summarise(
    n_total = n(),
    n_J = sum(letter_choice == "J"),
    n_M = sum(letter_choice == "M"),
    n_N = sum(letter_choice == "N"),
    prop_J = n_J / n_total,
    prop_M = n_M / n_total,
    prop_N = n_N / n_total,
    prop_switch = (n_M + n_N) / n_total,
    dominant = case_when(
      prop_M >= prop_N & prop_M >= prop_J ~ "M",
      prop_N > prop_M & prop_N >= prop_J ~ "N",
      TRUE ~ "J"
    ),
    .groups = "drop"
  ) %>%
  arrange(desc(prop_J))  # Sort by how much they stayed on J

cat("\n=== NCK (NO FEEDBACK) GROUP OUTCOMES ===\n")
print(nck_group_outcomes, n = 20)

# -----------------------------------------------------------------------------
# Select 4 representative groups per condition
# -----------------------------------------------------------------------------

# CK: Select groups that show successful switching
ck_m_groups <- ck_group_outcomes %>% 
  filter(dominant == "M") %>% 
  arrange(desc(prop_M)) %>% 
  pull(group_id)

ck_n_groups <- ck_group_outcomes %>% 
  filter(dominant == "N") %>% 
  arrange(desc(prop_N)) %>% 
  pull(group_id)

# Choose 4 CK groups: mix of M and N switchers
selected_ck <- c(
  ck_m_groups[1:min(2, length(ck_m_groups))],
  ck_n_groups[1:min(2, length(ck_n_groups))]
)[1:4]

cat("\nSelected CK groups:", selected_ck, "\n")

# NCK: Select 4 groups with HIGHEST prop_J (mostly stayed on J)
selected_nck <- nck_group_outcomes %>%
  arrange(desc(prop_J)) %>%
  head(4) %>%
  pull(group_id)

cat("Selected NCK groups:", selected_nck, "\n")

# Show details
cat("\n=== SELECTED CK GROUP DETAILS ===\n")
print(ck_group_outcomes %>% filter(group_id %in% selected_ck))

cat("\n=== SELECTED NCK GROUP DETAILS ===\n")
print(nck_group_outcomes %>% filter(group_id %in% selected_nck))

# -----------------------------------------------------------------------------
# Create paper-ready heatmap: CK left, NCK right
# -----------------------------------------------------------------------------
# Create row indices (1-4) for alignment
ck_group_map <- tibble(
  group_id = selected_ck,
  row_num = 1:length(selected_ck)
)
nck_group_map <- tibble(
  group_id = selected_nck,
  row_num = 1:length(selected_nck)
)
# Prepare data with row alignment
heatmap_data <- bind_rows(
  final_data %>%
    filter(treatment == "feedback" & group_id %in% selected_ck) %>%
    left_join(ck_group_map, by = "group_id"),
  final_data %>%
    filter(treatment == "no_feedback" & group_id %in% selected_nck) %>%
    left_join(nck_group_map, by = "group_id")
) %>%
  group_by(treatment, group_id) %>%
  mutate(participant_num = dense_rank(participant_id)) %>%
  ungroup() %>%
  mutate(
    condition_label = factor(
      ifelse(treatment == "feedback", "Mutual Observability", "No Mutual Observability"),
      levels = c("Mutual Observability", "No Mutual Observability")  # MO first (left)
    ),
    row_label = paste0("Group ", row_num)
  )
# Color palette
letter_colors <- c(
  "J" = "#2E86AB",
  "M" = "#A23B72", 
  "N" = "#F18F01",
  "A" = "#d9d9d9", "B" = "#d9d9d9", "C" = "#d9d9d9", "D" = "#d9d9d9",
  "E" = "#d9d9d9", "F" = "#d9d9d9", "G" = "#d9d9d9", "H" = "#d9d9d9"
)
# Plot: conditions as columns, rows aligned
p_heatmap_paper <- ggplot(heatmap_data, 
                          aes(x = round, y = as.factor(participant_num), fill = letter_choice)) +
  geom_tile(color = "white", linewidth = 0.4) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "gray40", linewidth = 0.5) +
  facet_grid(row_label ~ condition_label, scales = "free_y") +
  scale_fill_manual(values = letter_colors, 
                    breaks = c("J", "M", "N"),
                    name = "Letter") +
  scale_x_continuous(breaks = c(1, 7, 14), expand = c(0.02, 0.02)) +
  scale_y_discrete(expand = c(0.02, 0.02)) +
  labs(
    x = "Round",
    y = NULL
  ) +
  theme_minimal(base_size = 11, base_family = "serif") +
  theme(
    strip.text.x = element_text(size = 11, face = "bold"),
    strip.text.y = element_text(size = 10),
    strip.background = element_blank(),
    axis.text.y = element_blank(),
    axis.ticks.y = element_blank(),
    axis.text.x = element_text(size = 10, color = "black"),
    axis.title = element_text(size = 11),
    panel.grid = element_blank(),
    panel.spacing.x = unit(1.2, "lines"),
    panel.spacing.y = unit(0.4, "lines"),
    legend.position = "bottom",
    legend.key.size = unit(0.5, "cm")
  ) +
  guides(fill = guide_legend(nrow = 1))
print(p_heatmap_paper)

ggsave("~/Documents/GitHub/Group_Name_Game/heatmap_paper_side_by_side.png",
       plot = p_heatmap_paper, width = 6.5, height = 6, dpi = 300)

cat("\nSaved: heatmap_paper_side_by_side.png\n")