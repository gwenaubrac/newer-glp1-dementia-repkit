# =============================================================================
# 20-competing-events.R - death as a competing event (Aalen-Johansen)
# =============================================================================
# Sensitivity analysis for the primary analysis (ITT, overlap weights) that
# treats death as a competing event instead of a censoring event. For each
# cohort we fit an overlap-weighted Aalen-Johansen estimator of the cumulative
# incidence of all-cause dementia and of death, and report the risks, risk
# difference, and risk ratio at the end of follow-up (2 years after index).
# 95% CIs come from a nonparametric bootstrap that re-estimates the propensity
# score and overlap weights in each resample.
#
# The cohort and follow-up definitions match the primary ITT analysis in
# 18-run-survival-analyses.qmd (follow-up starts index + 90 days, ends at
# coverage end, study end, or 2 years after index; patients with dementia
# before the start of follow-up or with no follow-up after day 90 are
# excluded). The only differences are:
#   - death ends follow-up as a competing event rather than as censoring;
#   - dementia recorded on the same day as death counts as dementia.
#
# Cohorts:
#   - data1: novel GLP1 (sema + tirze) vs SGLT2
#   - data2: novel GLP1 vs DPP4
#   - data3: novel GLP1 vs sulfo
#
# Runs only for the sens10_competing_risk scenario (see sensitivity.R):
#   Rscript run_sensitivity.R --scenario sens10_competing_risk
# Results are saved in results/sens10_competing_risk/. Manuscript e-table 6 and
# e-figure 1 are written only on that scenario run. When sourced
# interactively the analysis always runs, writing results to RESULTS_DIR.
#
# Number of bootstrap resamples can be changed with the AJ_BOOT_REPS env var
# (default 500).
# =============================================================================

#### SETUP ####
library(dplyr)
library(magrittr)
library(lubridate)
library(survival)
library(broom)
library(ggplot2)
library(patchwork)
library(openxlsx)

project_root <- Sys.getenv("PROJECT_ROOT")
if (nchar(project_root) == 0) stop("PROJECT_ROOT is not set. To run this file directly in an R session, source code/00-setup.R first in the same session (it loads .Renviron). Otherwise launch the full pipeline via run_all.R / run_all.command / run_all.bat.")
output_dir      <- Sys.getenv("OUTPUT_DIR",      unset = file.path(project_root, "output"))
main_output_dir <- Sys.getenv("MAIN_OUTPUT_DIR", unset = output_dir)
results_dir <- Sys.getenv("RESULTS_DIR", unset = file.path(project_root, "results", "main"))
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- function(name) {
  p <- normalizePath(file.path(output_dir, name), winslash = "/", mustWork = FALSE)
  if (file.exists(p)) return(p)
  normalizePath(file.path(main_output_dir, name), winslash = "/", mustWork = FALSE)
}

source(file.path(project_root, "sensitivity.R"))
SCENARIO <- get_scenario()

if (!isTRUE(SCENARIO$competing_risk)) {
  message("Skipping 20-competing-events.R: it only runs for the competing-risk ",
          "scenario (Rscript run_sensitivity.R --scenario sens10_competing_risk).")
  if (!interactive()) quit(save = "no", status = 0)
}

# Manuscript outputs are only written by the scenario run itself, so an
# interactive exploratory run never overwrites them. Requires both signals to
# agree, as in the is_main checks of 18/19.
write_manuscript <- identical(Sys.getenv("SCENARIO_NAME"), "sens10_competing_risk") &&
                    identical(basename(results_dir), "sens10_competing_risk")
manuscript_tab_dir <- file.path(project_root, "manuscript", "tables")
manuscript_fig_dir <- file.path(project_root, "manuscript", "figures")

data1    <- readRDS(out_path("data1_novel.rds"))
data2    <- readRDS(out_path("data2_novel.rds"))
data3    <- readRDS(out_path("data3_novel.rds"))
cov_list <- readRDS(out_path("cov_list_novel.rds"))

end_date <- ymd(Sys.getenv("STUDY_END", unset = "2025-12-31"))
max_fu <- 730 # truncate follow-up up to 2 years after entry
fu_offset_days <- if (identical(SCENARIO$followup_start, "index_date")) 0L else 90L
horizon <- max_fu - fu_offset_days # days since start of follow-up = 2 years after index

n_boot <- as.integer(Sys.getenv("AJ_BOOT_REPS", unset = "500"))
ps_formula <- as.formula(paste("trt ~", paste(cov_list, collapse = " + ")))

cohort_labels <- list(
  data1 = c(ref = "SGLT2 Inhibitors", index = "GLP1 RAs", short = "SGLT2",
            title = "(a) GLP1 RAs vs SGLT2 Inhibitors"),
  data2 = c(ref = "DPP4 Inhibitors",  index = "GLP1 RAs", short = "DPP4",
            title = "(b) GLP1 RAs vs DPP4 Inhibitors"),
  data3 = c(ref = "Sulfonylureas",    index = "GLP1 RAs", short = "Sulfonylureas",
            title = "(c) GLP1 RAs vs Sulfonylureas")
)
palette <- c("#009E73", "#CC79A7") # comparator, GLP1 (same as figure 3)


#### HELPERS ####

# Code the observed exit as censor / dementia / death. Censoring must be the
# first factor level: this is what makes survfit() fit a multi-state
# (Aalen-Johansen) model instead of Kaplan-Meier. Patients flagged `excluded`
# (dementia before the start of follow-up, or no follow-up after it) are
# dropped after the propensity score is fit, as in the primary analysis.
prep_competing <- function(cohort) {
  cohort %>%
    mutate(across(c(index_date, cov_end, dod, outcome_dementia_allcause_date), as.Date)) %>%
    mutate(
      f_up_start  = index_date + fu_offset_days,
      early_event = !is.na(outcome_dementia_allcause_date) &
                      outcome_dementia_allcause_date < f_up_start,
      censor_date = pmin(cov_end, end_date, index_date + max_fu, na.rm = TRUE),
      dem_date    = if_else(!is.na(outcome_dementia_allcause_date) &
                              outcome_dementia_allcause_date >= f_up_start &
                              outcome_dementia_allcause_date < censor_date,
                            outcome_dementia_allcause_date, as.Date(NA)),
      death_date  = if_else(!is.na(dod) & dod <= censor_date, dod, as.Date(NA)),
      end_obs     = pmin(censor_date, dem_date, death_date, na.rm = TRUE),
      event = case_when(
        !is.na(dem_date)   & dem_date   == end_obs ~ "dementia", # dementia wins same-day ties
        !is.na(death_date) & death_date == end_obs ~ "death",
        TRUE ~ "censor"
      ),
      event = factor(event, levels = c("censor", "dementia", "death")),
      time  = as.numeric(end_obs - f_up_start),
      excluded = early_event | time <= 0
    )
}

fit_aj <- function(d, w) {
  d$w  <- w
  d$id <- seq_len(nrow(d)) # unique ids, also valid for bootstrap resamples
  survfit(Surv(time, event) ~ trt, data = d, weights = w, id = id)
}

# Risks of dementia and death at `horizon`; rows "0" = comparator, "1" = GLP1
get_risks <- function(fit, t = horizon) {
  s <- summary(fit, times = t, extend = TRUE)
  p <- s$pstate
  colnames(p) <- s$states
  rownames(p) <- sub("^trt=", "", as.character(s$strata))
  p[c("0", "1"), c("dementia", "death"), drop = FALSE]
}

risk_measures <- function(fit) {
  r <- get_risks(fit)
  unlist(lapply(c(dementia_allcause = "dementia", death = "death"), function(ev) c(
    risk_trt  = r["1", ev],
    risk_comp = r["0", ev],
    rd        = r["1", ev] - r["0", ev],
    rr        = r["1", ev] / r["0", ev]
  )))
}

# Fast weighted Aalen-Johansen risks at `t` for one arm. Each patient has a
# single exit (censor / dementia / death), so the AJ estimator reduces to
# CIF_k(t) = sum_{s <= t} S(s-) * dN_k(s) / Y(s), with S the all-cause
# product-limit survival. Gives the same values as summary(survfit(...))$pstate
# but avoids the overhead of survfit() inside the bootstrap.
aj_risk_fast <- function(time, event, w, t = horizon) {
  keep <- w > 0
  time <- time[keep]; event <- event[keep]; w <- w[keep]
  agg <- rowsum(cbind(w, w * (event == "dementia"), w * (event == "death")), time)
  s   <- as.numeric(rownames(agg))
  y   <- rev(cumsum(rev(agg[, 1])))          # weighted number at risk
  surv_prev <- c(1, head(cumprod(1 - (agg[, 2] + agg[, 3]) / y), -1))
  in_t <- s <= t
  c(dementia = sum((surv_prev * agg[, 2] / y)[in_t]),
    death    = sum((surv_prev * agg[, 3] / y)[in_t]))
}

risk_measures_fast <- function(time, event, trt, w) {
  r1 <- aj_risk_fast(time[trt == 1], event[trt == 1], w[trt == 1])
  r0 <- aj_risk_fast(time[trt == 0], event[trt == 0], w[trt == 0])
  unlist(lapply(c(dementia_allcause = "dementia", death = "death"), function(ev) c(
    risk_trt  = r1[[ev]],
    risk_comp = r0[[ev]],
    rd        = r1[[ev]] - r0[[ev]],
    rr        = r1[[ev]] / r0[[ev]]
  )))
}

# Bootstrap setup done once per cohort: the PS design matrix, outcome vectors
# and full-sample PS coefficients (used as starting values in each resample).
prep_boot <- function(cohort) {
  mf <- model.frame(ps_formula, data = cohort, na.action = na.fail)
  X   <- model.matrix(ps_formula, mf)
  trt <- as.numeric(as.character(cohort$trt))
  list(X = X, trt = trt,
       time = cohort$time, event = cohort$event, excluded = cohort$excluded,
       start = coef(glm.fit(X, trt, family = binomial())))
}

# One bootstrap replicate: resample patients, re-estimate overlap weights
# (same PS model as 16-compute-ow.qmd), then apply the exclusions. The
# resample is represented by how many times each patient is drawn: fitting
# the PS with these counts as frequency weights is equivalent to fitting it on
# the resampled rows, and uses the same random draws as sample().
boot_once <- function(b) {
  n     <- nrow(b$X)
  count <- tabulate(sample(n, replace = TRUE), nbins = n)
  ps    <- glm.fit(b$X, b$trt, weights = count, start = b$start,
                   family = binomial())$fitted.values
  ow    <- ifelse(b$trt == 1, 1 - ps, ps) * count
  ow[b$excluded] <- 0
  risk_measures_fast(b$time, b$event, b$trt, ow)
}

# Same formatting helper as 18-run-survival-analyses.qmd: indented labels are
# plain rows, non-indented labels with empty values are bold section headers.
write_manuscript_xlsx <- function(df, path, sheet = "Sheet1", label_col = 1) {
  val_cols <- setdiff(seq_len(ncol(df)), label_col)
  lab <- as.character(df[[label_col]]); lab[is.na(lab)] <- ""
  indented <- grepl("^[[:space:]]", lab)
  trimmed  <- trimws(lab)
  vals_empty <- vapply(seq_len(nrow(df)), function(i)
    all(is.na(df[i, val_cols]) | trimws(as.character(df[i, val_cols])) == ""),
    logical(1))
  is_section <- !indented & nzchar(trimmed) & vals_empty

  out <- df
  out[[label_col]] <- trimmed

  wb <- createWorkbook()
  addWorksheet(wb, sheet)
  writeData(wb, sheet, out, colNames = TRUE)
  nr <- nrow(out); nc <- ncol(out)

  font <- list(fontName = "Times New Roman", fontSize = 12)
  addStyle(wb, sheet, do.call(createStyle, c(font, list(valign = "center", wrapText = TRUE))),
           rows = 1:(nr + 1), cols = 1:nc, gridExpand = TRUE)
  addStyle(wb, sheet, do.call(createStyle, c(font, list(textDecoration = "bold", wrapText = TRUE))),
           rows = 1, cols = 1:nc, gridExpand = TRUE)
  for (i in seq_len(nr)) {
    st <- do.call(createStyle, c(font, list(
      halign = "left",
      indent = if (indented[i]) 1 else 0,
      textDecoration = if (is_section[i]) "bold" else NULL
    )))
    addStyle(wb, sheet, st, rows = i + 1, cols = label_col, gridExpand = TRUE)
  }
  setColWidths(wb, sheet, cols = label_col, widths = 34)
  setColWidths(wb, sheet, cols = val_cols, widths = 22)
  saveWorkbook(wb, path, overwrite = TRUE)
}


#### AALEN-JOHANSEN BY COHORT ####

set.seed(2026)

aj_results <- list()
aj_counts  <- list()
efig_panels <- list()

for (cohort_name in c("data1", "data2", "data3")) {

  labs_c <- cohort_labels[[cohort_name]]
  arm_labels <- c("trt=0" = labs_c[["ref"]], "trt=1" = labs_c[["index"]])
  cohort <- prep_competing(get(cohort_name))
  analytic <- cohort %>% filter(!excluded)

  # point estimates use the overlap weights saved by 16-compute-ow.qmd
  fit <- fit_aj(analytic, analytic$ow)
  est <- risk_measures(fit)

  # check the fast AJ against survfit() before relying on it in the bootstrap
  est_fast <- risk_measures_fast(analytic$time, analytic$event,
                                 as.numeric(as.character(analytic$trt)), analytic$ow)
  stopifnot(isTRUE(all.equal(est, est_fast, tolerance = 1e-8)))

  message(sprintf("%s: running %d bootstrap resamples (n = %s)...",
                  cohort_name, n_boot, format(nrow(cohort), big.mark = ",")))
  b  <- prep_boot(cohort)
  t0 <- Sys.time()
  pb <- txtProgressBar(min = 0, max = n_boot, style = 3)
  boots <- matrix(NA_real_, n_boot, length(est), dimnames = list(NULL, names(est)))
  for (i in seq_len(n_boot)) {
    boots[i, ] <- boot_once(b)
    setTxtProgressBar(pb, i)
  }
  close(pb)
  message(sprintf("%s: bootstrap done in %.1f min", cohort_name,
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))

  res <- data.frame(
    cohort   = cohort_name,
    outcome  = sub("\\..*$", "", names(est)),
    measure  = sub("^.*\\.", "", names(est)),
    horizon_days = horizon,
    estimate = unname(est),
    ci_lower = unname(apply(boots, 2, quantile, 0.025, na.rm = TRUE)),
    ci_upper = unname(apply(boots, 2, quantile, 0.975, na.rm = TRUE)),
    n_boot   = n_boot
  )
  aj_results[[cohort_name]] <- res

  # crude (unweighted) counts of each type of exit by treatment group
  aj_counts[[cohort_name]] <- analytic %>%
    group_by(trt) %>%
    summarise(
      n            = n(),
      n_dementia   = sum(event == "dementia"),
      n_death      = sum(event == "death"),
      n_censor     = sum(event == "censor"),
      median_fu    = median(time),
      .groups = "drop"
    ) %>%
    mutate(cohort = cohort_name, .before = 1)


  #### CUMULATIVE INCIDENCE CURVES ####

  cif_df <- tidy(fit) %>%
    filter(state %in% c("dementia", "death")) %>%
    select(strata, state, time, estimate)
  cif_df <- cif_df %>%
    distinct(strata, state) %>%
    mutate(time = 0, estimate = 0) %>%
    bind_rows(cif_df) %>%
    mutate(arm = factor(arm_labels[strata], levels = arm_labels))

  # Results-folder plot: dementia and death side by side
  p <- cif_df %>%
    mutate(event = factor(state, levels = c("dementia", "death"),
                          labels = c("All-Cause Dementia", "Death (Competing Event)"))) %>%
    ggplot(aes(x = time, y = estimate, colour = arm)) +
    geom_step(linewidth = 0.7) +
    facet_wrap(~ event, scales = "free_y") +
    scale_colour_manual(values = setNames(palette, arm_labels)) +
    scale_y_continuous(labels = scales::label_percent(accuracy = 0.1)) +
    labs(
      x = "Time (days)",
      y = "Cumulative Incidence",
      colour = "Treatment",
      title = "Cumulative Incidence of All-Cause Dementia and Death",
      subtitle = "Intention-to-Treat Approach with Overlap Weights (Aalen-Johansen Estimator, Death as Competing Event)"
    ) +
    theme_classic() +
    theme(legend.position = "bottom",
          strip.background = element_blank(),
          strip.text = element_text(face = "bold", size = 11))

  print(p)
  ggsave(file.path(results_dir, paste0("aj_cif_dementia_allcause_", cohort_name, ".pdf")),
         p, width = 10, height = 6)

  # e-figure 1 panel: dementia cumulative incidence + number at risk, laid out
  # like the per-cohort panels of manuscript figure 3
  rr <- res %>% filter(outcome == "dementia_allcause", measure == "rr")
  x_breaks <- seq(0, horizon, by = 200)

  p_curve <- cif_df %>%
    filter(state == "dementia") %>%
    ggplot(aes(x = time, y = estimate, colour = arm)) +
    geom_step(linewidth = 0.8) +
    annotate("text", x = 0, y = 0.025, hjust = 0, size = 4,
             label = sprintf("Risk ratio at 2 years: %.2f (95%% CI %.2f-%.2f)",
                             rr$estimate, rr$ci_lower, rr$ci_upper)) +
    scale_colour_manual(values = setNames(palette, arm_labels)) +
    scale_x_continuous(breaks = x_breaks) +
    coord_cartesian(xlim = c(0, horizon), ylim = c(0, 0.027)) + # same scale as figure 3; adjust as needed
    labs(x = "Time (days)", y = "Cumulative Incidence", colour = "Treatment",
         title = labs_c[["title"]]) +
    theme_classic() +
    theme(legend.position = "top",
          plot.title   = element_text(face = "bold"),
          legend.text  = element_text(size = 12),
          legend.title = element_text(size = 12, face = "bold"))

  # unweighted number at risk at each x-axis break
  at_risk <- expand.grid(time = x_breaks, trt = c("0", "1"), stringsAsFactors = FALSE)
  at_risk$n <- mapply(function(t, a) sum(analytic$time >= t & analytic$trt == a),
                      at_risk$time, at_risk$trt)
  at_risk$arm <- factor(arm_labels[paste0("trt=", at_risk$trt)], levels = rev(arm_labels))

  p_table <- ggplot(at_risk, aes(x = time, y = arm, label = format(n, big.mark = ","), colour = arm)) +
    geom_text(size = 3.5) +
    scale_colour_manual(values = setNames(palette, arm_labels), guide = "none") +
    scale_x_continuous(breaks = x_breaks) +
    coord_cartesian(xlim = c(0, horizon)) +
    labs(x = "Time (days)", y = NULL, title = "Number at risk") +
    theme_classic() +
    theme(plot.title  = element_text(size = 11),
          axis.line.y = element_blank(),
          axis.ticks.y = element_blank(),
          axis.text.y = element_text(face = "bold"))

  efig_panels[[cohort_name]] <- wrap_elements(
    p_curve / p_table + plot_layout(heights = c(3, 1))
  )

  rm(cohort, analytic, fit, est, est_fast, b, boots, res, cif_df, p, p_curve, p_table, at_risk, rr)
  gc()
}

# all three comparisons stacked vertically (results folder copy)
efig <- wrap_plots(efig_panels, ncol = 1)
ggsave(file.path(results_dir, "aj_cif_dementia_allcause_all.pdf"),
       efig, width = 8, height = 16)


#### SAVE RESULTS ####

aj_results <- bind_rows(aj_results)
aj_counts  <- bind_rows(aj_counts)

print(aj_results)
print(aj_counts)

write.csv(aj_results, file.path(results_dir, "aj_results.csv"), row.names = FALSE)
write.csv(aj_counts,  file.path(results_dir, "aj_counts.csv"),  row.names = FALSE)
saveRDS(aj_results, file.path(results_dir, "aj_results_novel.rds"))


#### MANUSCRIPT E-TABLE 6 AND E-FIGURE 1 ####

cohort_cols <- c(
  data1 = "GLP1s vs SGLT2s",
  data2 = "GLP1s vs DPP4s",
  data3 = "GLP1s vs Sulfonylureas"
)

# risks and RD in %, RR as a ratio
fmt_measure <- function(out, meas) {
  vapply(names(cohort_cols), function(coh) {
    r <- aj_results %>% filter(cohort == coh, outcome == out, measure == meas)
    k <- if (meas == "rr") 1 else 100
    if (nrow(r) == 1) sprintf("%.2f (%.2f, %.2f)", k * r$estimate, k * r$ci_lower, k * r$ci_upper)
    else NA_character_
  }, character(1))
}

etab_rows <- function(out, heading) {
  rbind(
    c(heading, rep("", length(cohort_cols))),
    c("  Risk in GLP1 RAs, % (95% CI)",     fmt_measure(out, "risk_trt")),
    c("  Risk in comparator, % (95% CI)",   fmt_measure(out, "risk_comp")),
    c("  Risk difference, % (95% CI)",      fmt_measure(out, "rd")),
    c("  Risk ratio (95% CI)",              fmt_measure(out, "rr"))
  )
}

# Footnote: crude (unweighted) number of events by treatment group
crude_events <- function(col) {
  parts <- vapply(names(cohort_cols), function(coh) {
    r <- aj_counts %>% filter(cohort == coh)
    sprintf("GLP-1 %d vs %s %d",
            r[[col]][r$trt == "1"], cohort_labels[[coh]][["short"]], r[[col]][r$trt == "0"])
  }, character(1))
  paste(parts, collapse = "; ")
}
blank <- rep("", length(cohort_cols))

e_tab6 <- as.data.frame(rbind(
  etab_rows("dementia_allcause", "All-cause dementia"),
  etab_rows("death", "Death (competing event)"),
  c("Crude number of events by treatment group:", blank),
  c(paste0("  All-cause dementia: ", crude_events("n_dementia")), blank),
  c(paste0("  Death: ", crude_events("n_death")), blank),
  c("Notes:", blank),
  c(paste0("  Risks at 2 years after index estimated with the overlap-weighted ",
           "Aalen-Johansen estimator, treating death as a competing event. ",
           "Follow-up starts 90 days after index; patients with dementia or ",
           "leaving the cohort before then are excluded. 95% CIs are bootstrap ",
           "percentile intervals (", n_boot, " resamples) re-estimating the ",
           "overlap weights in each resample."), blank)
), stringsAsFactors = FALSE)
colnames(e_tab6) <- c("Outcome", unname(cohort_cols))

if (write_manuscript) {
  dir.create(manuscript_tab_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(manuscript_fig_dir, recursive = TRUE, showWarnings = FALSE)

  write_manuscript_xlsx(e_tab6,
                        file.path(manuscript_tab_dir, "e-table-6-competing-risk.xlsx"),
                        sheet = "e-Table 6")

  ggsave(file.path(manuscript_fig_dir, "e-figure-1-aj-curves.pdf"),
         efig, width = 8, height = 16)
  # High-resolution TIFF for manuscript submission (LZW-compressed, 300 dpi).
  ggsave(file.path(manuscript_fig_dir, "e-figure-1-aj-curves.tiff"),
         efig, width = 8, height = 16, dpi = 300,
         device = "tiff", compression = "lzw")
}
