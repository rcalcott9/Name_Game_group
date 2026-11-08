# ============================================================
# Broad Model Comparison for Name Game
# ============================================================
#
# Compares plausible cognitive model families:
#
# 1. payoff_only_1p
# 2. static_precedent_payoff_2p
# 3. frequency_support_Vq_3p
# 4. coord_support_Vq5_3p
# 5. strategy_only_VS_3p
# 6. hybrid_calibrated_1p
# 7. hybrid_4p_free_epsilon_tau_theta_alpha
#
# Current preferred model:
#
#   hybrid_calibrated_1p
#
# with fixed/calibrated:
#
#   epsilon = .04
#   tau     = 90
#   theta   = .52
#   priorW  = .69
#
# and estimated:
#
#   alpha
#
# Important caveat:
#   These fixed values are calibrated from exploratory model development.
#   They should be described as calibrated/preset, not a priori constants,
#   unless evaluated on a genuinely held-out/new dataset.
# ============================================================

library(tidyverse)
library(ggplot2)

# -----------------------------
# 0. Settings
# -----------------------------

wide_path <- "~/Downloads/all_apps_wide-2026-01-12-6.csv"

# Safe output directory setup
out_dir <- file.path(getwd(), "model_comparison_outputs")

if (file.exists(out_dir) && !dir.exists(out_dir)) {
  stop("A file named 'model_comparison_outputs' exists. Rename/delete it so a folder can be created.")
}

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}

cat("Saving outputs to:\n", out_dir, "\n")

set.seed(2026)

# Calibrated fixed values for preferred 1p hybrid
fixed_epsilon <- 0.04
fixed_tau     <- 90
fixed_theta   <- 0.52
fixed_priorW  <- 0.69

# Local grids for fitting comparison models
tau_payoff_grid <- c(0.001, 0.02, 0.05, 0.10, 0.20)
precedent_bonus_grid <- c(0, 2, 5, 10, 15, 25)

epsilon_grid <- c(0.02, 0.04, 0.06, 0.10)
tau_grid     <- c(70, 80, 90, 100, 110, 140)
theta_grid   <- c(0.51, 0.52, 0.53, 0.55, 0.60)
alpha_grid   <- c(10, 15, 18, 23, 30, 40, 60, 80, 120)

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
    
    # Include app to avoid accidental group-id collisions.
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

cat("\nData used:\n")
cat("Participants:", n_distinct(model_data$participant_id), "\n")
cat("Groups:", n_distinct(model_data$group_uid), "\n")
cat("Rows:", nrow(model_data), "\n\n")
print(table(model_data$treatment))

N_obs <- nrow(model_data)

# -----------------------------
# 2. Group-level count data
# -----------------------------

make_group_data <- function(df) {
  
  df %>%
    arrange(group_uid, round, id_in_group, participant_id) %>%
    group_by(group_uid, treatment) %>%
    group_split() %>%
    map(function(g) {
      
      round_list <- list()
      
      for (r in sort(unique(g$round))) {
        choices <- g %>%
          filter(round == r) %>%
          pull(choice_idx)
        
        counts <- tabulate(choices, nbins = 3)
        
        round_list[[as.character(r)]] <- list(
          counts = counts,
          n = sum(counts)
        )
      }
      
      list(
        group_uid = unique(g$group_uid),
        treatment = unique(g$treatment),
        rounds = round_list
      )
    })
}

group_data <- make_group_data(model_data)

# -----------------------------
# 3. Helper functions
# -----------------------------

softmax <- function(x) {
  z <- x - max(x)
  exp_z <- exp(z)
  exp_z / sum(exp_z)
}

safe_log <- function(x) {
  log(pmax(x, 1e-300))
}

nll_counts <- function(counts, probs) {
  -sum(counts * safe_log(probs))
}

payoffs_for_round <- function(round) {
  if (round <= 7) {
    c(10, 0, 0)
  } else {
    c(10, 15, 15)
  }
}

# -----------------------------
# 4. Likelihood functions
# -----------------------------

# 4.1 Payoff-only
nll_payoff_only <- function(groups, tau) {
  
  nll <- 0
  
  for (gd in groups) {
    for (round in 1:14) {
      
      rr <- gd$rounds[[as.character(round)]]
      if (is.null(rr)) next
      
      V <- payoffs_for_round(round)
      probs <- softmax(tau * V)
      
      nll <- nll + nll_counts(rr$counts, probs)
    }
  }
  
  nll
}

# 4.2 Static precedent + payoff
nll_static_precedent_payoff <- function(groups, tau, precedent_bonus) {
  
  nll <- 0
  
  for (gd in groups) {
    for (round in 1:14) {
      
      rr <- gd$rounds[[as.character(round)]]
      if (is.null(rr)) next
      
      V <- payoffs_for_round(round)
      Q <- V + c(precedent_bonus, 0, 0)
      probs <- softmax(tau * Q)
      
      nll <- nll + nll_counts(rr$counts, probs)
    }
  }
  
  nll
}

# 4.3 Frequency/coordination support
nll_social_support <- function(groups, epsilon, tau, alpha, exponent) {
  
  nll <- 0
  
  for (gd in groups) {
    
    feedback <- gd$treatment == "feedback"
    q <- c(1/3, 1/3, 1/3)
    
    for (round in 1:14) {
      
      rr <- gd$rounds[[as.character(round)]]
      if (is.null(rr)) next
      
      V <- payoffs_for_round(round)
      Q <- V * (q ^ exponent)
      
      exploit_probs <- softmax(tau * Q)
      explore_probs <- V / sum(V)
      
      probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
      probs <- probs / sum(probs)
      
      nll <- nll + nll_counts(rr$counts, probs)
      
      observe <- feedback || round <= 7
      
      if (observe) {
        q <- (rr$counts + alpha) / (rr$n + 3 * alpha)
      }
    }
  }
  
  nll
}

# 4.4 Strategy-only Bayesian model
nll_strategy_only <- function(groups, epsilon, tau, theta, priorW = fixed_priorW) {
  
  p_choice_given_P <- c(theta, (1 - theta) / 2, (1 - theta) / 2)
  p_choice_given_W <- c(1 - theta, theta / 2, theta / 2)
  
  # Relative target scores, not normalized probabilities.
  # J is uninformative for M-vs-N target inference.
  target_score_TM <- c(1, theta, 1 - theta)
  target_score_TN <- c(1, 1 - theta, theta)
  
  logP  <- safe_log(p_choice_given_P)
  logW  <- safe_log(p_choice_given_W)
  logTM <- safe_log(target_score_TM)
  logTN <- safe_log(target_score_TN)
  
  nll <- 0
  
  for (gd in groups) {
    
    feedback <- gd$treatment == "feedback"
    PW <- NA_real_
    PTM <- NA_real_
    
    for (round in 1:14) {
      
      rr <- gd$rounds[[as.character(round)]]
      if (is.null(rr)) next
      
      if (round <= 7) {
        
        V <- c(10, 0, 0)
        probs <- softmax(tau * V)
        
        nll <- nll + nll_counts(rr$counts, probs)
        next
      }
      
      if (round == 8) {
        PW <- priorW
        PTM <- 0.5
      }
      
      Q <- c(
        10 * (1 - PW),
        15 * PW * PTM,
        15 * PW * (1 - PTM)
      )
      
      exploit_probs <- softmax(tau * Q)
      V <- c(10, 15, 15)
      explore_probs <- V / sum(V)
      
      probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
      probs <- probs / sum(probs)
      
      nll <- nll + nll_counts(rr$counts, probs)
      
      if (feedback) {
        
        counts <- rr$counts
        
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
  
  nll
}

# 4.5 Hybrid model: V * S * q^5
nll_hybrid <- function(
    groups,
    epsilon,
    tau,
    theta,
    alpha,
    priorW = fixed_priorW
) {
  
  p_choice_given_P <- c(theta, (1 - theta) / 2, (1 - theta) / 2)
  p_choice_given_W <- c(1 - theta, theta / 2, theta / 2)
  
  # Relative target scores, not normalized probabilities.
  # J is uninformative for M-vs-N target inference.
  target_score_TM <- c(1, theta, 1 - theta)
  target_score_TN <- c(1, 1 - theta, theta)
  
  logP  <- safe_log(p_choice_given_P)
  logW  <- safe_log(p_choice_given_W)
  logTM <- safe_log(target_score_TM)
  logTN <- safe_log(target_score_TN)
  
  nll <- 0
  
  for (gd in groups) {
    
    feedback <- gd$treatment == "feedback"
    q <- c(1/3, 1/3, 1/3)
    
    PW <- NA_real_
    PTM <- NA_real_
    
    for (round in 1:14) {
      
      rr <- gd$rounds[[as.character(round)]]
      if (is.null(rr)) next
      
      if (round <= 7) {
        
        V <- c(10, 0, 0)
        Q <- V * (q ^ 5)
        
        exploit_probs <- softmax(tau * Q)
        explore_probs <- V / sum(V)
        
        probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
        probs <- probs / sum(probs)
        
        nll <- nll + nll_counts(rr$counts, probs)
        
        q <- (rr$counts + alpha) / (rr$n + 3 * alpha)
        next
      }
      
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
      V <- c(10, 15, 15)
      explore_probs <- V / sum(V)
      
      probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
      probs <- probs / sum(probs)
      
      nll <- nll + nll_counts(rr$counts, probs)
      
      if (feedback) {
        
        counts <- rr$counts
        
        q <- (counts + alpha) / (rr$n + 3 * alpha)
        
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
  
  nll
}

# -----------------------------
# 5. Grid fitting wrappers
# -----------------------------

fit_payoff_only <- function(groups) {
  
  tidyr::crossing(tau = tau_payoff_grid) %>%
    rowwise() %>%
    mutate(nll = nll_payoff_only(groups, tau)) %>%
    ungroup() %>%
    arrange(nll) %>%
    slice(1) %>%
    mutate(
      model = "payoff_only_1p",
      k = 1
    )
}

fit_static_precedent_payoff <- function(groups) {
  
  tidyr::crossing(
    tau = tau_payoff_grid,
    precedent_bonus = precedent_bonus_grid
  ) %>%
    rowwise() %>%
    mutate(nll = nll_static_precedent_payoff(groups, tau, precedent_bonus)) %>%
    ungroup() %>%
    arrange(nll) %>%
    slice(1) %>%
    mutate(
      model = "static_precedent_payoff_2p",
      k = 2
    )
}

fit_frequency_support <- function(groups) {
  
  tidyr::crossing(
    epsilon = epsilon_grid,
    tau = tau_grid,
    alpha = alpha_grid
  ) %>%
    rowwise() %>%
    mutate(nll = nll_social_support(groups, epsilon, tau, alpha, exponent = 1)) %>%
    ungroup() %>%
    arrange(nll) %>%
    slice(1) %>%
    mutate(
      model = "frequency_support_Vq_3p",
      k = 3
    )
}

fit_coord_support <- function(groups) {
  
  tidyr::crossing(
    epsilon = epsilon_grid,
    tau = tau_grid,
    alpha = alpha_grid
  ) %>%
    rowwise() %>%
    mutate(nll = nll_social_support(groups, epsilon, tau, alpha, exponent = 5)) %>%
    ungroup() %>%
    arrange(nll) %>%
    slice(1) %>%
    mutate(
      model = "coord_support_Vq5_3p",
      k = 3
    )
}

fit_strategy_only <- function(groups) {
  
  tidyr::crossing(
    epsilon = epsilon_grid,
    tau = tau_grid,
    theta = theta_grid
  ) %>%
    rowwise() %>%
    mutate(nll = nll_strategy_only(groups, epsilon, tau, theta, priorW = fixed_priorW)) %>%
    ungroup() %>%
    arrange(nll) %>%
    slice(1) %>%
    mutate(
      model = "strategy_only_VS_3p",
      k = 3,
      priorW = fixed_priorW
    )
}

fit_hybrid_calibrated_1p <- function(groups) {
  
  tidyr::crossing(alpha = alpha_grid) %>%
    rowwise() %>%
    mutate(
      nll = nll_hybrid(
        groups,
        epsilon = fixed_epsilon,
        tau = fixed_tau,
        theta = fixed_theta,
        alpha = alpha,
        priorW = fixed_priorW
      )
    ) %>%
    ungroup() %>%
    arrange(nll) %>%
    slice(1) %>%
    mutate(
      model = "hybrid_calibrated_1p",
      k = 1,
      epsilon = fixed_epsilon,
      tau = fixed_tau,
      theta = fixed_theta,
      priorW = fixed_priorW
    )
}

fit_hybrid_4p <- function(groups) {
  
  tidyr::crossing(
    epsilon = epsilon_grid,
    tau = tau_grid,
    theta = theta_grid,
    alpha = alpha_grid
  ) %>%
    rowwise() %>%
    mutate(
      nll = nll_hybrid(
        groups,
        epsilon = epsilon,
        tau = tau,
        theta = theta,
        alpha = alpha,
        priorW = fixed_priorW
      )
    ) %>%
    ungroup() %>%
    arrange(nll) %>%
    slice(1) %>%
    mutate(
      model = "hybrid_4p_free_epsilon_tau_theta_alpha",
      k = 4,
      priorW = fixed_priorW
    )
}

fitters <- list(
  payoff_only_1p = fit_payoff_only,
  static_precedent_payoff_2p = fit_static_precedent_payoff,
  frequency_support_Vq_3p = fit_frequency_support,
  coord_support_Vq5_3p = fit_coord_support,
  strategy_only_VS_3p = fit_strategy_only,
  hybrid_calibrated_1p = fit_hybrid_calibrated_1p,
  hybrid_4p_free_epsilon_tau_theta_alpha = fit_hybrid_4p
)

# -----------------------------
# 6. Full-data model comparison
# -----------------------------

cat("\n=== FULL-DATA MODEL COMPARISON ===\n")

full_results <- list()

for (m in names(fitters)) {
  cat("Fitting:", m, "\n")
  full_results[[m]] <- fitters[[m]](group_data)
}

full_comparison <- bind_rows(full_results) %>%
  mutate(
    AIC = 2 * k + 2 * nll,
    BIC = k * log(N_obs) + 2 * nll
  ) %>%
  arrange(AIC) %>%
  mutate(
    delta_AIC = AIC - min(AIC),
    delta_BIC = BIC - min(BIC)
  )

cat("\nFull-data comparison:\n")
print(full_comparison)

write_csv(
  full_comparison,
  file.path(out_dir, "model_family_full_comparison.csv")
)

# -----------------------------
# 7. Group-level 5-fold CV
# -----------------------------

cat("\n=== GROUP-LEVEL 5-FOLD CROSS-VALIDATION ===\n")

group_info <- tibble(
  group_uid = map_chr(group_data, "group_uid"),
  treatment = map_chr(group_data, "treatment")
)

make_folds <- function(group_info, K = 5) {
  
  group_info %>%
    group_by(treatment) %>%
    mutate(
      shuffled = sample(row_number()),
      fold = ((shuffled - 1) %% K) + 1
    ) %>%
    ungroup() %>%
    select(group_uid, fold)
}

fold_assignments <- make_folds(group_info, K = 5)

evaluate_model_on_groups <- function(model_name, fit, test_groups) {
  
  if (model_name == "payoff_only_1p") {
    
    return(nll_payoff_only(test_groups, fit$tau))
    
  } else if (model_name == "static_precedent_payoff_2p") {
    
    return(nll_static_precedent_payoff(
      test_groups,
      fit$tau,
      fit$precedent_bonus
    ))
    
  } else if (model_name == "frequency_support_Vq_3p") {
    
    return(nll_social_support(
      test_groups,
      epsilon = fit$epsilon,
      tau = fit$tau,
      alpha = fit$alpha,
      exponent = 1
    ))
    
  } else if (model_name == "coord_support_Vq5_3p") {
    
    return(nll_social_support(
      test_groups,
      epsilon = fit$epsilon,
      tau = fit$tau,
      alpha = fit$alpha,
      exponent = 5
    ))
    
  } else if (model_name == "strategy_only_VS_3p") {
    
    return(nll_strategy_only(
      test_groups,
      epsilon = fit$epsilon,
      tau = fit$tau,
      theta = fit$theta,
      priorW = fixed_priorW
    ))
    
  } else if (model_name == "hybrid_calibrated_1p") {
    
    return(nll_hybrid(
      test_groups,
      epsilon = fixed_epsilon,
      tau = fixed_tau,
      theta = fixed_theta,
      alpha = fit$alpha,
      priorW = fixed_priorW
    ))
    
  } else if (model_name == "hybrid_4p_free_epsilon_tau_theta_alpha") {
    
    return(nll_hybrid(
      test_groups,
      epsilon = fit$epsilon,
      tau = fit$tau,
      theta = fit$theta,
      alpha = fit$alpha,
      priorW = fixed_priorW
    ))
    
  } else {
    stop(paste("Unknown model:", model_name))
  }
}

cv_results <- list()
row_idx <- 1

for (fold_id in 1:5) {
  
  cat("\nFold", fold_id, "\n")
  
  train_ids <- fold_assignments %>%
    filter(.data$fold != fold_id) %>%
    pull(group_uid)
  
  test_ids <- fold_assignments %>%
    filter(.data$fold == fold_id) %>%
    pull(group_uid)
  
  train_groups <- keep(group_data, ~ .x$group_uid %in% train_ids)
  test_groups  <- keep(group_data, ~ .x$group_uid %in% test_ids)
  
  test_obs <- sum(map_dbl(test_groups, function(gd) {
    sum(map_dbl(gd$rounds, "n"))
  }))
  
  for (m in names(fitters)) {
    
    cat("  Fitting:", m, "\n")
    
    fit <- fitters[[m]](train_groups)
    test_nll <- evaluate_model_on_groups(m, fit, test_groups)
    
    cv_results[[row_idx]] <- fit %>%
      mutate(
        fold = fold_id,
        test_nll = test_nll,
        test_obs = test_obs,
        test_nll_per_choice = test_nll / test_obs,
        n_train_groups = length(train_groups),
        n_test_groups = length(test_groups)
      )
    
    row_idx <- row_idx + 1
  }
}

cv_folds <- bind_rows(cv_results)

cv_summary <- cv_folds %>%
  group_by(model) %>%
  summarise(
    k = first(k),
    total_test_nll = sum(test_nll),
    mean_test_nll_per_choice = mean(test_nll_per_choice),
    sd_test_nll_per_choice = sd(test_nll_per_choice),
    .groups = "drop"
  ) %>%
  arrange(total_test_nll) %>%
  mutate(
    delta_cv_nll = total_test_nll - min(total_test_nll)
  )

cat("\nCV summary:\n")
print(cv_summary)

write_csv(
  cv_folds,
  file.path(out_dir, "model_family_group_cv_folds.csv")
)

write_csv(
  cv_summary,
  file.path(out_dir, "model_family_group_cv_summary.csv")
)

# -----------------------------
# 8. Visualizations
# -----------------------------

# Full-data AIC/BIC plot
full_long <- full_comparison %>%
  select(model, delta_AIC, delta_BIC) %>%
  pivot_longer(
    cols = c(delta_AIC, delta_BIC),
    names_to = "criterion",
    values_to = "delta"
  )

p_full <- ggplot(
  full_long,
  aes(x = reorder(model, delta), y = delta, fill = criterion)
) +
  geom_col(position = position_dodge(width = 0.8)) +
  coord_flip() +
  labs(
    title = "Model-family comparison: full-data AIC/BIC",
    x = "Model",
    y = "Delta from best",
    fill = "Criterion"
  ) +
  theme_minimal(base_size = 13)

print(p_full)

ggsave(
  file.path(out_dir, "model_family_full_delta_aic_bic.png"),
  p_full,
  width = 10,
  height = 6,
  dpi = 300
)

# Group-level CV plot
p_cv <- ggplot(
  cv_summary,
  aes(x = reorder(model, delta_cv_nll), y = delta_cv_nll)
) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Model-family comparison: group-level 5-fold CV",
    subtitle = "Lower held-out NLL is better",
    x = "Model",
    y = "Delta held-out NLL from best"
  ) +
  theme_minimal(base_size = 13)

print(p_cv)

ggsave(
  file.path(out_dir, "model_family_cv_delta_nll.png"),
  p_cv,
  width = 10,
  height = 6,
  dpi = 300
)

# Fold-level held-out performance
cv_folds$model <- factor(
  cv_folds$model,
  levels = cv_summary$model
)

p_fold <- ggplot(
  cv_folds,
  aes(x = model, y = test_nll_per_choice)
) +
  geom_point(size = 2.5, alpha = 0.8) +
  coord_flip() +
  labs(
    title = "Fold-level held-out performance",
    x = "Model",
    y = "Held-out NLL per choice"
  ) +
  theme_minimal(base_size = 13)

print(p_fold)

ggsave(
  file.path(out_dir, "model_family_cv_fold_points.png"),
  p_fold,
  width = 10,
  height = 6,
  dpi = 300
)

# -----------------------------
# 9. Save compact parameter table
# -----------------------------

parameter_table <- full_comparison %>%
  select(
    model,
    k,
    nll,
    AIC,
    BIC,
    delta_AIC,
    delta_BIC,
    any_of(c(
      "epsilon",
      "tau",
      "theta",
      "alpha",
      "priorW",
      "precedent_bonus"
    ))
  )

write_csv(
  parameter_table,
  file.path(out_dir, "model_family_parameter_table.csv")
)

cat("\nSaved outputs to:", out_dir, "\n")
cat("- model_family_full_comparison.csv\n")
cat("- model_family_group_cv_folds.csv\n")
cat("- model_family_group_cv_summary.csv\n")
cat("- model_family_parameter_table.csv\n")
cat("- model_family_full_delta_aic_bic.png\n")
cat("- model_family_cv_delta_nll.png\n")
cat("- model_family_cv_fold_points.png\n")

# ============================================================
# Robustness and Sanity Checks
# ============================================================

library(tidyverse)
library(ggplot2)

if (!exists("out_dir")) {
  out_dir <- file.path(getwd(), "model_comparison_outputs")
}

if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}

# ============================================================
# 1. Empirical treatment x round baseline
# ============================================================
#
# This is a near-saturated descriptive baseline.
# It asks: what NLL do we get if we simply predict the empirical
# choice distribution in each treatment x round cell?
#
# The cognitive model does NOT need to beat this.
# This is mostly an upper-bound/descriptive sanity check.
# ============================================================

empirical_round_probs <- model_data %>%
  count(treatment, round, choice_idx) %>%
  group_by(treatment, round) %>%
  mutate(p = n / sum(n)) %>%
  ungroup() %>%
  select(treatment, round, choice_idx, p)

model_data_emp <- model_data %>%
  left_join(
    empirical_round_probs,
    by = c("treatment", "round", "choice_idx")
  )

empirical_round_nll <- -sum(safe_log(model_data_emp$p))

cat("\n=== Empirical treatment x round baseline ===\n")
cat("Empirical treatment x round NLL:", empirical_round_nll, "\n")
cat("This baseline is near-saturated and not a cognitive model.\n")

write_csv(
  tibble(
    baseline = "empirical_treatment_round",
    nll = empirical_round_nll
  ),
  file.path(out_dir, "sanity_empirical_round_baseline.csv")
)

# ============================================================
# 2. Previous-round frequency baseline
# ============================================================
#
# This tests a simple social-copying alternative:
# predict current choices from previous observed group frequencies.
#
# In feedback: q updates after each round.
# In no-feedback: q updates through round 7, then freezes.
# ============================================================

nll_prev_round_frequency <- function(groups, alpha = 1) {
  
  nll <- 0
  
  for (gd in groups) {
    
    feedback <- gd$treatment == "feedback"
    q <- c(1/3, 1/3, 1/3)
    
    for (round in 1:14) {
      
      rr <- gd$rounds[[as.character(round)]]
      if (is.null(rr)) next
      
      probs <- q / sum(q)
      nll <- nll + nll_counts(rr$counts, probs)
      
      observe <- feedback || round <= 7
      
      if (observe) {
        q <- (rr$counts + alpha) / (rr$n + 3 * alpha)
      }
    }
  }
  
  nll
}

prev_freq_grid <- tidyr::crossing(
  alpha = c(0.1, 0.5, 1, 2, 5, 10, 20, 50, 100)
) %>%
  rowwise() %>%
  mutate(
    nll = nll_prev_round_frequency(group_data, alpha)
  ) %>%
  ungroup() %>%
  arrange(nll) %>%
  mutate(
    delta_nll = nll - min(nll)
  )

cat("\n=== Previous-round frequency baseline ===\n")
print(prev_freq_grid)

write_csv(
  prev_freq_grid,
  file.path(out_dir, "sanity_prev_round_frequency_baseline.csv")
)

# ============================================================
# 3. Repeated group-level CV: hybrid vs coordination-support
# ============================================================
#
# This checks whether the hybrid reliably beats the strongest
# non-Bayesian competitor across many random group-level splits.
# Positive delta means coordination-support has worse held-out NLL,
# so the hybrid is better.
# ============================================================

group_info <- tibble(
  group_uid = map_chr(group_data, "group_uid"),
  treatment = map_chr(group_data, "treatment")
)

make_folds_seeded <- function(group_info, K = 5, seed = 1) {
  
  set.seed(seed)
  
  group_info %>%
    group_by(treatment) %>%
    mutate(
      shuffled = sample(row_number()),
      fold = ((shuffled - 1) %% K) + 1
    ) %>%
    ungroup() %>%
    select(group_uid, fold)
}

run_one_cv_split <- function(seed) {
  
  fold_assignments <- make_folds_seeded(group_info, K = 5, seed = seed)
  
  rows <- list()
  row_idx <- 1
  
  for (fold_id in 1:5) {
    
    train_ids <- fold_assignments %>%
      filter(.data$fold != fold_id) %>%
      pull(group_uid)
    
    test_ids <- fold_assignments %>%
      filter(.data$fold == fold_id) %>%
      pull(group_uid)
    
    train_groups <- keep(group_data, ~ .x$group_uid %in% train_ids)
    test_groups  <- keep(group_data, ~ .x$group_uid %in% test_ids)
    
    # Hybrid calibrated 1p
    fit_h <- fit_hybrid_calibrated_1p(train_groups)
    
    nll_h <- nll_hybrid(
      test_groups,
      epsilon = fixed_epsilon,
      tau = fixed_tau,
      theta = fixed_theta,
      alpha = fit_h$alpha,
      priorW = fixed_priorW
    )
    
    # Coordination-support competitor
    fit_c <- fit_coord_support(train_groups)
    
    nll_c <- nll_social_support(
      test_groups,
      epsilon = fit_c$epsilon,
      tau = fit_c$tau,
      alpha = fit_c$alpha,
      exponent = 5
    )
    
    rows[[row_idx]] <- tibble(
      seed = seed,
      fold = fold_id,
      hybrid_test_nll = nll_h,
      coord_test_nll = nll_c,
      delta_coord_minus_hybrid = nll_c - nll_h,
      hybrid_alpha = fit_h$alpha,
      coord_epsilon = fit_c$epsilon,
      coord_tau = fit_c$tau,
      coord_alpha = fit_c$alpha
    )
    
    row_idx <- row_idx + 1
  }
  
  bind_rows(rows)
}

n_cv_repeats <- 50

cv_repeats <- map_dfr(1:n_cv_repeats, run_one_cv_split)

cv_repeat_summary <- cv_repeats %>%
  group_by(seed) %>%
  summarise(
    hybrid_total_nll = sum(hybrid_test_nll),
    coord_total_nll = sum(coord_test_nll),
    delta_coord_minus_hybrid = coord_total_nll - hybrid_total_nll,
    mean_hybrid_alpha = mean(hybrid_alpha),
    .groups = "drop"
  )

cat("\n=== Repeated group-level CV: coordination-support minus hybrid ===\n")
print(summary(cv_repeat_summary$delta_coord_minus_hybrid))

cat("\nProportion of splits where hybrid beats coordination-support:\n")
print(mean(cv_repeat_summary$delta_coord_minus_hybrid > 0))

write_csv(
  cv_repeats,
  file.path(out_dir, "sanity_repeated_cv_fold_results_hybrid_vs_coord.csv")
)

write_csv(
  cv_repeat_summary,
  file.path(out_dir, "sanity_repeated_cv_summary_hybrid_vs_coord.csv")
)

p_cv_repeat <- ggplot(
  cv_repeat_summary,
  aes(x = delta_coord_minus_hybrid)
) +
  geom_histogram(bins = 25, color = "white") +
  geom_vline(xintercept = 0, linetype = "dashed") +
  labs(
    title = "Repeated group-level CV: coordination-support minus hybrid",
    subtitle = "Positive values mean the calibrated hybrid has better held-out prediction",
    x = "Held-out NLL difference",
    y = "Number of CV splits"
  ) +
  theme_minimal(base_size = 13)

print(p_cv_repeat)

ggsave(
  file.path(out_dir, "sanity_repeated_cv_hybrid_vs_coord.png"),
  p_cv_repeat,
  width = 8,
  height = 5,
  dpi = 300
)

# ============================================================
# 4. Group-level outcome sanity checks
# ============================================================
#
# These summarize the empirical group-level phenomena the model should
# eventually reproduce in forward simulation.
# ============================================================

observed_group_rounds <- model_data %>%
  group_by(group_uid, treatment, round) %>%
  summarise(
    n = n(),
    n_J = sum(letter_choice == "J"),
    n_M = sum(letter_choice == "M"),
    n_N = sum(letter_choice == "N"),
    n_switch = sum(letter_choice != "J"),
    switch_rate = mean(letter_choice != "J"),
    .groups = "drop"
  )

observed_group_outcomes <- observed_group_rounds %>%
  group_by(group_uid, treatment) %>%
  summarise(
    final_switch_rate = switch_rate[round == 14],
    
    ever_switched_post8 = any(n_switch > 0 & round >= 8),
    
    first_switch_round = ifelse(
      any(n_switch > 0 & round >= 8),
      min(round[n_switch > 0 & round >= 8]),
      NA_real_
    ),
    
    majority_switch_round = ifelse(
      any(n_switch >= 4 & round >= 8),
      min(round[n_switch >= 4 & round >= 8]),
      NA_real_
    ),
    
    final_n_switch = n_switch[round == 14],
    
    final_target_concentration = {
      m <- n_M[round == 14]
      n <- n_N[round == 14]
      if ((m + n) == 0) {
        NA_real_
      } else {
        max(m, n) / (m + n)
      }
    },
    
    .groups = "drop"
  )

group_outcome_summary <- observed_group_outcomes %>%
  group_by(treatment) %>%
  summarise(
    n_groups = n(),
    mean_final_switch = mean(final_switch_rate, na.rm = TRUE),
    prop_ever_switched_post8 = mean(ever_switched_post8, na.rm = TRUE),
    mean_first_switch_round = mean(first_switch_round, na.rm = TRUE),
    mean_majority_switch_round = mean(majority_switch_round, na.rm = TRUE),
    prop_majority_switch_by_final = mean(final_n_switch >= 4, na.rm = TRUE),
    mean_final_target_concentration = mean(final_target_concentration, na.rm = TRUE),
    .groups = "drop"
  )

cat("\n=== Observed group-level outcome summary ===\n")
print(group_outcome_summary)

write_csv(
  observed_group_outcomes,
  file.path(out_dir, "sanity_observed_group_outcomes.csv")
)

write_csv(
  group_outcome_summary,
  file.path(out_dir, "sanity_observed_group_outcome_summary.csv")
)

p_final_switch <- ggplot(
  observed_group_outcomes,
  aes(x = final_switch_rate, fill = treatment)
) +
  geom_histogram(
    binwidth = 1/6,
    boundary = 0,
    alpha = 0.65,
    position = "identity"
  ) +
  scale_x_continuous(breaks = seq(0, 1, by = 1/6)) +
  labs(
    title = "Observed distribution of final-round switching by group",
    x = "Final-round switching rate",
    y = "Number of groups",
    fill = "Condition"
  ) +
  theme_minimal(base_size = 13)

print(p_final_switch)

ggsave(
  file.path(out_dir, "sanity_observed_final_switch_distribution.png"),
  p_final_switch,
  width = 8,
  height = 5,
  dpi = 300
)

p_first_switch <- ggplot(
  observed_group_outcomes %>% filter(!is.na(first_switch_round)),
  aes(x = first_switch_round, fill = treatment)
) +
  geom_histogram(
    binwidth = 1,
    alpha = 0.65,
    position = "identity"
  ) +
  scale_x_continuous(breaks = 8:14) +
  labs(
    title = "Observed first-switch round by group",
    x = "First round with at least one switcher",
    y = "Number of groups",
    fill = "Condition"
  ) +
  theme_minimal(base_size = 13)


print(p_first_switch)

ggsave(
  file.path(out_dir, "sanity_observed_first_switch_round_distribution.png"),
  p_first_switch,
  width = 8,
  height = 5,
  dpi = 300
)

# ============================================================
# 5. Ablation checks
# ============================================================
#
# These are simpler than the full broad comparison and easier to present:
#
# - Full calibrated hybrid
# - No strategy term: coordination-support only
# - No implementation term: strategy-only
# - No proposal term: epsilon = 0
# - No Bayesian updating after round 8
#
# The point is to show which pieces matter.
# ============================================================

nll_hybrid_no_bayes_update <- function(groups, epsilon, tau, theta, alpha, priorW = fixed_priorW) {
  
  nll <- 0
  
  for (gd in groups) {
    
    feedback <- gd$treatment == "feedback"
    q <- c(1/3, 1/3, 1/3)
    PW <- NA_real_
    PTM <- NA_real_
    
    for (round in 1:14) {
      
      rr <- gd$rounds[[as.character(round)]]
      if (is.null(rr)) next
      
      if (round <= 7) {
        
        V <- c(10, 0, 0)
        Q <- V * (q ^ 5)
        
        exploit_probs <- softmax(tau * Q)
        explore_probs <- V / sum(V)
        probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
        probs <- probs / sum(probs)
        
        nll <- nll + nll_counts(rr$counts, probs)
        
        q <- (rr$counts + alpha) / (rr$n + 3 * alpha)
        next
      }
      
      if (round == 8) {
        PW <- priorW
        PTM <- 0.5
      }
      
      V <- c(10, 15, 15)
      Q <- c(
        10 * (1 - PW) * (q[1] ^ 5),
        15 * PW * PTM * (q[2] ^ 5),
        15 * PW * (1 - PTM) * (q[3] ^ 5)
      )
      
      exploit_probs <- softmax(tau * Q)
      explore_probs <- V / sum(V)
      probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
      probs <- probs / sum(probs)
      
      nll <- nll + nll_counts(rr$counts, probs)
      
      # q still updates with feedback, but PW/PTM do not.
      if (feedback) {
        q <- (rr$counts + alpha) / (rr$n + 3 * alpha)
      }
    }
  }
  
  nll
}

# Fit alpha for calibrated hybrid
fit_full_calibrated <- fit_hybrid_calibrated_1p(group_data)

# Fit alpha for no Bayesian update
fit_no_bayes <- tidyr::crossing(alpha = alpha_grid) %>%
  rowwise() %>%
  mutate(
    nll = nll_hybrid_no_bayes_update(
      group_data,
      epsilon = fixed_epsilon,
      tau = fixed_tau,
      theta = fixed_theta,
      alpha = alpha,
      priorW = fixed_priorW
    )
  ) %>%
  ungroup() %>%
  arrange(nll) %>%
  slice(1) %>%
  mutate(
    model = "hybrid_no_bayes_update",
    k = 1,
    epsilon = fixed_epsilon,
    tau = fixed_tau,
    theta = fixed_theta,
    priorW = fixed_priorW
  )

# No proposal term: epsilon = 0, fit alpha only
fit_no_proposal <- tidyr::crossing(alpha = alpha_grid) %>%
  rowwise() %>%
  mutate(
    nll = nll_hybrid(
      group_data,
      epsilon = 0,
      tau = fixed_tau,
      theta = fixed_theta,
      alpha = alpha,
      priorW = fixed_priorW
    )
  ) %>%
  ungroup() %>%
  arrange(nll) %>%
  slice(1) %>%
  mutate(
    model = "hybrid_no_proposal_epsilon0",
    k = 1,
    epsilon = 0,
    tau = fixed_tau,
    theta = fixed_theta,
    priorW = fixed_priorW
  )

# Coordination-only, using existing fitter
fit_coord <- fit_coord_support(group_data)

# Strategy-only, using calibrated fixed epsilon/tau/theta
fit_strategy_calibrated <- tibble(
  model = "strategy_only_calibrated",
  k = 0,
  epsilon = fixed_epsilon,
  tau = fixed_tau,
  theta = fixed_theta,
  priorW = fixed_priorW,
  nll = nll_strategy_only(
    group_data,
    epsilon = fixed_epsilon,
    tau = fixed_tau,
    theta = fixed_theta,
    priorW = fixed_priorW
  )
)

ablation_results <- bind_rows(
  fit_full_calibrated %>%
    mutate(model = "hybrid_calibrated_full"),
  fit_coord %>%
    mutate(model = "no_strategy_coord_support"),
  fit_strategy_calibrated,
  fit_no_bayes,
  fit_no_proposal
) %>%
  mutate(
    AIC = 2 * k + 2 * nll,
    BIC = k * log(nrow(model_data)) + 2 * nll
  ) %>%
  arrange(nll) %>%
  mutate(
    delta_nll = nll - min(nll),
    delta_AIC = AIC - min(AIC),
    delta_BIC = BIC - min(BIC)
  )

cat("\n=== Ablation results ===\n")
print(ablation_results)

write_csv(
  ablation_results,
  file.path(out_dir, "sanity_ablation_results.csv")
)

p_ablation <- ggplot(
  ablation_results,
  aes(x = reorder(model, delta_nll), y = delta_nll)
) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Ablation checks",
    subtitle = "Delta NLL relative to best; lower is better",
    x = "Model",
    y = "Delta NLL"
  ) +
  theme_minimal(base_size = 13)

print(p_ablation)

ggsave(
  file.path(out_dir, "sanity_ablation_delta_nll.png"),
  p_ablation,
  width = 8,
  height = 5,
  dpi = 300
)

# ============================================================
# 6. Cross-validated calibration of switching predictions
# ============================================================
#
# This is stronger than in-sample calibration.
# It fits alpha on training groups and predicts held-out groups.
# ============================================================

predict_hybrid_group_round <- function(groups, alpha) {
  
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
  
  for (gd in groups) {
    
    treatment <- gd$treatment
    feedback <- treatment == "feedback"
    
    q <- c(1/3, 1/3, 1/3)
    PW <- NA_real_
    PTM <- NA_real_
    
    for (round in 1:14) {
      
      rr <- gd$rounds[[as.character(round)]]
      if (is.null(rr)) next
      
      if (round <= 7) {
        
        V <- c(10, 0, 0)
        Q <- V * (q ^ 5)
        
        exploit_probs <- softmax(tau * Q)
        explore_probs <- V / sum(V)
        probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
        probs <- probs / sum(probs)
        
      } else {
        
        if (round == 8) {
          PW <- priorW
          PTM <- 0.5
        }
        
        V <- c(10, 15, 15)
        Q <- c(
          10 * (1 - PW) * (q[1] ^ 5),
          15 * PW * PTM * (q[2] ^ 5),
          15 * PW * (1 - PTM) * (q[3] ^ 5)
        )
        
        exploit_probs <- softmax(tau * Q)
        explore_probs <- V / sum(V)
        probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
        probs <- probs / sum(probs)
      }
      
      pred_rows[[row_idx]] <- tibble(
        group_uid = gd$group_uid,
        treatment = treatment,
        round = round,
        pred_J = probs[1],
        pred_M = probs[2],
        pred_N = probs[3],
        pred_switch = probs[2] + probs[3]
      )
      
      row_idx <- row_idx + 1
      
      observe <- feedback || round <= 7
      
      if (observe) {
        
        counts <- rr$counts
        
        q <- (counts + alpha) / (rr$n + 3 * alpha)
        
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

# Create one CV split for calibration
fold_assignments_cal <- make_folds_seeded(group_info, K = 5, seed = 999)

cv_pred_rows <- list()
row_idx <- 1

for (fold_id in 1:5) {
  
  train_ids <- fold_assignments_cal %>%
    filter(.data$fold != fold_id) %>%
    pull(group_uid)
  
  test_ids <- fold_assignments_cal %>%
    filter(.data$fold == fold_id) %>%
    pull(group_uid)
  
  train_groups <- keep(group_data, ~ .x$group_uid %in% train_ids)
  test_groups  <- keep(group_data, ~ .x$group_uid %in% test_ids)
  
  fit_h <- fit_hybrid_calibrated_1p(train_groups)
  
  preds <- predict_hybrid_group_round(test_groups, alpha = fit_h$alpha) %>%
    mutate(
      fold = fold_id,
      fitted_alpha = fit_h$alpha
    )
  
  cv_pred_rows[[row_idx]] <- preds
  row_idx <- row_idx + 1
}

cv_group_round_preds <- bind_rows(cv_pred_rows)

cv_trial_preds <- model_data %>%
  select(group_uid, treatment, round, participant_id, switched) %>%
  inner_join(
    cv_group_round_preds %>%
      select(group_uid, round, pred_switch, fold, fitted_alpha),
    by = c("group_uid", "round")
  )

cv_calibration <- cv_trial_preds %>%
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

cat("\n=== Cross-validated switching calibration ===\n")
print(cv_calibration)

write_csv(
  cv_calibration,
  file.path(out_dir, "sanity_cv_switch_calibration.csv")
)

write_csv(
  cv_trial_preds,
  file.path(out_dir, "sanity_cv_trial_level_predictions.csv")
)

p_cv_calibration <- ggplot(
  cv_calibration,
  aes(x = mean_pred, y = observed_switch)
) +
  geom_point(aes(size = n), alpha = 0.8) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  scale_x_continuous(limits = c(0, 1)) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(
    title = "Cross-validated calibration of predicted switching",
    subtitle = "Predictions generated for held-out groups",
    x = "Mean predicted P(choice != J)",
    y = "Observed switching rate",
    size = "N trials"
  ) +
  theme_minimal(base_size = 13)

print(p_cv_calibration)

ggsave(
  file.path(out_dir, "sanity_cv_switch_calibration.png"),
  p_cv_calibration,
  width = 6,
  height = 5.5,
  dpi = 300
)

cat("\nSaved sanity check outputs to:", out_dir, "\n")

# ============================================================
# Better ablation visualizations
# ============================================================

library(tidyverse)
library(ggplot2)
library(scales)

# Clean labels and compute deltas
ablation_plot_data <- ablation_results %>%
  mutate(
    model_label = case_when(
      model == "hybrid_calibrated_full" ~ "Full calibrated hybrid",
      model == "hybrid_no_proposal_epsilon0" ~ "No proposal term",
      model == "hybrid_no_bayes_update" ~ "No Bayesian\nstrategy update",
      model == "no_strategy_coord_support" ~ "No strategy term\n(coordination only)",
      model == "strategy_only_calibrated" ~ "No implementation support\n(strategy only)",
      TRUE ~ model
    ),
    delta_nll = nll - min(nll),
    model_label = factor(
      model_label,
      levels = c(
        "Full calibrated hybrid",
        "No proposal term",
        "No Bayesian\nstrategy update",
        "No strategy term\n(coordination only)",
        "No implementation support\n(strategy only)"
      )
    )
  )

# -----------------------------
# 1. Main ablation plot, excluding catastrophic strategy-only model
# -----------------------------

ablation_main <- ablation_plot_data %>%
  filter(model != "strategy_only_calibrated")

p_ablation_main <- ggplot(
  ablation_main,
  aes(x = model_label, y = delta_nll)
) +
  geom_col(width = 0.65, fill = "grey35") +
  geom_text(
    aes(label = round(delta_nll, 1)),
    hjust = -0.15,
    size = 4
  ) +
  coord_flip(clip = "off") +
  scale_y_continuous(
    limits = c(0, max(ablation_main$delta_nll) * 1.18),
    expand = expansion(mult = c(0, 0.05))
  ) +
  labs(
    title = "Ablation checks",
 
    x = NULL,
    y = expression(Delta~"NLL relative to full hybrid")
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.margin = margin(10, 30, 10, 10),
    panel.grid.major.y = element_blank()
  )

print(p_ablation_main)


# -----------------------------
# 2. Separate plot showing catastrophic strategy-only failure
# -----------------------------

p_ablation_all_log <- ggplot(
  ablation_plot_data,
  aes(x = model_label, y = delta_nll + 1)
) +
  geom_col(width = 0.65, fill = "grey35") +
  geom_text(
    aes(label = round(delta_nll, 1)),
    hjust = -0.1,
    size = 3.5
  ) +
  coord_flip(clip = "off") +
  scale_y_log10(
    labels = label_number(),
    breaks = c(1, 10, 100, 1000, 10000)
  ) +
  labs(
    title = "Ablation checks including catastrophic strategy-only model",
    subtitle = "Log scale; plotted as Delta NLL + 1",
    x = NULL,
    y = expression(log[10]~(Delta~"NLL + 1"))
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.margin = margin(10, 40, 10, 10),
    panel.grid.major.y = element_blank()
  )

print(p_ablation_all_log)

ggsave(
  file.path(out_dir, "sanity_ablation_delta_nll_all_log.png"),
  p_ablation_all_log,
  width = 8.5,
  height = 5.2,
  dpi = 300
)

# -----------------------------
# 3. Simple table-style plot: NLL and delta NLL
# -----------------------------

ablation_table_plot <- ablation_plot_data %>%
  mutate(
    label = paste0(
      "NLL = ", round(nll, 1),
      "\nΔNLL = ", round(delta_nll, 1)
    )
  )

p_ablation_table <- ggplot(
  ablation_table_plot,
  aes(x = 1, y = fct_rev(model_label))
) +
  geom_text(
    aes(label = label),
    hjust = 0,
    size = 4
  ) +
  xlim(1, 2.4) +
  labs(
    title = "Ablation summary",
    x = NULL,
    y = NULL
  ) +
  theme_void(base_size = 13) +
  theme(
    axis.text.y = element_text(size = 12),
    plot.title = element_text(face = "bold")
  )

print(p_ablation_table)

ggsave(
  file.path(out_dir, "sanity_ablation_summary_table_plot.png"),
  p_ablation_table,
  width = 7,
  height = 4.5,
  dpi = 300
)

# ============================================================
# Better Parameter Recovery for Calibrated Hybrid Model
# ============================================================
#
# Goal:
#   Test whether alpha is recoverable when all other parameters
#   are fixed/calibrated.
#
# Fixed:
#   epsilon = .04
#   tau     = 90
#   theta   = .52
#   priorW  = .69
#
# Recovered:
#   alpha
#
# Improvements over crude grid recovery:
#   - Uses continuous optimization over log(alpha)
#   - Tests several true alpha values near and far from fitted value
#   - Reports bias, RMSE, MAE, Spearman/Pearson correlations
#   - Produces recovery scatter, boxplot, and profile likelihood plots
# ============================================================

library(tidyverse)
library(ggplot2)

if (!exists("out_dir")) {
  out_dir <- file.path(normalizePath(getwd()), "model_comparison_outputs")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}

set.seed(2026)

# -----------------------------
# 1. Simulate one dataset
# -----------------------------

simulate_hybrid_dataset <- function(
    group_data,
    alpha_true,
    epsilon = fixed_epsilon,
    tau = fixed_tau,
    theta = fixed_theta,
    priorW = fixed_priorW
) {
  
  p_choice_given_P <- c(theta, (1 - theta) / 2, (1 - theta) / 2)
  p_choice_given_W <- c(1 - theta, theta / 2, theta / 2)
  
  # Relative target scores, not normalized probabilities.
  target_score_TM <- c(1, theta, 1 - theta)
  target_score_TN <- c(1, 1 - theta, theta)
  
  logP  <- safe_log(p_choice_given_P)
  logW  <- safe_log(p_choice_given_W)
  logTM <- safe_log(target_score_TM)
  logTN <- safe_log(target_score_TN)
  
  sim_rows <- list()
  row_idx <- 1
  
  for (gd in group_data) {
    
    treatment <- gd$treatment
    feedback <- treatment == "feedback"
    group_uid <- gd$group_uid
    
    q <- c(1/3, 1/3, 1/3)
    PW <- NA_real_
    PTM <- NA_real_
    
    for (round in 1:14) {
      
      rr <- gd$rounds[[as.character(round)]]
      if (is.null(rr)) next
      
      n <- rr$n
      
      if (round <= 7) {
        
        V <- c(10, 0, 0)
        Q <- V * (q ^ 5)
        
        exploit_probs <- softmax(tau * Q)
        explore_probs <- V / sum(V)
        
        probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
        probs <- probs / sum(probs)
        
      } else {
        
        if (round == 8) {
          PW <- priorW
          PTM <- 0.5
        }
        
        V <- c(10, 15, 15)
        
        Q <- c(
          10 * (1 - PW) * (q[1] ^ 5),
          15 * PW * PTM * (q[2] ^ 5),
          15 * PW * (1 - PTM) * (q[3] ^ 5)
        )
        
        exploit_probs <- softmax(tau * Q)
        explore_probs <- V / sum(V)
        
        probs <- (1 - epsilon) * exploit_probs + epsilon * explore_probs
        probs <- probs / sum(probs)
      }
      
      counts <- as.vector(rmultinom(n = 1, size = n, prob = probs))
      
      sim_rows[[row_idx]] <- tibble(
        group_uid = group_uid,
        treatment = treatment,
        round = round,
        n = n,
        n_J = counts[1],
        n_M = counts[2],
        n_N = counts[3]
      )
      
      row_idx <- row_idx + 1
      
      # Public evidence update
      observe <- feedback || round <= 7
      
      if (observe) {
        
        q <- (counts + alpha_true) / (n + 3 * alpha_true)
        
        if (round >= 8) {
          
          # P(W) update
          log_lik_P <- sum(counts * logP)
          log_lik_W <- sum(counts * logW)
          
          log_post_W <- log(PW) + log_lik_W
          log_post_P <- log(1 - PW) + log_lik_P
          
          mx <- max(log_post_W, log_post_P)
          
          PW <- exp(log_post_W - mx) /
            (exp(log_post_W - mx) + exp(log_post_P - mx))
          
          # P(T=M | W) update
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
  
  bind_rows(sim_rows)
}

# -----------------------------
# 2. Convert simulated counts to group_data format
# -----------------------------

sim_counts_to_group_data <- function(sim_counts) {
  
  sim_counts %>%
    group_by(group_uid, treatment) %>%
    group_split() %>%
    map(function(g) {
      
      round_list <- list()
      
      for (i in seq_len(nrow(g))) {
        
        r <- g$round[i]
        counts <- c(g$n_J[i], g$n_M[i], g$n_N[i])
        
        round_list[[as.character(r)]] <- list(
          counts = counts,
          n = sum(counts)
        )
      }
      
      list(
        group_uid = unique(g$group_uid),
        treatment = unique(g$treatment),
        rounds = round_list
      )
    })
}

# -----------------------------
# 3. Continuous alpha fitting
# -----------------------------

nll_alpha_log <- function(log_alpha, sim_group_data) {
  
  alpha <- exp(log_alpha)
  
  nll_hybrid(
    sim_group_data,
    epsilon = fixed_epsilon,
    tau = fixed_tau,
    theta = fixed_theta,
    alpha = alpha,
    priorW = fixed_priorW
  )
}

fit_alpha_continuous <- function(
    sim_group_data,
    lower_alpha = 1,
    upper_alpha = 200,
    starts_alpha = c(5, 10, 20, 23, 40, 80, 120)
) {
  
  fits <- map(starts_alpha, function(start_alpha) {
    
    optim(
      par = log(start_alpha),
      fn = nll_alpha_log,
      sim_group_data = sim_group_data,
      method = "L-BFGS-B",
      lower = log(lower_alpha),
      upper = log(upper_alpha),
      control = list(maxit = 1000)
    )
  })
  
  best <- fits[[which.min(map_dbl(fits, "value"))]]
  
  tibble(
    alpha_hat = exp(best$par[1]),
    nll = best$value,
    convergence = best$convergence
  )
}

# -----------------------------
# 4. Run recovery experiment
# -----------------------------

alpha_true_values <- c(8, 12, 18, 23, 30, 45, 70, 100)
n_reps_per_alpha <- 50

recovery_results <- list()
row_idx <- 1

for (alpha_true in alpha_true_values) {
  
  cat("\nTrue alpha:", alpha_true, "\n")
  
  for (rep_id in 1:n_reps_per_alpha) {
    
    sim_counts <- simulate_hybrid_dataset(
      group_data = group_data,
      alpha_true = alpha_true
    )
    
    sim_group_data <- sim_counts_to_group_data(sim_counts)
    
    fit <- fit_alpha_continuous(sim_group_data)
    
    recovery_results[[row_idx]] <- tibble(
      alpha_true = alpha_true,
      rep = rep_id,
      alpha_hat = fit$alpha_hat,
      nll = fit$nll,
      convergence = fit$convergence
    )
    
    row_idx <- row_idx + 1
  }
}

recovery_results <- bind_rows(recovery_results)



# -----------------------------
# 5. Recovery summary
# -----------------------------

recovery_summary <- recovery_results %>%
  group_by(alpha_true) %>%
  summarise(
    n_reps = n(),
    mean_hat = mean(alpha_hat),
    median_hat = median(alpha_hat),
    sd_hat = sd(alpha_hat),
    bias = mean(alpha_hat - alpha_true),
    abs_bias = abs(mean(alpha_hat - alpha_true)),
    mae = mean(abs(alpha_hat - alpha_true)),
    rmse = sqrt(mean((alpha_hat - alpha_true)^2)),
    mean_ratio = mean(alpha_hat / alpha_true),
    median_ratio = median(alpha_hat / alpha_true),
    prop_converged = mean(convergence == 0),
    .groups = "drop"
  )

print(recovery_summary)

write_csv(
  recovery_summary,
  file.path(out_dir, "parameter_recovery_alpha_continuous_summary.csv")
)

# ============================================================
# Visualize alpha parameter recovery
# ============================================================

library(tidyverse)
library(ggplot2)

# -----------------------------
# 1. Recovery scatter with median recovered alpha
# -----------------------------

p_recovery_scatter <- ggplot(
  recovery_results,
  aes(x = alpha_true, y = alpha_hat)
) +
  geom_jitter(width = 0.7, height = 0, alpha = 0.30, size = 1.8) +
  stat_summary(
    fun = median,
    geom = "point",
    size = 4
  ) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = sort(unique(recovery_results$alpha_true))) +
  labs(
    title = "Parameter recovery for alpha",
    subtitle = "Points are simulated datasets",
    x = "True alpha",
    y = "Recovered alpha"
  ) +
  theme_minimal(base_size = 13)

print(p_recovery_scatter)


# -----------------------------
# 2. Boxplot by true alpha
# -----------------------------

p_recovery_box <- ggplot(
  recovery_results,
  aes(x = factor(alpha_true), y = alpha_hat)
) +
  geom_boxplot(outlier.alpha = 0.35) +
  stat_summary(
    fun = median,
    geom = "point",
    size = 3
  ) +
  labs(
    title = "Distribution of recovered alpha values",
    subtitle = "Recovery is tight near the empirical estimate alpha ≈ 23",
    x = "True alpha",
    y = "Recovered alpha"
  ) +
  theme_minimal(base_size = 13)

print(p_recovery_box)


# -----------------------------
# 3. Mean/median recovered alpha with uncertainty
# -----------------------------

recovery_summary_plot <- recovery_results %>%
  group_by(alpha_true) %>%
  summarise(
    mean_hat = mean(alpha_hat),
    median_hat = median(alpha_hat),
    lo = quantile(alpha_hat, 0.05),
    hi = quantile(alpha_hat, 0.95),
    .groups = "drop"
  )

p_recovery_summary <- ggplot(
  recovery_summary_plot,
  aes(x = alpha_true, y = median_hat)
) +
  geom_ribbon(
    aes(ymin = lo, ymax = hi),
    alpha = 0.18
  ) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  scale_x_continuous(breaks = sort(unique(recovery_results$alpha_true))) +
  labs(
    title = "Alpha recovery summary",
    subtitle = "Line = median recovered alpha; ribbon = 90% recovery interval",
    x = "True alpha",
    y = "Recovered alpha"
  ) +
  theme_minimal(base_size = 13)

print(p_recovery_summary)


# -----------------------------
# 4. Bias plot
# -----------------------------

bias_summary <- recovery_results %>%
  group_by(alpha_true) %>%
  summarise(
    mean_bias = mean(alpha_hat - alpha_true),
    lo = quantile(alpha_hat - alpha_true, 0.05),
    hi = quantile(alpha_hat - alpha_true, 0.95),
    .groups = "drop"
  )

p_bias <- ggplot(
  bias_summary,
  aes(x = alpha_true, y = mean_bias)
) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_ribbon(
    aes(ymin = lo, ymax = hi),
    alpha = 0.18
  ) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = sort(unique(recovery_results$alpha_true))) +
  labs(
    title = "Parameter recovery bias",
    subtitle = "Mean recovered alpha minus true alpha",
    x = "True alpha",
    y = "Recovery bias"
  ) +
  theme_minimal(base_size = 13)

print(p_bias)


# -----------------------------
# 5. Log-scale recovery plot
# -----------------------------
# Useful because alpha is positive and recovery variance grows at high alpha.

p_recovery_log <- ggplot(
  recovery_results,
  aes(x = alpha_true, y = alpha_hat)
) +
  geom_jitter(width = 0.02, height = 0, alpha = 0.30, size = 1.8) +
  stat_summary(
    fun = median,
    geom = "point",
    size = 4
  ) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  scale_x_log10(breaks = sort(unique(recovery_results$alpha_true))) +
  scale_y_log10(breaks = sort(unique(recovery_results$alpha_true))) +
  labs(
    title = "Parameter recovery for alpha, log scale",
    subtitle = "Good recovery means medians track the dashed line",
    x = "True alpha",
    y = "Recovered alpha"
  ) +
  theme_minimal(base_size = 13)

print(p_recovery_log)

pearson_cor <- cor(
  recovery_results$alpha_true,
  recovery_results$alpha_hat,
  method = "pearson"
)

spearman_cor <- cor(
  recovery_results$alpha_true,
  recovery_results$alpha_hat,
  method = "spearman"
)

cat("\nPearson correlation:", pearson_cor, "\n")
cat("Spearman correlation:", spearman_cor, "\n")

cor_summary <- tibble(
  pearson_cor = pearson_cor,
  spearman_cor = spearman_cor
)

write_csv(
  cor_summary,
  file.path(out_dir, "parameter_recovery_alpha_correlations.csv")
)

