# ============================================================
# Fixed-Calibration Hybrid Bayesian Precedent/Switch
# + Coordination-Support Model
# ============================================================
#
# Latest preferred model:
#
#   Q_t(a) = V_t(a) * S_t(a) * q_t(a)^5
#
# Choice rule:
#
#   P(c_t = a) =
#     (1 - epsilon) * softmax_a[tau * Q_t(a)]
#     + epsilon * V_t(a) / sum_b V_t(b)
#
# Fixed calibration parameters:
#
#   epsilon = 0.04
#   tau     = 90
#   theta   = 0.52
#   priorW  = 0.69
#
# Only estimated parameter:
#
#   alpha = implementation-support smoothing
#
# Interpretation:
#   alpha controls how cautiously participants update q(a),
#   their belief that others will choose option a.
# ============================================================

library(tidyverse)
library(ggplot2)

# -----------------------------
# 0. Settings
# -----------------------------

wide_path <- "~/Downloads/all_apps_wide-2026-01-12-6.csv"

out_dir <- "fixed_hybrid_outputs"

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}

# Fixed parameters from sensitivity / reduction analyses
fixed_epsilon <- 0.04
fixed_tau     <- 90
fixed_theta   <- 0.52
fixed_priorW  <- 0.69

# -----------------------------
# 1. Load and reshape data
# -----------------------------

data <- read_csv(wide_path, show_col_types = FALSE)

round_data_list <- list()

for (round in 1:14) {
  
  for (app in c("name_game", "name_game_no_feedback")) {
    
    col_letter <- paste0(app, ".", round, ".player.letter_choice")
    col_group  <- paste0(app, ".", round, ".group.id_in_subsession")
    col_id     <- paste0(app, ".", round, ".player.id_in_group")
    
    if (!col_letter %in% names(data)) next
    
    tmp <- data %>%
      transmute(
        participant_id = `participant.code`,
        treatment = as.character(`consent.1.player.treatment`),
        app = app,
        round = round,
        letter_choice = .data[[col_letter]],
        group_id_raw = .data[[col_group]],
        id_in_group = if (col_id %in% names(data)) .data[[col_id]] else NA
      ) %>%
      filter(!is.na(letter_choice), letter_choice != "")
    
    round_data_list[[length(round_data_list) + 1]] <- tmp
  }
}

long_data <- bind_rows(round_data_list) %>%
  mutate(
    treatment = as.character(treatment),
    letter_choice = str_trim(as.character(letter_choice)),
    
    # Safer than treatment + group_id alone because it prevents app collisions.
    group_uid = paste(treatment, app, group_id_raw, sep = "_")
  )

complete_ids <- long_data %>%
  group_by(participant_id) %>%
  summarise(n_rounds = n_distinct(round), .groups = "drop") %>%
  filter(n_rounds == 14) %>%
  pull(participant_id)

model_data <- long_data %>%
  filter(participant_id %in% complete_ids) %>%
  filter(letter_choice %in% c("J", "M", "N")) %>%
  mutate(
    choice_idx = case_when(
      letter_choice == "J" ~ 1L,
      letter_choice == "M" ~ 2L,
      letter_choice == "N" ~ 3L
    ),
    switched = as.integer(letter_choice != "J")
  )

cat("\nData used for model fitting:\n")
cat("Participants:", n_distinct(model_data$participant_id), "\n")
cat("Groups:", n_distinct(model_data$group_uid), "\n")
cat("Rows:", nrow(model_data), "\n\n")
print(table(model_data$treatment))

# -----------------------------
# 2. Helper functions
# -----------------------------

softmax <- function(x) {
  z <- x - max(x)
  exp_z <- exp(z)
  exp_z / sum(exp_z)
}

safe_log <- function(x) {
  log(pmax(x, 1e-300))
}

payoffs_for_round <- function(round) {
  if (round <= 7) {
    c(10, 0, 0)
  } else {
    c(10, 15, 15)
  }
}

# Turn data into group-level list
group_data <- model_data %>%
  arrange(group_uid, round, id_in_group, participant_id) %>%
  group_by(group_uid, treatment) %>%
  group_split() %>%
  map(function(g) {
    rounds <- split(g$choice_idx, g$round)
    list(
      group_uid = unique(g$group_uid),
      treatment = unique(g$treatment),
      rounds = rounds
    )
  })

# -----------------------------
# 3. Negative log likelihood
# -----------------------------

hybrid_nll_fixed <- function(alpha, group_data) {
  
  epsilon <- fixed_epsilon
  tau     <- fixed_tau
  theta   <- fixed_theta
  priorW  <- fixed_priorW
  
  if (alpha <= 0) {
    return(Inf)
  }
  
  # Precedent vs switch likelihoods.
  #
  # P: precedent state
  # W: switch state
  p_choice_given_P <- c(theta, (1 - theta) / 2, (1 - theta) / 2)
  p_choice_given_W <- c(1 - theta, theta / 2, theta / 2)
  
  # Relative target scores.
  #
  # These are NOT normalized probability distributions.
  # J is treated as uninformative for M-vs-N target inference,
  # so it receives the same relative score under both target hypotheses.
  target_score_TM <- c(1, theta, 1 - theta)
  target_score_TN <- c(1, 1 - theta, theta)
  
  logP  <- safe_log(p_choice_given_P)
  logW  <- safe_log(p_choice_given_W)
  logTM <- safe_log(target_score_TM)
  logTN <- safe_log(target_score_TN)
  
  nll <- 0
  
  for (gd in group_data) {
    
    treatment <- gd$treatment
    
    # q(a) = implementation-support belief for J/M/N
    q <- c(1/3, 1/3, 1/3)
    
    # PW = P(switch)
    # PTM = P(target = M | switch)
    PW <- NA_real_
    PTM <- NA_real_
    
    for (round in 1:14) {
      
      choices <- gd$rounds[[as.character(round)]]
      if (is.null(choices)) next
      
      # -----------------------
      # Rounds 1-7
      # -----------------------
      if (round <= 7) {
        
        payoffs <- c(10, 0, 0)
        
        # No strategy branch yet; J is the only payoff-relevant option.
        Q <- payoffs * (q ^ 5)
        
        exploit_probs <- softmax(tau * Q)
        explore_probs <- payoffs / sum(payoffs)
        
        probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
        probs <- probs / sum(probs)
        
        nll <- nll - sum(safe_log(probs[choices]))
        
        # Rounds 1-7 are common/public, so q updates in both conditions.
        counts <- tabulate(choices, nbins = 3)
        q <- (counts + alpha) / (length(choices) + 3 * alpha)
        
        next
      }
      
      # -----------------------
      # Round 8 branch initialization
      # -----------------------
      if (round == 8) {
        PW <- priorW
        PTM <- 0.5
      }
      
      # -----------------------
      # Rounds 8-14 choice values
      # -----------------------
      
      Q_J <- 10 * (1 - PW) * (q[1] ^ 5)
      Q_M <- 15 * PW * PTM * (q[2] ^ 5)
      Q_N <- 15 * PW * (1 - PTM) * (q[3] ^ 5)
      
      Q <- c(Q_J, Q_M, Q_N)
      
      exploit_probs <- softmax(tau * Q)
      
      payoffs <- c(10, 15, 15)
      explore_probs <- payoffs / sum(payoffs)
      
      probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
      probs <- probs / sum(probs)
      
      nll <- nll - sum(safe_log(probs[choices]))
      
      # -----------------------
      # Feedback-based updating
      # -----------------------
      observe <- treatment == "feedback"
      
      if (observe) {
        
        counts <- tabulate(choices, nbins = 3)
        
        # Implementation support update
        q <- (counts + alpha) / (length(choices) + 3 * alpha)
        
        # Bayesian update: precedent vs switch
        log_lik_P <- sum(counts * logP)
        log_lik_W <- sum(counts * logW)
        
        log_post_W <- log(PW) + log_lik_W
        log_post_P <- log(1 - PW) + log_lik_P
        
        mx <- max(log_post_W, log_post_P)
        
        PW <- exp(log_post_W - mx) /
          (exp(log_post_W - mx) + exp(log_post_P - mx))
        
        # Bayesian update: target M vs target N
        log_lik_TM <- sum(counts * logTM)
        log_lik_TN <- sum(counts * logTN)
        
        log_post_M <- log(PTM) + log_lik_TM
        log_post_N <- log(1 - PTM) + log_lik_TN
        
        mx2 <- max(log_post_M, log_post_N)
        
        PTM <- exp(log_post_M - mx2) /
          (exp(log_post_M - mx2) + exp(log_post_N - mx2))
      }
    }
  }
  
  nll
}

# -----------------------------
# 4. Fit one-parameter model
# -----------------------------

fit_1p <- optim(
  par = c(alpha = 23),
  fn = hybrid_nll_fixed,
  group_data = group_data,
  method = "L-BFGS-B",
  lower = c(0.01),
  upper = c(100),
  control = list(maxit = 1000)
)

alpha_hat <- fit_1p$par[1]

par_hat <- c(
  epsilon = fixed_epsilon,
  tau = fixed_tau,
  theta = fixed_theta,
  priorW = fixed_priorW,
  alpha = alpha_hat
)

cat("\nBest-fitting fixed-calibration model parameters:\n")
print(round(par_hat, 4))

cat("\nNLL:", round(fit_1p$value, 2), "\n")
cat("AIC:", round(2 * 1 + 2 * fit_1p$value, 2), "\n")

# -----------------------------
# 5. Generate fitted predictions
# -----------------------------

predict_hybrid_fixed <- function(alpha, group_data) {
  
  epsilon <- fixed_epsilon
  tau     <- fixed_tau
  theta   <- fixed_theta
  priorW  <- fixed_priorW
  
  p_choice_given_P <- c(theta, (1 - theta) / 2, (1 - theta) / 2)
  p_choice_given_W <- c(1 - theta, theta / 2, theta / 2)
  
  target_score_TM <- c(1, theta, 1 - theta)
  target_score_TN <- c(1, 1 - theta, theta)
  
  logP  <- safe_log(p_choice_given_P)
  logW  <- safe_log(p_choice_given_W)
  logTM <- safe_log(target_score_TM)
  logTN <- safe_log(target_score_TN)
  
  pred_rows <- list()
  row_idx <- 1
  
  for (gd in group_data) {
    
    treatment <- gd$treatment
    group_uid <- gd$group_uid
    
    q <- c(1/3, 1/3, 1/3)
    PW <- NA_real_
    PTM <- NA_real_
    
    for (round in 1:14) {
      
      choices <- gd$rounds[[as.character(round)]]
      if (is.null(choices)) next
      
      if (round <= 7) {
        
        payoffs <- c(10, 0, 0)
        Q <- payoffs * (q ^ 5)
        
        exploit_probs <- softmax(tau * Q)
        explore_probs <- payoffs / sum(payoffs)
        
        probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
        probs <- probs / sum(probs)
        
        belief_switch <- NA_real_
        belief_target_M <- NA_real_
        
      } else {
        
        if (round == 8) {
          PW <- priorW
          PTM <- 0.5
        }
        
        Q <- c(
          10 * (1 - PW) * (q[1] ^ 5),
          15 * PW * PTM * (q[2] ^ 5),
          15 * PW * (1 - PTM) * (q[3] ^ 5)
        )
        
        exploit_probs <- softmax(tau * Q)
        
        payoffs <- c(10, 15, 15)
        explore_probs <- payoffs / sum(payoffs)
        
        probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
        probs <- probs / sum(probs)
        
        belief_switch <- PW
        belief_target_M <- PTM
      }
      
      pred_rows[[row_idx]] <- tibble(
        group_uid = group_uid,
        treatment = treatment,
        round = round,
        n = length(choices),
        obs_switch = mean(choices != 1),
        pred_J = probs[1],
        pred_M = probs[2],
        pred_N = probs[3],
        pred_switch = probs[2] + probs[3],
        belief_switch = belief_switch,
        belief_target_M = belief_target_M,
        q_J = q[1],
        q_M = q[2],
        q_N = q[3]
      )
      
      row_idx <- row_idx + 1
      
      # In predictions, rounds 1-7 update q for everyone.
      # After round 8, only feedback groups update from public choices.
      observe <- treatment == "feedback" || round <= 7
      
      if (observe) {
        
        counts <- tabulate(choices, nbins = 3)
        
        q <- (counts + alpha) / (length(choices) + 3 * alpha)
        
        if (round >= 8) {
          
          log_lik_P <- sum(counts * logP)
          log_lik_W <- sum(counts * logW)
          
          log_post_W <- log(PW) + log_lik_W
          log_post_P <- log(1 - PW) + log_lik_P
          
          mx <- max(log_post_W, log_post_P)
          
          PW <- exp(log_post_W - mx) /
            (exp(log_post_W - mx) + exp(log_post_P - mx))
          
          log_lik_TM <- sum(counts * logTM)
          log_lik_TN <- sum(counts * logTN)
          
          log_post_M <- log(PTM) + log_lik_TM
          log_post_N <- log(1 - PTM) + log_lik_TN
          
          mx2 <- max(log_post_M, log_post_N)
          
          PTM <- exp(log_post_M - mx2) /
            (exp(log_post_M - mx2) + exp(log_post_N - mx2))
        }
      }
    }
  }
  
  bind_rows(pred_rows)
}

pred <- predict_hybrid_fixed(alpha_hat, group_data)

agg <- pred %>%
  rename(weight_n = n) %>%
  group_by(treatment, round) %>%
  summarise(
    n = sum(weight_n),
    
    obs_switch = weighted.mean(obs_switch, weight_n),
    pred_switch = weighted.mean(pred_switch, weight_n),
    pred_J = weighted.mean(pred_J, weight_n),
    pred_M = weighted.mean(pred_M, weight_n),
    pred_N = weighted.mean(pred_N, weight_n),
    
    belief_switch = if (all(is.na(belief_switch))) {
      NA_real_
    } else {
      weighted.mean(belief_switch, weight_n, na.rm = TRUE)
    },
    
    belief_target_M = if (all(is.na(belief_target_M))) {
      NA_real_
    } else {
      weighted.mean(belief_target_M, weight_n, na.rm = TRUE)
    },
    
    q_J = weighted.mean(q_J, weight_n),
    q_M = weighted.mean(q_M, weight_n),
    q_N = weighted.mean(q_N, weight_n),
    
    .groups = "drop"
  )

# -----------------------------
# 6. Plot observed vs fitted switching
# -----------------------------

p_switch <- ggplot(agg, aes(x = round)) +
  geom_line(aes(y = obs_switch, color = treatment, linetype = "Observed"), linewidth = 1.2) +
  geom_point(aes(y = obs_switch, color = treatment), size = 2.5) +
  geom_line(aes(y = pred_switch, color = treatment, linetype = "Fitted"), linewidth = 1.2) +
  geom_point(aes(y = pred_switch, color = treatment), size = 2.5, shape = 1) +
  geom_vline(xintercept = 7.5, linetype = "dotted") +
  scale_x_continuous(breaks = 1:14) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "Observed vs fitted switching",
    subtitle = paste0(
      "fixed: epsilon=", fixed_epsilon,
      ", tau=", fixed_tau,
      ", theta=", fixed_theta,
      ", priorW=", fixed_priorW,
      "; fitted alpha=", round(alpha_hat, 2)
    ),
    x = "Round",
    y = "Switching rate: P(choice != J)",
    color = "Condition",
    linetype = ""
  ) +
  theme_minimal(base_size = 13)

print(p_switch)

ggsave(
  file.path(out_dir, "fixed_hybrid_observed_vs_fitted_switching.png"),
  p_switch,
  width = 9,
  height = 5.5,
  dpi = 300
)

# -----------------------------
# 7. Diagnostic plot:
# strategy belief, support, prediction
# -----------------------------

belief_diag <- agg %>%
  filter(round >= 8) %>%
  mutate(
    total_switch_support = q_M + q_N,
    concentrated_switch_support = q_M^5 + q_N^5
  ) %>%
  select(
    treatment,
    round,
    pred_switch,
    belief_switch,
    total_switch_support,
    concentrated_switch_support
  ) %>%
  pivot_longer(
    cols = c(
      belief_switch,
      total_switch_support,
      concentrated_switch_support,
      pred_switch
    ),
    names_to = "quantity",
    values_to = "value"
  ) %>%
  mutate(
    quantity = case_when(
      quantity == "belief_switch" ~ "Strategy belief: P(switch)",
      quantity == "total_switch_support" ~ "Total switch support: q(M)+q(N)",
      quantity == "concentrated_switch_support" ~ "Concentrated support: q(M)^5+q(N)^5",
      quantity == "pred_switch" ~ "Predicted switching: P(choice != J)",
      TRUE ~ quantity
    ),
    quantity = factor(
      quantity,
      levels = c(
        "Strategy belief: P(switch)",
        "Total switch support: q(M)+q(N)",
        "Concentrated support: q(M)^5+q(N)^5",
        "Predicted switching: P(choice != J)"
      )
    )
  )

p_belief_diag <- ggplot(
  belief_diag,
  aes(x = round, y = value, color = treatment)
) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2.5) +
  facet_wrap(~ quantity, ncol = 1, scales = "free_y") +
  scale_x_continuous(breaks = 8:14) +
  labs(
    title = "Strategy belief, switch support, and predicted switching",
    subtitle = paste0(
      "fixed: epsilon=", fixed_epsilon,
      ", tau=", fixed_tau,
      ", theta=", fixed_theta,
      ", priorW=", fixed_priorW,
      "; fitted alpha=", round(alpha_hat, 2)
    ),
    x = "Round",
    y = "Value",
    color = "Condition"
  ) +
  theme_minimal(base_size = 13)

print(p_belief_diag)

ggsave(
  file.path(out_dir, "fixed_hybrid_belief_support_prediction_diagnostic.png"),
  p_belief_diag,
  width = 8.5,
  height = 11,
  dpi = 300
)

# -----------------------------
# 8. Conditional diagnostic:
# current switching by previous public switching
# -----------------------------

group_round_obs <- model_data %>%
  group_by(group_uid, treatment, round) %>%
  summarise(
    n = n(),
    n_switched = sum(switched),
    obs_switch_rate = mean(switched),
    .groups = "drop"
  )

prev_switch <- group_round_obs %>%
  select(group_uid, round, prev_n_switched = n_switched) %>%
  mutate(round = round + 1)

conditional_diag <- group_round_obs %>%
  left_join(prev_switch, by = c("group_uid", "round")) %>%
  left_join(
    pred %>% select(group_uid, round, pred_switch, belief_switch, q_J, q_M, q_N),
    by = c("group_uid", "round")
  ) %>%
  filter(treatment == "feedback", round >= 9) %>%
  mutate(prev_n_switched = replace_na(prev_n_switched, 0)) %>%
  group_by(prev_n_switched) %>%
  summarise(
    n_group_rounds = n(),
    observed_current_switch = mean(obs_switch_rate),
    fitted_current_switch = mean(pred_switch),
    fitted_belief_switch = mean(belief_switch, na.rm = TRUE),
    mean_q_J = mean(q_J),
    mean_q_M = mean(q_M),
    mean_q_N = mean(q_N),
    .groups = "drop"
  )

print(conditional_diag)

p_cond <- ggplot(conditional_diag, aes(x = prev_n_switched)) +
  geom_line(aes(y = observed_current_switch, color = "Observed"), linewidth = 1.2) +
  geom_point(aes(y = observed_current_switch, color = "Observed"), size = 2.5) +
  geom_line(aes(y = fitted_current_switch, color = "Fitted"), linewidth = 1.2, linetype = "dashed") +
  geom_point(aes(y = fitted_current_switch, color = "Fitted"), size = 2.5) +
  scale_x_continuous(breaks = 0:6) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "Current switching as a function of previous public switching",
    subtitle = "Feedback condition, rounds 9-14",
    x = "Number of group members who switched in previous round",
    y = "Current-round switching rate",
    color = ""
  ) +
  theme_minimal(base_size = 13)

print(p_cond)

ggsave(
  file.path(out_dir, "fixed_hybrid_conditional_switching_by_prev_switch_count.png"),
  p_cond,
  width = 8.5,
  height = 5.5,
  dpi = 300
)

# -----------------------------
# 9. Save outputs
# -----------------------------

write_csv(
  pred,
  file.path(out_dir, "fixed_hybrid_group_predictions.csv")
)

write_csv(
  agg,
  file.path(out_dir, "fixed_hybrid_aggregate_predictions.csv")
)

write_csv(
  conditional_diag,
  file.path(out_dir, "fixed_hybrid_conditional_switching_by_prev_switch_count.csv")
)

parameter_summary <- tibble(
  parameter = c("epsilon", "tau", "theta", "priorW", "alpha"),
  value = c(fixed_epsilon, fixed_tau, fixed_theta, fixed_priorW, alpha_hat),
  status = c("fixed", "fixed", "fixed", "fixed", "estimated")
)

write_csv(
  parameter_summary,
  file.path(out_dir, "fixed_hybrid_parameter_summary.csv")
)

# Aggregate-level R2 for switching curves
r2_switching <- agg %>%
  group_by(treatment) %>%
  summarise(
    r2 = 1 - sum((obs_switch - pred_switch)^2) /
      sum((obs_switch - mean(obs_switch))^2),
    rmse = sqrt(mean((obs_switch - pred_switch)^2)),
    mae = mean(abs(obs_switch - pred_switch)),
    .groups = "drop"
  )

r2_switching_overall <- agg %>%
  summarise(
    r2 = 1 - sum((obs_switch - pred_switch)^2) /
      sum((obs_switch - mean(obs_switch))^2),
    rmse = sqrt(mean((obs_switch - pred_switch)^2)),
    mae = mean(abs(obs_switch - pred_switch))
  )

print(r2_switching)
print(r2_switching_overall)

cat("\nSaved outputs to:", out_dir, "\n")
cat("- fixed_hybrid_parameter_summary.csv\n")
cat("- fixed_hybrid_group_predictions.csv\n")
cat("- fixed_hybrid_aggregate_predictions.csv\n")
cat("- fixed_hybrid_conditional_switching_by_prev_switch_count.csv\n")
cat("- fixed_hybrid_observed_vs_fitted_switching.png\n")
cat("- fixed_hybrid_belief_support_prediction_diagnostic.png\n")
cat("- fixed_hybrid_conditional_switching_by_prev_switch_count.png\n")

# ============================================================
# Sanity check 5: calibration of predicted switching probabilities
# Requires pred from fitted hybrid predictions
# ============================================================

trial_level_pred <- model_data %>%
  select(group_uid, treatment, round, participant_id, switched) %>%
  left_join(
    pred %>% select(group_uid, round, pred_switch),
    by = c("group_uid", "round")
  )

calibration <- trial_level_pred %>%
  mutate(
    pred_bin = cut(
      pred_switch,
      breaks = seq(0, 1, by = 0.1),
      include.lowest = TRUE
    )
  ) %>%
  group_by(pred_bin) %>%
  summarise(
    mean_pred = mean(pred_switch),
    observed_switch = mean(switched),
    n = n(),
    .groups = "drop"
  )

print(calibration)

p_calibration <- ggplot(calibration, aes(x = mean_pred, y = observed_switch)) +
  geom_point(aes(size = n), alpha = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  scale_x_continuous(limits = c(0, 1)) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "Trial-level calibration of predicted switching",
    x = "Mean predicted P(choice != J)",
    y = "Observed switching rate",
    size = "N trials"
  ) +
  theme_minimal(base_size = 13)

print(p_calibration)

ggsave(
  file.path(out_dir, "robustness_trial_level_switch_calibration.png"),
  p_calibration,
  width = 6,
  height = 5.5,
  dpi = 300
)

write_csv(
  calibration,
  file.path(out_dir, "robustness_trial_level_switch_calibration.csv")
)