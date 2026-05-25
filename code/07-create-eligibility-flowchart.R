# This code creates a CSV with the number of patients at each step from cohort creation to eligibility

library(tidyverse)
library(dplyr)

project_root <- Sys.getenv("PROJECT_ROOT")
if (nchar(project_root) == 0) stop("PROJECT_ROOT is not set. To run this file directly in an R session, source code/00-setup.R first in the same session (it loads .Renviron). Otherwise launch the full pipeline via run_all.R / run_all.command / run_all.bat.")
output_dir      <- Sys.getenv("OUTPUT_DIR",      unset = file.path(project_root, "output"))
main_output_dir <- Sys.getenv("MAIN_OUTPUT_DIR", unset = output_dir)
results_dir <- Sys.getenv("RESULTS_DIR", unset = file.path(project_root, "results", "main"))
out_path <- function(name) {
  p <- normalizePath(file.path(output_dir, name), winslash = "/", mustWork = FALSE)
  if (file.exists(p)) return(p)
  normalizePath(file.path(main_output_dir, name), winslash = "/", mustWork = FALSE)
}

log_path <- out_path("eligibility_log.txt")
lines <- readr::read_lines(log_path)

# keep lines of interest from the eligibility log text file
step_idx <- str_detect(lines, regex(
  "^(Start:|After exclude)",
  ignore_case = TRUE
))
df_lines <- tibble(raw = lines, lineno = seq_along(lines)) %>% filter(step_idx)

# get the patient count at each step
extract_count <- function(line) {
  nums <- str_extract_all(line, "\\d[\\d,]*")[[1]] %>% str_replace_all(",", "")
  if (length(nums) == 0) return(NA_integer_)
  nums_int <- as.integer(nums)

  # "remaining" / "left" patterns
  remain <- str_match(line, "(?i)(?:remaining|left|remain(?:ing)?(?: after)?)\\s*[:=]?\\s*(\\d[\\d,]*)")
  if (!is.na(remain[1,2])) return(as.integer(str_replace_all(remain[1,2], ",", "")))

  # number immediately followed or preceded by word "patients"
  patients <- str_match(line, "(?i)(\\d[\\d,]*)\\s*(?:patients)\\b")
  if (!is.na(remain[1,2])) return(as.integer(str_replace_all(remain[1,2], "," , "")))
  patients <- str_match(line, "(?i)\\b(?:patients)[: ]+\\s*(\\d[\\d,]*)")
  if (!is.na(patients[1,2])) return(as.integer(str_replace_all(patients[1,2], "," , "")))

  # choose the largest multi-digit number (>=10) to avoid capturing 2 from T2D or age 60
  if (any(!is.na(nums_int))) {
    candidates <- nums_int[!is.na(nums_int)]
    big <- max(candidates, na.rm = TRUE)
    if (big >= 10) return(big)
  }
  NA_integer_
}

# build table with step and counts for each group
df <- df_lines %>%
  mutate(
    step = str_replace(raw, "^([^:]+):.*", "\\1") %>% str_trim(),
    cohort = case_when(
      str_detect(raw, regex("novel", ignore_case = TRUE)) ~ "novel",
      TRUE ~ NA_character_
    ),
    n = map_int(raw, extract_count)
  ) %>%
  fill(cohort, .direction = "down") %>%
  select(lineno, step, cohort, n)

# pivot to wide form with a row per step
step_order <- df %>% distinct(step, .keep_all = TRUE) %>% pull(step)
res <- df %>%
  mutate(step = factor(step, levels = step_order)) %>%
  arrange(step, lineno) %>%
  select(-lineno) %>%
  pivot_wider(names_from = cohort, values_from = n)

# and compute number excluded at each step
res_with_excluded <- res %>%
  mutate(across(any_of(c("novel")), as.integer))  

cohorts <- intersect(c("novel"), names(res_with_excluded))

for (c in cohorts) {
  newname <- paste0("Excluded (", c, ")")
  res_with_excluded[[newname]] <- dplyr::lag(res_with_excluded[[c]]) - res_with_excluded[[c]]
}

res_with_excluded

dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
readr::write_csv(res_with_excluded, file.path(results_dir, "eligibility_steps_by_cohort.csv"))
