# Name Game Incentivized - Data Analysis Script
# This script converts the wide-format oTree data to long format
# and extracts key variables for analysis

library(tidyverse)

# Read the data
data <- read_csv("~/Downloads/all_apps_wide-2025-11-12.csv")

# Extract participant-level variables (constant across rounds)
participant_info <- data %>%
  select(
    participant_id = `participant.code`,
    prolific_id = `participant.label`,
    consent = `Intro.1.player.consent`,
    attention_check_attempts = `Intro.1.player.attention_check_attempts`,
    attention_check_failed = `Intro.1.player.attention_check_failed`,
    # Post-survey questions
    following_rule = `End_name.1.player.following_rule`,
    what_rule = `End_name.1.player.what_rule`,
    rule_importance = `End_name.1.player.rule_importance`,
    same_rule_from_start = `End_name.1.player.same_rule_from_start`,
    num_rules_followed = `End_name.1.player.num_rules_followed`,
    rule_advice = `End_name.1.player.rule_advice`,
    feedback = `End_name.1.player.feedback`,
    gender = `End_name.1.player.gender`,
    age = `End_name.1.player.age`
  )

# Extract round-by-round data (long format)
# Create a list to store data from each round
round_data_list <- list()

for (round in 1:14) {
  # Build column names for this round
  col_condition <- paste0("name_game_incentivized.", round, ".player.condition")
  col_letter <- paste0("name_game_incentivized.", round, ".player.letter_choice")
  col_partner <- paste0("name_game_incentivized.", round, ".player.partner_id_in_group")
  col_round_points <- paste0("name_game_incentivized.", round, ".player.round_points")
  col_total_points <- paste0("name_game_incentivized.", round, ".player.total_points")
  col_group <- paste0("name_game_incentivized.", round, ".group.id_in_subsession")

  round_data <- data %>%
    select(
      participant_id = `participant.code`,
      condition = !!sym(col_condition),
      letter_choice = !!sym(col_letter),
      partner_id_in_group = !!sym(col_partner),
      round_points = !!sym(col_round_points),
      total_points = !!sym(col_total_points),
      group_id = !!sym(col_group)
    ) %>%
    mutate(round = round)

  round_data_list[[round]] <- round_data
}

# Combine all rounds
long_data <- bind_rows(round_data_list)

# Create coordination indicator
# For each participant-round, check if they coordinated (got points > 0)
long_data <- long_data %>%
  mutate(
    coordinated = round_points > 0,
    # Identify phase (rounds 1-7 vs 8-14)
    phase = ifelse(round <= 7, "early", "late")
  )

# Merge participant info with round data
final_data <- long_data %>%
  left_join(participant_info, by = "participant_id") %>%
  # Reorder columns for clarity
  select(
    participant_id,
    prolific_id,
    condition,
    round,
    phase,
    letter_choice,
    coordinated,
    round_points,
    total_points,
    partner_id_in_group,
    group_id,
    # Post-survey questions
    following_rule,
    what_rule,
    rule_importance,
    same_rule_from_start,
    num_rules_followed,
    rule_advice,
    feedback,
    gender,
    age,
    # Attention checks
    consent,
    attention_check_attempts,
    attention_check_failed
  )

# Check data before filtering
cat("\n=== PRE-FILTERING CHECK ===\n")
cat("Total participants in raw data:", n_distinct(long_data$participant_id), "\n")
cat("Participants with condition data:", sum(!is.na(long_data$condition) & long_data$condition != ""), "\n")
cat("Rows with condition:", sum(!is.na(long_data$condition) & long_data$condition != "", na.rm = TRUE), "\n\n")

# Remove rows where participant didn't start the game (no condition)
final_data <- final_data %>%
  filter(!is.na(condition) & condition != "")

# Save the long-format data
write_csv(final_data, "~/Documents/GitHub/Group_Name_Game/name_game_long.csv")

# Print summary statistics
cat("\n=== DATA SUMMARY ===\n\n")

cat("Total participants who played:", n_distinct(final_data$participant_id), "\n")
cat("Total observations (participant-rounds):", nrow(final_data), "\n\n")

cat("Participants by condition:\n")
print(table(unique(final_data[c("participant_id", "condition")])$condition))

cat("\n\nCoordination rates by condition and phase:\n")
coord_summary <- final_data %>%
  group_by(condition, phase) %>%
  summarise(
    n_rounds = n(),
    n_coordinated = sum(coordinated, na.rm = TRUE),
    coord_rate = mean(coordinated, na.rm = TRUE),
    mean_points = mean(round_points, na.rm = TRUE),
    .groups = "drop"
  )
print(coord_summary)

cat("\n\nLetter choices by condition and phase:\n")
letter_summary <- final_data %>%
  filter(!is.na(letter_choice) & letter_choice != "") %>%
  group_by(condition, phase, letter_choice) %>%
  summarise(
    count = n(),
    .groups = "drop"
  ) %>%
  arrange(condition, phase, desc(count))
print(letter_summary)

cat("\n\nTotal points earned by condition:\n")
points_summary <- final_data %>%
  filter(round == 14) %>%  # Final round total_points
  group_by(condition) %>%
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

cat("\n\n=== ANALYSIS COMPLETE ===\n")
cat("Long-format data saved to: ~/Documents/GitHub/Group_Name_Game/name_game_long.csv\n")

# =============================================================================
# VISUALIZATIONS
# =============================================================================

cat("\n\n=== CREATING VISUALIZATIONS ===\n")

# Check all letter choices in the data
cat("\nAll letter choices in dataset:\n")
print(table(final_ngi$letter_choice, useNA = "ifany"))

cat("\nLetter choices by round:\n")
print(table(final_ngi$round, final_ngi$letter_choice, useNA = "ifany"))

# Filter to only J, M, N choices for visualization
jmn_data <- final_ngi %>%
  filter(letter_choice %in% c("J", "M", "N"))

cat("\nRows after filtering to J, M, N:\n")
cat("Total rows:", nrow(jmn_data), "\n")
cat("Rounds represented:", paste(unique(jmn_data$round), collapse = ", "), "\n")

# 1. Letter choice proportions by round and condition
letter_proportions <- jmn_data %>%
  group_by(condition, round, letter_choice) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(condition, round) %>%
  mutate(proportion = count / sum(count))

# Plot 1: Letter choice proportions over time by condition
p1 <- ggplot(letter_proportions, aes(x = round, y = proportion, color = letter_choice)) +
  geom_line(aes(group = letter_choice), size = 1.2) +
  geom_point(size = 3) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = 7.5, y = 1, label = "M & N introduced",
           hjust = -0.1, vjust = 1, color = "red", size = 3.5) +
  facet_wrap(~condition, ncol = 1) +
  scale_color_manual(values = c("J" = "#2E86AB", "M" = "#A23B72", "N" = "#F18F01"),
                     name = "Letter") +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format()) +
  labs(
    title = "Letter Choice Proportions Across Rounds",
    subtitle = "Red line indicates introduction of M & N (15 points each)",
    x = "Round",
    y = "Proportion of Choices",
    caption = paste("Only J, M, and N choices shown | N =", n_distinct(final_ngi$participant_id), "participants")
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

# Plot 2: Raw counts of letter choices
letter_counts <- jmn_data %>%
  group_by(condition, round, letter_choice) %>%
  summarise(count = n(), .groups = "drop")

p2 <- ggplot(letter_counts, aes(x = round, y = count, color = letter_choice)) +
  geom_line(aes(group = letter_choice), size = 1.2) +
  geom_point(size = 3) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = 7.5, y = max(letter_counts$count), label = "M & N introduced",
           hjust = -0.1, vjust = 1, color = "red", size = 3.5) +
  facet_wrap(~condition, ncol = 1, scales = "free_y") +
  scale_color_manual(values = c("J" = "#2E86AB", "M" = "#A23B72", "N" = "#F18F01"),
                     name = "Letter") +
  scale_x_continuous(breaks = 1:14) +
  labs(
    title = "Letter Choice Counts Across Rounds",
    subtitle = "Red line indicates introduction of M & N (15 points each)",
    x = "Round",
    y = "Number of Participants",
    caption = paste("Only J, M, and N choices shown | N =", n_distinct(final_ngi$participant_id), "participants")
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

# Plot 3: Stacked area chart
p3 <- ggplot(letter_proportions, aes(x = round, y = proportion, fill = letter_choice)) +
  geom_area(alpha = 0.7, position = "stack") +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = 7.5, y = 1, label = "M & N introduced",
           hjust = -0.1, vjust = 1, color = "red", size = 3.5) +
  facet_wrap(~condition, ncol = 1) +
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

# Plot 4: Coordination rates over time
coord_by_round <- final_ngi %>%
  group_by(condition, round) %>%
  summarise(
    coord_rate = mean(coordinated, na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

p4 <- ggplot(coord_by_round, aes(x = round, y = coord_rate, color = condition)) +
  geom_line(aes(group = condition), size = 1.2) +
  geom_point(size = 3) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", size = 1) +
  annotate("text", x = 7.5, y = 1, label = "M & N introduced",
           hjust = -0.1, vjust = 1, color = "red", size = 3.5) +
  scale_color_manual(values = c("dyadic" = "#6A4C93", "group" = "#1982C4"),
                     name = "Condition") +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Coordination Rate Across Rounds by Condition",
    subtitle = "Red line indicates introduction of M & N (15 points each)",
    x = "Round",
    y = "Coordination Rate",
    caption = paste("N =", n_distinct(final_ngi$participant_id), "participants")
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  )

ggsave("~/Documents/GitHub/Group_Name_Game/coordination_rates.png",
       plot = p4, width = 10, height = 6, dpi = 300)
cat("Saved: coordination_rates.png\n")

cat("\n=== VISUALIZATION COMPLETE ===\n")
cat("All plots saved to: ~/Documents/GitHub/Group_Name_Game/\n")
