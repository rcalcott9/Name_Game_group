# ============================================================
# Hybrid Bayesian Precedent/Switch + Coordination-Support Model
# ============================================================
#
# Model:
#
# Latent strategy belief:
#   P(W) = probability the group is switching
#   1 - P(W) = probability the group is preserving precedent
#
# Target belief:
#   P(TM) = probability M is the switch target, conditional on switching
#   1 - P(TM) = probability N is the switch target
#
# Implementation/support belief:
#   q(J), q(M), q(N) = expected probability that another group member chooses each letter
#
# Values:
#   Q(J) = 10 * (1 - P(W)) * q(J)^5
#   Q(M) = 15 * P(W) * P(TM) * q(M)^5
#   Q(N) = 15 * P(W) * (1 - P(TM)) * q(N)^5
#
# Choice:
#   P(choice = a) =
#     (1 - epsilon) * softmax(tau * Q(a)) +
#     epsilon * payoff_proportional_exploration(a)
#
# Bayesian updates:
#   public feedback updates P(W), P(TM), and q
#   no-feedback condition receives no post-round-7 public evidence
#
# ============================================================

library(tidyverse)
library(ggplot2)

# -----------------------------
# 1. Load and reshape data
# -----------------------------

wide_path <- "~/Downloads/all_apps_wide-2026-01-12-6.csv"
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
        treatment = `consent.1.player.treatment`,
        round = round,
        letter_choice = .data[[col_letter]],
        group_id_raw = .data[[col_group]],
        id_in_group = .data[[col_id]]
      ) %>%
      filter(!is.na(letter_choice), letter_choice != "")
    
    round_data_list[[length(round_data_list) + 1]] <- tmp
  }
}

long_data <- bind_rows(round_data_list) %>%
  mutate(
    treatment = as.character(treatment),
    letter_choice = str_trim(as.character(letter_choice)),
    group_uid = paste(treatment, group_id_raw, sep = "_")
  )

# Keep complete participants
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

# Turn data into group-level list for faster fitting
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

hybrid_nll <- function(par, group_data) {
  
  epsilon <- par[1]
  tau     <- par[2]
  theta   <- par[3]
  priorW  <- par[4]
  alpha   <- par[5]
  
  # Bounds / validity checks
  if (
    epsilon < 0 || epsilon > 0.8 ||
    tau <= 0 ||
    theta <= 0.5 || theta >= 1 ||
    priorW <= 0 || priorW >= 1 ||
    alpha <= 0
  ) {
    return(Inf)
  }
  
  # Likelihoods for Bayesian updating.
  #
  # Precedent P:
  #   J likely; M/N unlikely.
  #
  # Switch W:
  #   M/N likely; J unlikely.
  #
  # Target M:
  #   M likely; N unlikely; J uninformative.
  #
  # Target N:
  #   N likely; M unlikely; J uninformative.
  
  p_choice_given_P <- c(theta, (1 - theta) / 2, (1 - theta) / 2)
  p_choice_given_W <- c(1 - theta, theta / 2, theta / 2)
  
  p_choice_given_TM <- c(1, theta, 1 - theta)
  p_choice_given_TN <- c(1, 1 - theta, theta)
  
  logP  <- safe_log(p_choice_given_P)
  logW  <- safe_log(p_choice_given_W)
  logTM <- safe_log(p_choice_given_TM)
  logTN <- safe_log(p_choice_given_TN)
  
  nll <- 0
  
  for (gd in group_data) {
    
    treatment <- gd$treatment
    
    # q = implementation/support belief.
    # Initial neutral belief before evidence.
    q <- c(1/3, 1/3, 1/3)
    
    # Bayesian latent beliefs, initialized at round 8.
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
        
        Q <- payoffs * (q ^ 5)
        exploit_probs <- softmax(tau * Q)
        
        explore_probs <- payoffs / sum(payoffs)
        
        probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
        probs <- probs / sum(probs)
        
        nll <- nll - sum(safe_log(probs[choices]))
        
        # Everyone has public evidence through round 7.
        counts <- tabulate(choices, nbins = 3)
        q <- (counts + alpha) / (length(choices) + 3 * alpha)
        
        next
      }
      
      # -----------------------
      # Round 8: branch point
      # -----------------------
      if (round == 8) {
        PW <- priorW
        PTM <- 0.5
      }
      
      # -----------------------
      # Rounds 8-14 values
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
      # Public evidence update
      # -----------------------
      observe <- treatment == "feedback"
      
      if (observe) {
        
        counts <- tabulate(choices, nbins = 3)
        
        # Update implementation/support belief q
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
# 4. Fit model
# -----------------------------

# Parameters:
# epsilon, tau, theta, priorW, alpha

lower <- c(0.001, 0.001, 0.501, 0.001, 0.01)
upper <- c(0.799, 300.0, 0.999, 0.999, 100.0)

set.seed(2026)

# Use optim with multiple starting points.
# This is usually enough. For publication-grade fitting,
# run more starts or use DEoptim / rstan / cmdstanr.

start_grid <- tibble(
  epsilon = c(0.03, 0.10, 0.20, 0.30),
  tau     = c(30, 80, 120),
  theta   = c(0.52, 0.65, 0.80),
  priorW  = c(0.40, 0.60, 0.70),
  alpha   = c(5, 20, 30, 60)
) %>%
  tidyr::crossing(
    epsilon = epsilon,
    tau = tau,
    theta = theta,
    priorW = priorW,
    alpha = alpha
  ) %>%
  distinct() %>%
  slice_sample(n = min(60, n()))

fit_one <- function(start) {
  optim(
    par = as.numeric(start),
    fn = hybrid_nll,
    group_data = group_data,
    method = "L-BFGS-B",
    lower = lower,
    upper = upper,
    control = list(maxit = 1000)
  )
}

fits <- vector("list", nrow(start_grid))

for (i in seq_len(nrow(start_grid))) {
  fits[[i]] <- fit_one(start_grid[i, ])
  cat("Fit", i, "NLL =", fits[[i]]$value, "\n")
}

best_idx <- which.min(map_dbl(fits, "value"))
best_fit <- fits[[best_idx]]

par_hat <- best_fit$par
names(par_hat) <- c("epsilon", "tau", "theta", "priorW", "alpha")

cat("\nBest-fitting parameters:\n")
print(round(par_hat, 4))

cat("\nNLL:", round(best_fit$value, 2), "\n")
cat("AIC:", round(2 * length(par_hat) + 2 * best_fit$value, 2), "\n")

# -----------------------------
# 5. Generate fitted predictions
# -----------------------------

predict_hybrid <- function(par, group_data) {
  
  epsilon <- par[1]
  tau     <- par[2]
  theta   <- par[3]
  priorW  <- par[4]
  alpha   <- par[5]
  
  p_choice_given_P <- c(theta, (1 - theta) / 2, (1 - theta) / 2)
  p_choice_given_W <- c(1 - theta, theta / 2, theta / 2)
  
  p_choice_given_TM <- c(1, theta, 1 - theta)
  p_choice_given_TN <- c(1, 1 - theta, theta)
  
  logP  <- safe_log(p_choice_given_P)
  logW  <- safe_log(p_choice_given_W)
  logTM <- safe_log(p_choice_given_TM)
  logTN <- safe_log(p_choice_given_TN)
  
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

pred <- predict_hybrid(par_hat, group_data)

agg <- pred %>%
  group_by(treatment, round) %>%
  summarise(
    n = sum(n),
    obs_switch = weighted.mean(obs_switch, n),
    pred_switch = weighted.mean(pred_switch, n),
    pred_J = weighted.mean(pred_J, n),
    pred_M = weighted.mean(pred_M, n),
    pred_N = weighted.mean(pred_N, n),
    belief_switch = ifelse(
      all(is.na(belief_switch)),
      NA_real_,
      weighted.mean(belief_switch, n, na.rm = TRUE)
    ),
    belief_target_M = ifelse(
      all(is.na(belief_target_M)),
      NA_real_,
      weighted.mean(belief_target_M, n, na.rm = TRUE)
    ),
    q_J = weighted.mean(q_J, n),
    q_M = weighted.mean(q_M, n),
    q_N = weighted.mean(q_N, n),
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
      "epsilon=", round(par_hat["epsilon"], 3),
      ", tau=", round(par_hat["tau"], 1),
      ", theta=", round(par_hat["theta"], 3),
      ", priorW=", round(par_hat["priorW"], 3),
      ", alpha=", round(par_hat["alpha"], 2)
    ),
    x = "Round",
    y = "Switching rate: P(choice != J)",
    color = "Condition",
    linetype = ""
  ) +
  theme_minimal(base_size = 13)

print(p_switch)

ggsave(
  "fitted_hybrid_bayes_switching.png",
  p_switch,
  width = 9,
  height = 5.5,
  dpi = 300
)

# -----------------------------
# 7. Plot fitted Bayesian belief
# -----------------------------

p_belief <- agg %>%
  filter(round >= 8) %>%
  ggplot(aes(x = round, y = belief_switch, color = treatment)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2.5) +
  scale_x_continuous(breaks = 8:14) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "Fitted belief that group is switching",
    x = "Round",
    y = "P(switch)",
    color = "Condition"
  ) +
  theme_minimal(base_size = 13)

print(p_belief)

ggsave(
  "fitted_hybrid_bayes_switch_belief.png",
  p_belief,
  width = 8,
  height = 5,
  dpi = 300
)

# -----------------------------
# 8. Conditional diagnostic:
#    Does next-round switching depend on prior public switching?
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
  "conditional_switching_by_prev_switch_count.png",
  p_cond,
  width = 8.5,
  height = 5.5,
  dpi = 300
)

# -----------------------------
# 9. Save outputs
# -----------------------------

write_csv(pred, "fitted_hybrid_bayes_group_predictions.csv")
write_csv(agg, "fitted_hybrid_bayes_aggregate_predictions.csv")
write_csv(conditional_diag, "conditional_switching_by_prev_switch_count.csv")

cat("\nSaved outputs:\n")
cat("- fitted_hybrid_bayes_switching.png\n")
cat("- fitted_hybrid_bayes_switch_belief.png\n")
cat("- conditional_switching_by_prev_switch_count.png\n")
cat("- fitted_hybrid_bayes_group_predictions.csv\n")
cat("- fitted_hybrid_bayes_aggregate_predictions.csv\n")
cat("- conditional_switching_by_prev_switch_count.csv\n")