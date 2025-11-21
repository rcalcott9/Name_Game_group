# Name Game Incentivized - ngi Analysis Script
# This script converts the wide-format oTree ngi to long format
# and extracts key variables for analysis

library(tidyverse)

# Read the ngi
ngi <- read_csv("~/Downloads/name_game_incentivized.csv")

# Extract participant-level variables (constant across rounds)
participant_info <- ngi %>%
  dplyr::select(
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

# Extract round-by-round ngi (long format)
# Create a list to store ngi from each round
round_ngi_list <- list()

for (round in 1:14) {
  # Build column names for this round
  col_condition <- paste0("name_game_incentivized.", round, ".player.condition")
  col_letter <- paste0("name_game_incentivized.", round, ".player.letter_choice")
  col_partner <- paste0("name_game_incentivized.", round, ".player.partner_id_in_group")
  col_round_points <- paste0("name_game_incentivized.", round, ".player.round_points")
  col_total_points <- paste0("name_game_incentivized.", round, ".player.total_points")
  col_group <- paste0("name_game_incentivized.", round, ".group.id_in_subsession")

  round_ngi <- ngi %>%
    dplyr::select(
      participant_id = `participant.code`,
      condition = !!sym(col_condition),
      letter_choice = !!sym(col_letter),
      partner_id_in_group = !!sym(col_partner),
      round_points = !!sym(col_round_points),
      total_points = !!sym(col_total_points),
      group_id = !!sym(col_group)
    ) %>%
    mutate(round = round)

  round_ngi_list[[round]] <- round_ngi
}

# Combine all rounds
long_ngi <- bind_rows(round_ngi_list)

# Combine all rounds
long_ngi <- bind_rows(round_ngi_list)

# Fill in condition for each participant across all rounds
# Extract condition from round 1 for each participant
participant_conditions <- long_ngi %>%
  filter(round == 1) %>%
  dplyr::select(participant_id, condition) %>%
  filter(!is.na(condition) & condition != "")

# Join condition back to all rounds
long_ngi <- long_ngi %>%
  dplyr::select(-condition) %>%  # Remove the incomplete condition column
  left_join(participant_conditions, by = "participant_id")

# Create coordination indicator
# For each participant-round, check if they coordinated (got points > 0)
long_ngi <- long_ngi %>%
  mutate(
    coordinated = round_points > 0,
    # Identify phase (rounds 1-7 vs 8-14)
    phase = ifelse(round <= 7, "early", "late")
  )

# Create coordination indicator
# For each participant-round, check if they coordinated (got points > 0)
long_ngi <- long_ngi %>%
  mutate(
    coordinated = round_points > 0,
    # Identify phase (rounds 1-7 vs 8-14)
    phase = ifelse(round <= 7, "early", "late")
  )

# Merge participant info with round ngi
final_ngi <- long_ngi %>%
  left_join(participant_info, by = "participant_id") %>%
  # Reorder columns for clarity
  dplyr::select(
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

# Check ngi before filtering
cat("\n=== PRE-FILTERING CHECK ===\n")
cat("Total participants in raw ngi:", n_distinct(long_ngi$participant_id), "\n")
cat("Participants with condition ngi:", sum(!is.na(long_ngi$condition) & long_ngi$condition != ""), "\n")
cat("Rows with condition:", sum(!is.na(long_ngi$condition) & long_ngi$condition != "", na.rm = TRUE), "\n\n")

# Remove rows where participant didn't start the game (no condition)
final_ngi <- final_ngi %>%
  filter(!is.na(condition) & condition != "")

# Save the long-format ngi
write_csv(final_ngi, "~/Documents/GitHub/Group_Name_Game/name_game_long.csv")

# Print summary statistics
cat("\n=== ngi SUMMARY ===\n\n")

cat("Total participants who played:", n_distinct(final_ngi$participant_id), "\n")
cat("Total observations (participant-rounds):", nrow(final_ngi), "\n\n")

cat("Participants by condition:\n")
print(table(unique(final_ngi[c("participant_id", "condition")])$condition))

cat("\n\nCoordination rates by condition and phase:\n")
coord_summary <- final_ngi %>%
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
letter_summary <- final_ngi %>%
  filter(!is.na(letter_choice) & letter_choice != "") %>%
  group_by(condition, phase, letter_choice) %>%
  summarise(
    count = n(),
    .groups = "drop"
  ) %>%
  arrange(condition, phase, desc(count))
print(letter_summary)

cat("\n\nTotal points earned by condition:\n")
points_summary <- final_ngi %>%
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
cat("Long-format ngi saved to: ~/Documents/GitHub/Group_Name_Game/name_game_long.csv\n")

# ===========================
# VISUALIZATIONS
# ===========================

library(ggplot2)
long_ngi$condition

# 1. Proportion choosing J by condition across trials
# Calculate proportion choosing J
j_prop_data <- long_ngi %>%
  group_by(condition, round) %>%
  summarise(
    prop_j = mean(letter_choice == "J", na.rm = TRUE),
    n = n(),
    .groups = "drop"
  )

# Plot 1: Proportion choosing J by condition
plot1 <- ggplot(j_prop_data, aes(x = round, y = prop_j, color = condition, group = condition)) +
  geom_line(size = 1.2) +
  geom_point(size = 2) +
  geom_vline(xintercept = 7, linetype = "dashed", color = "black", size = 0.8) +
  annotate("text", x = 7, y = max(j_prop_data$prop_j) * 1.05, 
           label = "M & N points added", hjust = -0.1, size = 3.5) +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Proportion Choosing J by Condition Across Trials",
    x = "Trial",
    y = "Proportion Choosing J",
    color = "Condition"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom"
  )

print(plot1)
ggsave("~/Documents/GitHub/Group_Name_Game/plot1_prop_j_by_condition.png", 
       plot1, width = 10, height = 6, dpi = 300)


# 2. Proportion choosing J, M, N by condition across trials
letter_prop_data <- long_ngi %>%
  filter(!is.na(letter_choice) & letter_choice != "") %>%
  group_by(condition, round, letter_choice) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(condition, round) %>%
  mutate(
    total = sum(count),
    proportion = count / total
  ) %>%
  ungroup() %>%
  filter(letter_choice %in% c("J", "M", "N"))

# Plot 2: Stacked area or line plot for J, M, N
plot2 <- ggplot(letter_prop_data, aes(x = round, y = proportion, 
                                      color = letter_choice, 
                                      group = interaction(condition, letter_choice))) +
  geom_line(size = 1) +
  geom_point(size = 1.5) +
  geom_vline(xintercept = 7, linetype = "dashed", color = "gray30", size = 0.8) +
  facet_wrap(~condition, ncol = 1) +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1.1)) +
  scale_color_manual(values = c("J" = "#E41A1C", "M" = "#377EB8", "N" = "#4DAF4A")) +
  labs(
    title = "Proportion Choosing J, M, N by Condition Across Trials",
    x = "Trial",
    y = "Proportion",
    color = "Letter Choice"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom",
    strip.text = element_text(face = "bold")
  )

print(plot2)
ggsave("~/Documents/GitHub/Group_Name_Game/plot2_letter_choices_by_condition.png", 
       plot2, width = 10, height = 8, dpi = 300)


# 3. Proportion of successful coordination by condition across trials
coord_prop_data <- long_ngi %>%
  filter(!is.na(condition) & condition != "") %>%  # Remove NA conditions
  group_by(condition, round) %>%
  summarise(
    prop_coordinated = mean(coordinated, na.rm = TRUE),
    n = n(),
    se = sd(coordinated, na.rm = TRUE) / sqrt(n),
    .groups = "drop"
  )

# Plot 3: Coordination success rate
plot3 <- ggplot(coord_prop_data, aes(x = round, y = prop_coordinated, 
                                     color = condition, group = condition)) +
  geom_line(size = 1.2) +
  geom_point(size = 2) +
  geom_ribbon(aes(ymin = prop_coordinated - se, 
                  ymax = prop_coordinated + se,
                  fill = condition), 
              alpha = 0.2, color = NA) +
  geom_vline(xintercept = 7, linetype = "dashed", color = "black", size = 0.8) +
  annotate("text", x = 7, y = max(coord_prop_data$prop_coordinated) * 1.05, 
           label = "M & N points added", hjust = -0.1, size = 3.5) +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Proportion of Successful Coordination by Condition Across Trials",
    x = "Trial",
    y = "Coordination Success Rate",
    color = "Condition",
    fill = "Condition"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom"
  )

print(plot3)
ggsave("~/Documents/GitHub/Group_Name_Game/plot3_coordination_by_condition.png", 
       plot3, width = 10, height = 6, dpi = 300)

# 4. Points earned by condition across trials
points_by_trial <- long_ngi %>%
  filter(!is.na(condition) & condition != "") %>%
  group_by(condition, round) %>%
  summarise(
    mean_points = mean(round_points, na.rm = TRUE),
    se_points = sd(round_points, na.rm = TRUE) / sqrt(n()),
    n = n(),
    .groups = "drop"
  )

# Plot 4: Points earned by condition across trials
plot4 <- ggplot(points_by_trial, aes(x = round, y = mean_points, 
                                     color = condition, group = condition)) +
  geom_line(size = 1.2) +
  geom_point(size = 2) +
  geom_ribbon(aes(ymin = mean_points - se_points, 
                  ymax = mean_points + se_points,
                  fill = condition), 
              alpha = 0.2, color = NA) +
  geom_vline(xintercept = 7, linetype = "dashed", color = "black", size = 0.8) +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(limits = c(0, NA)) +
  labs(
    title = "Mean Points Earned by Condition Across Trials",
    x = "Trial",
    y = "Mean Points per Round",
    color = "Condition",
    fill = "Condition"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom"
  )

print(plot4)
ggsave("~/Documents/GitHub/Group_Name_Game/plot4_points_by_condition.png", 
       plot4, width = 10, height = 6, dpi = 300)

cat("Plot 4: Points earned by condition across trials\n")

cat("\n\n=== VISUALIZATIONS SAVED ===\n")
cat("Plot 1: Proportion choosing J by condition\n")
cat("Plot 2: Letter choices (J, M, N) by condition\n")
cat("Plot 3: Coordination success by condition\n")

# Switching behavior after trial 7
switching_analysis <- long_ngi %>%
  filter(round %in% c(7, 8)) %>%
  group_by(participant_id, condition) %>%
  summarise(
    choice_r7 = letter_choice[round == 7],
    choice_r8 = letter_choice[round == 8],
    switched = choice_r7 != choice_r8,
    .groups = "drop"
  )

# Switching rates by condition
switching_analysis %>%
  group_by(condition) %>%
  summarise(
    n = n(),
    switch_rate = mean(switched, na.rm = TRUE),
    switched_to_M = mean(choice_r8 == "M" & switched, na.rm = TRUE),
    switched_to_N = mean(choice_r8 == "N" & switched, na.rm = TRUE)
  )
# Coordination difficulty by group size
coordination_by_size <- long_ngi %>%
  group_by(condition, phase) %>%
  summarise(
    coord_rate = mean(coordinated, na.rm = TRUE),
    mean_points = mean(round_points, na.rm = TRUE),
    .groups = "drop"
  )

# Coordination difficulty by group size
coordination_by_size <- long_ngi %>%
  group_by(condition, phase) %>%
  summarise(
    coord_rate = mean(coordinated, na.rm = TRUE),
    mean_points = mean(round_points, na.rm = TRUE),
    .groups = "drop"
  )

ngi$End_name.1.player.following_rule
ngi$End_name.1.player.what_rule
ngi$End_name.1.player.rule_importance
ngi$End_name.1.player.same_rule_from_start
ngi$End_name.1.player.num_rules_followed
ngi$End_name.1.player.rule_advice

# Add participant info (including end questions) to long_ngi
long_ngi <- long_ngi %>%
  left_join(participant_info, by = "participant_id")

# ===========================
# END SURVEY VISUALIZATIONS
# ===========================

# Create participant-level data (one row per participant)
participant_data <- long_ngi %>%
  filter(round == 14, !is.na(condition) & condition != "") %>%
  dplyr::select(participant_id, condition, following_rule, num_rules_followed, 
         same_rule_from_start, total_points)

# Plot 5: Following Rule by Condition
plot5 <- participant_data %>%
  filter(!is.na(following_rule)) %>%
  ggplot(aes(x = condition, fill = factor(following_rule))) +
  geom_bar(position = "fill") +
  scale_y_continuous(labels = scales::percent_format()) +
  scale_fill_brewer(palette = "Set2", 
                    labels = c("No", "Yes"),
                    name = "Following a Rule?") +
  labs(
    title = "Proportion Following a Rule by Condition",
    x = "Condition",
    y = "Proportion"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom"
  )

print(plot5)
ggsave("~/Documents/GitHub/Group_Name_Game/plot5_following_rule_by_condition.png", 
       plot5, width = 8, height = 6, dpi = 300)

# Plot 6: Number of Rules Followed by Condition
plot6 <- participant_data %>%
  filter(!is.na(num_rules_followed)) %>%
  ggplot(aes(x = condition, y = num_rules_followed, fill = condition)) +
  geom_violin(alpha = 0.6) +
  geom_boxplot(width = 0.2, alpha = 0.8) +
  geom_jitter(width = 0.1, alpha = 0.3, size = 2) +
  labs(
    title = "Number of Rules Followed by Condition",
    x = "Condition",
    y = "Number of Rules Followed (0-2)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "none"
  )

print(plot6)
ggsave("~/Documents/GitHub/Group_Name_Game/plot6_num_rules_by_condition.png", 
       plot6, width = 8, height = 6, dpi = 300)

# Plot 7: Same Rule From Start by Condition (Histogram)
plot7 <- participant_data %>%
  filter(!is.na(same_rule_from_start)) %>%
  ggplot(aes(x = same_rule_from_start, fill = condition)) +
  geom_histogram(position = "dodge", binwidth = 1, color = "black", alpha = 0.7) +
  facet_wrap(~condition, ncol = 1) +
  scale_x_continuous(breaks = seq(min(participant_data$same_rule_from_start, na.rm = TRUE),
                                  max(participant_data$same_rule_from_start, na.rm = TRUE), 
                                  by = 1)) +
  labs(
    title = "Distribution of 'Same Rule From Start' Responses by Condition",
    x = "Same Rule From Start (Scale)",
    y = "Count",
    fill = "Condition"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom",
    strip.text = element_text(face = "bold")
  )

print(plot7)
ggsave("~/Documents/GitHub/Group_Name_Game/plot7_same_rule_from_start_by_condition.png", 
       plot7, width = 8, height = 8, dpi = 300)
ggsave("~/Documents/GitHub/Group_Name_Game/plot7_same_rule_from_start_by_condition.png", 
       plot7, width = 8, height = 6, dpi = 300)

# Summary statistics for these variables
cat("\n\n=== END SURVEY SUMMARY ===\n\n")

cat("Following Rule by Condition:\n")
following_summary <- participant_data %>%
  group_by(condition) %>%
  summarise(
    n = n(),
    prop_following = mean(following_rule, na.rm = TRUE),
    .groups = "drop"
  )
print(following_summary)

cat("\n\nNumber of Rules Followed by Condition:\n")
num_rules_summary <- participant_data %>%
  group_by(condition) %>%
  summarise(
    n = n(),
    mean_rules = mean(num_rules_followed, na.rm = TRUE),
    sd_rules = sd(num_rules_followed, na.rm = TRUE),
    median_rules = median(num_rules_followed, na.rm = TRUE),
    .groups = "drop"
  )
print(num_rules_summary)

cat("\n\nSame Rule From Start by Condition:\n")
same_rule_summary <- participant_data %>%
  group_by(condition) %>%
  summarise(
    n = n(),
    prop_same_rule = mean(same_rule_from_start, na.rm = TRUE),
    .groups = "drop"
  )
print(same_rule_summary)

cat("\n\n=== END SURVEY VISUALIZATIONS SAVED ===\n")
cat("Plot 5: Following rule by condition\n")
cat("Plot 6: Number of rules followed by condition\n")
cat("Plot 7: Same rule from start by condition\n")

# Load plotly
library(plotly)

# ===========================
# INTERACTIVE VISUALIZATIONS WITH HOVER TEXT
# ===========================

# First, let's create enhanced datasets with the text responses

# For plots that show participant-level data, add text responses
participant_data_with_text <- long_ngi %>%
  filter(round == 14, !is.na(condition) & condition != "") %>%
  select(participant_id, condition, following_rule, num_rules_followed, 
         same_rule_from_start, total_points, what_rule, rule_advice, feedback) %>%
  mutate(
    # Create hover text that combines all relevant info
    hover_text = paste0(
      "Participant: ", participant_id, "<br>",
      "Condition: ", condition, "<br>",
      "Total Points: ", total_points, "<br>",
      "Following Rule: ", ifelse(following_rule == 1, "Yes", "No"), "<br>",
      "Num Rules: ", num_rules_followed, "<br>",
      "Same Rule From Start: ", same_rule_from_start, "<br>",
      "<br><b>What Rule:</b><br>", ifelse(is.na(what_rule) | what_rule == "", "No response", what_rule), "<br>",
      "<br><b>Rule Advice:</b><br>", ifelse(is.na(rule_advice) | rule_advice == "", "No response", rule_advice), "<br>",
      "<br><b>Feedback:</b><br>", ifelse(is.na(feedback) | feedback == "", "No response", feedback)
    )
  )

# Interactive Plot 5: Following Rule by Condition
plot5_interactive <- participant_data_with_text %>%
  filter(!is.na(following_rule)) %>%
  ggplot(aes(x = condition, fill = factor(following_rule), 
             text = hover_text)) +
  geom_bar(position = "fill") +
  scale_y_continuous(labels = scales::percent_format()) +
  scale_fill_brewer(palette = "Set2", 
                    labels = c("No", "Yes"),
                    name = "Following a Rule?") +
  labs(
    title = "Proportion Following a Rule by Condition",
    x = "Condition",
    y = "Proportion"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom"
  )

ggplotly(plot5_interactive, tooltip = "text")

# Create dataset with only what_rule in hover text for Plot 6
participant_data_plot6 <- long_ngi %>%
  filter(round == 14, !is.na(condition) & condition != "") %>%
  select(participant_id, condition, num_rules_followed, what_rule, total_points) %>%
  mutate(
    # Create hover text with only what_rule
    hover_text = paste0(
      "Participant: ", participant_id, "<br>",
      "Condition: ", condition, "<br>",
      "Num Rules: ", num_rules_followed, "<br>",
      "Total Points: ", total_points, "<br>",
      "<br><b>What Rule:</b><br>", 
      ifelse(is.na(what_rule) | what_rule == "", "No response", what_rule)
    )
  )


# Save it
saveWidget(ggplotly(plot6_interactive, tooltip = "text"), 
           "~/Documents/GitHub/Group_Name_Game/plot6_interactive.html")

# Create dataset with only rule_advice in hover text for Plot 8
participant_data_plot8 <- long_ngi %>%
  filter(round == 14, !is.na(condition) & condition != "") %>%
  select(participant_id, condition, num_rules_followed, rule_advice, total_points) %>%
  mutate(
    # Create hover text with only rule_advice
    hover_text = paste0(
      "Participant: ", participant_id, "<br>",
      "Condition: ", condition, "<br>",
      "Num Rules: ", num_rules_followed, "<br>",
      "Total Points: ", total_points, "<br>",
      "<br><b>Rule Advice:</b><br>", 
      ifelse(is.na(rule_advice) | rule_advice == "", "No response", rule_advice)
    )
  )

# Interactive Plot 8: Number of Rules with Rule Advice Hover
plot8_interactive <- participant_data_plot8 %>%
  filter(!is.na(num_rules_followed)) %>%
  ggplot(aes(x = condition, y = num_rules_followed, fill = condition,
             text = hover_text)) +
  geom_jitter(width = 0.2, alpha = 0.6, size = 3) +
  labs(
    title = "Number of Rules Followed (Hover for Advice Given to New Players)",
    x = "Condition",
    y = "Number of Rules Followed (0-2)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 11),
    legend.position = "none"
  )

ggplotly(plot8_interactive, tooltip = "text")

long_ngi

# Create dataset with only rule_advice in hover text for Plot 9
participant_data_plot9 <- long_ngi %>%
  filter(round == 14, !is.na(condition) & condition != "") %>%
  select(participant_id, condition, num_rules_followed, what_rule, total_points) %>%
  mutate(
    # Create hover text with only rule_advice
    hover_text = paste0(
      "Participant: ", participant_id, "<br>",
      "Condition: ", condition, "<br>",
      "Num Rules: ", num_rules_followed, "<br>",
      "Total Points: ", total_points, "<br>",
      "<br><b>What Rule:</b><br>", 
      ifelse(is.na(what_rule) | what_rule == "", "No response", what_rule)
    )
  )

# Interactive Plot 8: Number of Rules with Rule Advice Hover
plot9_interactive <- participant_data_plot9 %>%
  filter(!is.na(num_rules_followed)) %>%
  ggplot(aes(x = condition, y = num_rules_followed, fill = condition,
             text = hover_text)) +
  geom_jitter(width = 0.2, alpha = 0.6, size = 3) +
  labs(
    title = "Number of Rules Followed (Hover for Rule Explanation)",
    x = "Condition",
    y = "Number of Rules Followed (0-2)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 11),
    legend.position = "none"
  )

ggplotly(plot9_interactive, tooltip = "text")

# Save it
saveWidget(ggplotly(plot8_interactive, tooltip = "text"), 
           "~/Documents/GitHub/Group_Name_Game/plot8_rule_advice_interactive.html")

cat("\n\nPlot 8: Number of rules with rule advice hover text saved\n")

# Interactive Plot 7: Same Rule From Start by Condition
plot7_interactive <- participant_data_with_text %>%
  filter(!is.na(same_rule_from_start)) %>%
  ggplot(aes(x = same_rule_from_start, fill = condition,
             text = hover_text)) +
  geom_histogram(position = "dodge", binwidth = 1, color = "black", alpha = 0.7) +
  facet_wrap(~condition, ncol = 1) +
  labs(
    title = "Distribution of 'Same Rule From Start' Responses by Condition",
    x = "Same Rule From Start (Scale)",
    y = "Count",
    fill = "Condition"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom",
    strip.text = element_text(face = "bold")
  )

ggplotly(plot7_interactive, tooltip = "text")

# For the time series plots, we can add hover information as well
# Interactive Plot 1: Proportion choosing J
j_prop_data_with_text <- long_ngi %>%
  filter(!is.na(condition) & condition != "") %>%
  left_join(
    participant_data_with_text %>% select(participant_id, what_rule, rule_advice),
    by = "participant_id"
  ) %>%
  group_by(condition, round) %>%
  mutate(
    hover_text_aggregate = paste0(
      "Condition: ", condition, "<br>",
      "Round: ", round, "<br>",
      "Proportion choosing J: ", round(mean(letter_choice == "J", na.rm = TRUE), 3)
    )
  ) %>%
  summarise(
    prop_j = mean(letter_choice == "J", na.rm = TRUE),
    n = n(),
    hover_text = first(hover_text_aggregate),
    .groups = "drop"
  )

plot1_interactive <- ggplot(j_prop_data_with_text, 
                            aes(x = round, y = prop_j, color = condition, 
                                group = condition, text = hover_text)) +
  geom_line(size = 1.2) +
  geom_point(size = 2) +
  geom_vline(xintercept = 7, linetype = "dashed", color = "black", size = 0.8) +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Proportion Choosing J by Condition Across Trials",
    x = "Trial",
    y = "Proportion Choosing J",
    color = "Condition"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom"
  )

ggplotly(plot1_interactive, tooltip = "text")

# Interactive Plot 4: Points by trial
points_with_hover <- long_ngi %>%
  filter(!is.na(condition) & condition != "") %>%
  group_by(condition, round) %>%
  summarise(
    mean_points = mean(round_points, na.rm = TRUE),
    se_points = sd(round_points, na.rm = TRUE) / sqrt(n()),
    n = n(),
    hover_text = paste0(
      "Condition: ", condition, "<br>",
      "Round: ", round, "<br>",
      "Mean Points: ", round(mean_points, 2), "<br>",
      "SE: ", round(se_points, 2), "<br>",
      "N: ", n
    ),
    .groups = "drop"
  )

plot4_interactive <- ggplot(points_with_hover, 
                            aes(x = round, y = mean_points, color = condition, 
                                group = condition, text = hover_text)) +
  geom_line(size = 1.2) +
  geom_point(size = 2) +
  geom_vline(xintercept = 7, linetype = "dashed", color = "black", size = 0.8) +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(limits = c(0, NA)) +
  labs(
    title = "Mean Points Earned by Condition Across Trials",
    x = "Trial",
    y = "Mean Points per Round",
    color = "Condition"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom"
  )

ggplotly(plot4_interactive, tooltip = "text")

# Create coordination plot data with hover text
coord_data_with_hover <- long_ngi %>%
  filter(!is.na(condition) & condition != "") %>%
  group_by(condition, round) %>%
  summarise(
    prop_coordinated = mean(coordinated, na.rm = TRUE),
    n = n(),
    se = sd(coordinated, na.rm = TRUE) / sqrt(n),
    hover_text = paste0(
      "Condition: ", condition, "<br>",
      "Round: ", round, "<br>",
      "Coordination Rate: ", round(prop_coordinated * 100, 1), "%<br>",
      "N: ", n
    ),
    .groups = "drop"
  )

# Interactive Plot 3: Coordination success rate
plot3_interactive <- ggplot(coord_data_with_hover, 
                            aes(x = round, y = prop_coordinated, 
                                color = condition, group = condition,
                                text = hover_text)) +
  geom_line(size = 1.2) +
  geom_point(size = 2) +
  geom_vline(xintercept = 7, linetype = "dashed", color = "black", size = 0.8) +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
  labs(
    title = "Proportion of Successful Coordination by Condition Across Trials",
    x = "Trial",
    y = "Coordination Success Rate",
    color = "Condition"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    legend.position = "bottom"
  )

ggplotly(plot3_interactive, tooltip = "text")

# Create the plotly object
p3 <- ggplotly(plot3_interactive, tooltip = "text")


# Create dataset with rule_importance
participant_data_plot10 <- long_ngi %>%
  filter(round == 14, !is.na(condition) & condition != "") %>%
  filter(!is.na(rule_importance)) %>%
  select(participant_id, condition, rule_importance, what_rule, rule_advice, total_points) %>%
  mutate(
    hover_text = paste0(
      "Participant: ", participant_id, "<br>",
      "Condition: ", condition, "<br>",
      "Rule Importance: ", rule_importance, "<br>",
      "Total Points: ", total_points, "<br>",
      "<br><b>What Rule:</b><br>", 
      ifelse(is.na(what_rule) | what_rule == "", "No response", what_rule), "<br>",
      "<br><b>Rule Advice:</b><br>", 
      ifelse(is.na(rule_advice) | rule_advice == "", "No response", rule_advice)
    )
  )

# Interactive Plot 10: Rule Importance by Condition (simplified for plotly)
plot10_interactive <- participant_data_plot10 %>%
  ggplot(aes(x = condition, y = rule_importance, color = condition,
             text = hover_text)) +
  geom_jitter(width = 0.2, alpha = 0.6, size = 3) +
  labs(
    title = "Importance of Following Rule by Condition (Hover for Details)",
    x = "Condition",
    y = "Rule Importance (Scale)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 11),
    legend.position = "none"
  )

# Create the plotly object
p10 <- ggplotly(plot10_interactive, tooltip = "text")



# Save interactive plots as HTML files
library(htmlwidgets)

saveWidget(ggplotly(plot5_interactive, tooltip = "text"), 
           "~/Documents/GitHub/Group_Name_Game/plot5_interactive.html")
saveWidget(ggplotly(plot6_interactive, tooltip = "text"), 
           "~/Documents/GitHub/Group_Name_Game/plot6_interactive.html")
saveWidget(ggplotly(plot7_interactive, tooltip = "text"), 
           "~/Documents/GitHub/Group_Name_Game/plot7_interactive.html")
saveWidget(ggplotly(plot1_interactive, tooltip = "text"), 
           "~/Documents/GitHub/Group_Name_Game/plot1_interactive.html")
saveWidget(ggplotly(plot4_interactive, tooltip = "text"), 
           "~/Documents/GitHub/Group_Name_Game/plot4_interactive.html")

cat("\n\n=== INTERACTIVE VISUALIZATIONS CREATED ===\n")
cat("Hover over data points to see participant responses!\n")
cat("HTML files saved for sharing\n")


# ===========================
# COMBINE ALL PLOTS INTO ONE HTML PAGE
# ===========================

library(htmlwidgets)
library(htmltools)



library(htmlwidgets)
library(htmltools)

# Recreate all the plotly objects (make sure these are defined)
p1 <- ggplotly(plot1_interactive, tooltip = "text")
p3 <- ggplotly(plot3_interactive, tooltip = "text")
p4 <- ggplotly(plot4_interactive, tooltip = "text")
p5 <- ggplotly(plot5_interactive, tooltip = "text")
p6 <- ggplotly(plot6_interactive, tooltip = "text")
p7 <- ggplotly(plot7_interactive, tooltip = "text")
p8 <- ggplotly(plot8_interactive, tooltip = "text")
p9 <- ggplotly(plot9_interactive, tooltip = "text")
p10 <- ggplotly(plot10_interactive, tooltip = "text")

# Create combined page using browsable for better self-containment
combined_page <- browsable(
  tagList(
    tags$h1("Name Game Incentivized - Interactive Analysis Dashboard", 
            style = "text-align: center; font-family: Arial, sans-serif; color: #333; margin: 20px;"),
    tags$hr(),
    
    tags$h2("1. Proportion Choosing J by Condition Across Trials", 
            style = "font-family: Arial, sans-serif; color: #555; margin: 20px;"),
    p1,
    tags$hr(),
    
    tags$h2("3. Proportion of Successful Coordination by Condition Across Trials", 
            style = "font-family: Arial, sans-serif; color: #555; margin: 20px;"),
    p3,
    tags$hr(),
    
    tags$h2("4. Mean Points Earned by Condition Across Trials", 
            style = "font-family: Arial, sans-serif; color: #555; margin: 20px;"),
    p4,
    tags$hr(),
    
    tags$h2("5. Proportion Following a Rule by Condition", 
            style = "font-family: Arial, sans-serif; color: #555; margin: 20px;"),
    p5,
    tags$hr(),
    
    tags$h2("7. Distribution of 'Same Rule From Start' Responses", 
            style = "font-family: Arial, sans-serif; color: #555; margin: 20px;"),
    p7,
    tags$hr(),
    
    tags$h2("8. Number of Rules Followed (Hover for Advice to New Players)", 
            style = "font-family: Arial, sans-serif; color: #555; margin: 20px;"),
    p8,
    tags$hr(),
    
    tags$h2("9. Number of Rules Followed (Hover for Rule Explanation)", 
            style = "font-family: Arial, sans-serif; color: #555; margin: 20px;"),
    p9,
    tags$hr(),
    
    tags$h2("10. Importance of Following Rule by Condition", 
            style = "font-family: Arial, sans-serif; color: #555; margin: 20px;"),
    p10
  )
)

# Save with selfcontained explicitly TRUE
saveWidget(
  combined_page,
  file = "~/Documents/GitHub/Group_Name_Game/all_plots_interactive.html",
  selfcontained = TRUE,
  libdir = NULL
)

cat("\n\n=== FIXED INTERACTIVE DASHBOARD CREATED ===\n")
cat("File saved. Now push to GitHub:\n")
cat("cd ~/Documents/GitHub/Group_Name_Game\n")
cat("git add all_plots_interactive.html\n")
cat("git commit -m 'Fix interactive dashboard with embedded dependencies'\n")
cat("git push origin main\n")

# ===========================
# IDENTIFY PAIRS/GROUPS
# ===========================

# ===========================
# IDENTIFY PAIRS/GROUPS BY CONDITION
# ===========================

# Dyadic condition: pairs of 2
# Group condition: groups of 6

# First, let's check the group_id variable - it might already tell us groupings
group_id_check <- long_ngi %>%
  filter(!is.na(condition) & condition != "", round == 1) %>%
  group_by(condition, group_id) %>%
  summarise(
    n_participants = n(),
    participants = paste(participant_id, collapse = ", "),
    .groups = "drop"
  ) %>%
  arrange(condition, group_id)

cat("\n=== GROUP_ID ANALYSIS ===\n")
print(group_id_check)

# If group_id already identifies groups correctly, use it directly
# Otherwise, we'll use the signature matching approach with size constraints

# Method 1: Use group_id if available
if(all(!is.na(long_ngi$group_id))) {
  
  long_ngi <- long_ngi %>%
    mutate(matched_group_id = paste(condition, group_id, sep = "_"))
  
  cat("\nUsing group_id to identify groups\n")
  
} else {
  
  # Method 2: Signature matching with size constraints
  cat("\nUsing signature matching with size constraints\n")
  
  # Create signatures for each participant
  participant_signatures <- long_ngi %>%
    filter(!is.na(condition) & condition != "") %>%
    arrange(participant_id, round) %>%
    group_by(participant_id, condition) %>%
    summarise(
      # Create comprehensive signature
      letter_signature = paste(letter_choice, collapse = "|"),
      coord_signature = paste(as.integer(coordinated), collapse = "|"),
      points_signature = paste(round_points, collapse = "|"),
      .groups = "drop"
    )
  
  # For dyadic condition: find pairs (groups of 2)
  dyadic_groups <- participant_signatures %>%
    filter(condition == "dyadic") %>%
    group_by(letter_signature, coord_signature, points_signature) %>%
    filter(n() == 2) %>%  # Must be exactly 2 participants
    mutate(matched_group_id = paste0("dyadic_", cur_group_id())) %>%
    ungroup()
  
  # For group condition: find groups (groups of 6)
  group_groups <- participant_signatures %>%
    filter(condition == "group") %>%
    group_by(letter_signature, coord_signature, points_signature) %>%
    filter(n() == 6) %>%  # Must be exactly 6 participants
    mutate(matched_group_id = paste0("group_", cur_group_id())) %>%
    ungroup()
  
  # Combine the matches
  all_matched <- bind_rows(dyadic_groups, group_groups) %>%
    select(participant_id, matched_group_id)
  
  # Add back to long_ngi
  long_ngi <- long_ngi %>%
    left_join(all_matched, by = "participant_id")
}

# Calculate group size
long_ngi <- long_ngi %>%
  group_by(matched_group_id) %>%
  mutate(group_size = n_distinct(participant_id)) %>%
  ungroup()

# Summary of identified groups
group_summary <- long_ngi %>%
  filter(!is.na(matched_group_id), round == 1) %>%
  group_by(matched_group_id, condition) %>%
  summarise(
    n_participants = n(),
    participants = paste(participant_id, collapse = ", "),
    .groups = "drop"
  ) %>%
  arrange(condition, matched_group_id)

cat("\n=== IDENTIFIED GROUPS/PAIRS ===\n\n")
print(group_summary, n = 100)

cat("\n=== SUMMARY STATISTICS ===\n")
cat("Total participants:", n_distinct(long_ngi$participant_id[!is.na(long_ngi$condition) & long_ngi$condition != ""]), "\n")
cat("Participants in identified groups:", n_distinct(long_ngi$participant_id[!is.na(long_ngi$matched_group_id)]), "\n")
cat("Number of dyadic pairs:", sum(group_summary$condition == "dyadic" & group_summary$n_participants == 2), "\n")
cat("Number of 6-person groups:", sum(group_summary$condition == "group" & group_summary$n_participants == 6), "\n")

# Check for any unmatched participants
unmatched <- long_ngi %>%
  filter(!is.na(condition) & condition != "", is.na(matched_group_id), round == 1) %>%
  select(participant_id, condition)

if(nrow(unmatched) > 0) {
  cat("\n=== UNMATCHED PARTICIPANTS ===\n")
  print(unmatched)
  cat("\nThese participants may have dropped out or had unique response patterns\n")
}

# Save updated data
write_csv(long_ngi, "~/Documents/GitHub/Group_Name_Game/name_game_long_with_groups.csv")

cat("\n=== DATA SAVED ===\n")
cat("File: name_game_long_with_groups.csv\n")

# ===========================
# RECREATE group_data_all FROM SCRATCH
# ===========================

group_data_all <- long_ngi %>%
  filter(condition == "group", !is.na(matched_group_id)) %>%
  arrange(matched_group_id, participant_id, round) %>%
  group_by(matched_group_id) %>%
  mutate(
    group_position = factor(6 - (row_number() - 1) %% 6, levels = 1:6, labels = paste("Member", 1:6))
  ) %>%
  ungroup()

# Check the data
cat("\n=== GROUP_DATA_ALL SUMMARY ===\n")
cat("Total rows:", nrow(group_data_all), "\n")
cat("Expected (7 groups × 6 members × 14 rounds):", 7 * 6 * 14, "\n")
cat("Unique participants:", n_distinct(group_data_all$participant_id), "\n")
cat("Unique groups:", n_distinct(group_data_all$matched_group_id), "\n")

# Check completeness by group
cat("\n=== ROWS PER GROUP ===\n")
group_data_all %>%
  group_by(matched_group_id) %>%
  summarise(n_rows = n(), .groups = "drop") %>%
  print()

# Create the plot with fixed visualization
all_letter_colors <- c(
  "J" = "#E41A1C",   # Red
  "M" = "#377EB8",   # Blue
  "N" = "#4DAF4A",   # Green
  "Q" = "#FF7F00",   # Orange
  "X" = "#999999",   # Gray
  "R" = "#984EA3",   # Purple
  "C" = "#FFFF33",   # Yellow
  "F" = "#A65628"    # Brown
)


# ===========================
# APPLY SAME VISUALIZATION TO ALL GROUPS
# ===========================

# Get all group data
all_groups_data <- long_ngi %>%
  filter(condition == "group", !is.na(matched_group_id)) %>%
  arrange(matched_group_id, participant_id, round) %>%
  select(matched_group_id, participant_id, round, letter_choice, coordinated, round_points)

cat("\n=== ALL GROUPS DATA ===\n")
cat("Total rows:", nrow(all_groups_data), "\n")
cat("Expected rows (7 groups × 6 participants × 14 rounds):", 7 * 6 * 14, "\n")
cat("Number of groups:", n_distinct(all_groups_data$matched_group_id), "\n\n")

# Create the same plot for all groups
plot_all_groups <- all_groups_data %>%
  ggplot(aes(x = factor(round), y = participant_id, fill = letter_choice)) +
  geom_tile(color = "black", linewidth = 0.5) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", linewidth = 1) +
  facet_wrap(~matched_group_id, ncol = 2, scales = "free_y") +
  scale_fill_manual(
    values = all_letter_colors,
    na.value = "pink"
  ) +
  labs(
    title = "Letter choices in group condition ",
    subtitle = "Each panel shows one 6-person group. Dashed line = M & N introduced",
    x = "Trial",
    y = "Participant ID",
    fill = "Letter"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
    plot.subtitle = element_text(hjust = 0.5, size = 11),
    strip.text = element_text(face = "bold", size = 11),
    axis.text.x = element_text(size = 8),
    axis.text.y = element_text(size = 7),
    panel.spacing = unit(1, "lines"),
    legend.position = "bottom",
    legend.title = element_text(face = "bold")
  )

print(plot_all_groups)
ggsave("~/Documents/GitHub/Group_Name_Game/plot_all_groups_complete.png", 
       plot_all_groups, width = 14, height = 16, dpi = 300)

cat("\n=== ALL GROUPS PLOT SAVED ===\n")

# ===========================
# DYADIC CONDITION - SAME VISUALIZATION
# ===========================

# Get all dyadic data
all_dyadic_data <- long_ngi %>%
  filter(condition == "dyadic", !is.na(matched_group_id)) %>%
  arrange(matched_group_id, participant_id, round) %>%
  select(matched_group_id, participant_id, round, letter_choice, coordinated, round_points)

cat("\n=== ALL DYADIC DATA ===\n")
cat("Total rows:", nrow(all_dyadic_data), "\n")
cat("Number of pairs:", n_distinct(all_dyadic_data$matched_group_id), "\n")
cat("Total participants:", n_distinct(all_dyadic_data$participant_id), "\n\n")

# Create the same plot for all dyadic pairs
plot_all_dyadic <- all_dyadic_data %>%
  ggplot(aes(x = factor(round), y = participant_id, fill = letter_choice)) +
  geom_tile(color = "black", linewidth = 0.5) +
  geom_vline(xintercept = 7.5, linetype = "dashed", color = "red", linewidth = 1) +
  facet_wrap(~matched_group_id, ncol = 4, scales = "free_y") +
  scale_fill_manual(
    values = all_letter_colors,
    na.value = "pink"
  ) +
  labs(
    title = "Letter choices in dyadic condition",
    subtitle = "Each panel shows one pair. Dashed line = M & N introduced",
    x = "Trial",
    y = "Participant ID",
    fill = "Letter"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 16),
    plot.subtitle = element_text(hjust = 0.5, size = 11),
    strip.text = element_text(face = "bold", size = 9),
    axis.text.x = element_text(size = 8),
    axis.text.y = element_text(size = 6),
    panel.spacing = unit(0.5, "lines"),
    legend.position = "bottom",
    legend.title = element_text(face = "bold")
  )

print(plot_all_dyadic)
ggsave("~/Documents/GitHub/Group_Name_Game/plot_all_dyadic_complete.png", 
       plot_all_dyadic, width = 16, height = 12, dpi = 300)

cat("\n=== ALL DYADIC PAIRS PLOT SAVED ===\n")

# ===========================
# ADD NEW VISUALIZATIONS TO HTML DASHBOARD
# ===========================

library(htmlwidgets)
library(htmltools)
library(plotly)

# Create interactive versions of the new plots
# These plots are not interactive by nature (heatmaps), so we'll include them as static images

# Recreate all existing plotly objects
p1 <- ggplotly(plot1_interactive, tooltip = "text")
p3 <- ggplotly(plot3_interactive, tooltip = "text")
p4 <- ggplotly(plot4_interactive, tooltip = "text")
p5 <- ggplotly(plot5_interactive, tooltip = "text")
p6 <- ggplotly(plot6_interactive, tooltip = "text")
p7 <- ggplotly(plot7_interactive, tooltip = "text")
p8 <- ggplotly(plot8_interactive, tooltip = "text")
p9 <- ggplotly(plot9_interactive, tooltip = "text")
p10 <- ggplotly(plot10_interactive, tooltip = "text")

# ===========================
# FIX: EMBED IMAGES AS BASE64 IN HTML
# ===========================

library(htmlwidgets)
library(htmltools)
library(plotly)
library(base64enc)

# Recreate all existing plotly objects
p1 <- ggplotly(plot1_interactive, tooltip = "text")
p3 <- ggplotly(plot3_interactive, tooltip = "text")
p4 <- ggplotly(plot4_interactive, tooltip = "text")
p5 <- ggplotly(plot5_interactive, tooltip = "text")
p6 <- ggplotly(plot6_interactive, tooltip = "text")
p7 <- ggplotly(plot7_interactive, tooltip = "text")
p8 <- ggplotly(plot8_interactive, tooltip = "text")
p9 <- ggplotly(plot9_interactive, tooltip = "text")
p10 <- ggplotly(plot10_interactive, tooltip = "text")

# Convert PNG images to base64 for embedding
group_plot_base64 <- base64encode("~/Documents/GitHub/Group_Name_Game/plot_all_groups_complete.png")
dyadic_plot_base64 <- base64encode("~/Documents/GitHub/Group_Name_Game/plot_all_dyadic_complete.png")

# Create combined page with embedded images
combined_page <- tags$html(
  tags$head(
    tags$title("Name Game Interactive Dashboard"),
    tags$style(HTML("
      body { font-family: Arial, sans-serif; margin: 20px; }
      h1 { text-align: center; color: #333; }
      h2 { color: #555; margin-top: 40px; }
      hr { margin: 30px 0; }
      .static-plot { text-align: center; margin: 20px 0; }
      .static-plot img { max-width: 100%; height: auto; border: 1px solid #ddd; }
    "))
  ),
  tags$body(
    tags$h1("Name Game Incentivized - Interactive Analysis Dashboard"),
    tags$hr(),
    
    tags$h2("1. Proportion Choosing J by Condition Across Trials"),
    p1,
    tags$hr(),
    
    tags$h2("3. Proportion of Successful Coordination by Condition Across Trials"),
    p3,
    tags$hr(),
    
    tags$h2("4. Mean Points Earned by Condition Across Trials"),
    p4,
    tags$hr(),
    
    tags$h2("5. Proportion Following a Rule by Condition"),
    p5,
    tags$hr(),
    
    tags$h2("7. Distribution of 'Same Rule From Start' Responses"),
    p7,
    tags$hr(),
    
    tags$h2("8. Number of Rules Followed (Hover for Advice to New Players)"),
    p8,
    tags$hr(),
    
    tags$h2("9. Number of Rules Followed (Hover for Rule Explanation)"),
    p9,
    tags$hr(),
    
    tags$h2("10. Importance of Following Rule by Condition"),
    p10,
    tags$hr(),
    
    tags$h2("11. Letter Choices by Group (6-person groups)"),
    tags$div(
      class = "static-plot",
      tags$img(src = paste0("data:image/png;base64,", group_plot_base64), 
               alt = "Group condition letter choices heatmap")
    ),
    tags$hr(),
    
    tags$h2("12. Letter Choices by Pair (Dyadic condition)"),
    tags$div(
      class = "static-plot",
      tags$img(src = paste0("data:image/png;base64,", dyadic_plot_base64), 
               alt = "Dyadic condition letter choices heatmap")
    ),
    
    tags$footer(
      tags$p(paste("Generated:", Sys.time()), 
             style = "text-align: center; color: #999; font-size: 12px; margin-top: 50px;")
    )
  )
)

# Save the updated combined page
save_html(combined_page, 
          file = "~/Documents/GitHub/Group_Name_Game/all_plots_interactive.html")

cat("\n\n=== UPDATED INTERACTIVE DASHBOARD WITH EMBEDDED IMAGES ===\n")
cat("Images are now embedded as base64 - no need to commit PNG files separately!\n")
cat("File: ~/Documents/GitHub/Group_Name_Game/all_plots_interactive.html\n")
cat("\nNow push to GitHub:\n")
cat("cd ~/Documents/GitHub/Group_Name_Game\n")
cat("git add all_plots_interactive.html\n")
cat("git commit -m 'Embed images as base64 in dashboard'\n")
cat("git push origin main\n")

