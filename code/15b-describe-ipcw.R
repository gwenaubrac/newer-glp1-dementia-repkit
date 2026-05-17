project_root <- Sys.getenv("PROJECT_ROOT")
if (nchar(project_root) == 0) stop("PROJECT_ROOT is not set. Please run: source config.sh (bash) or set it in .Renviron (RStudio).")
output_dir  <- file.path(project_root, "output")
results_dir <- Sys.getenv("RESULTS_DIR", unset = file.path(project_root, "results"))

#### SWITCH MODEL SEPARATELY BY TREATMENT ####

# Open a text file to save ../outputs
sink(file.path(results_dir, "switching_analysis_results_novel.txt"))

cat("=" , rep("=", 70), "\n", sep = "")
cat("MEDICATION SWITCHING ANALYSIS RESULTS\n")
cat("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("=" , rep("=", 70), "\n\n", sep = "")

# ============================================================================
# Overall switching rate
# ============================================================================
cat("\n")
cat("TABLE 1: OVERALL SWITCHING RATE\n")
cat("-" , rep("-", 70), "\n", sep = "")

table1 <- data %>%
  tbl_summary(
    include = switch,
    label = list(switch ~ "Switched Medication"),
    statistic = all_categorical() ~ "{n} ({p}%)"
  ) %>%
  bold_labels() %>%
  as_hux_table()

print(table1)

cat("\n\n")
cat("TABLE 2: SWITCHING RATE BY INDEX MEDICATION\n")
cat("-" , rep("-", 70), "\n", sep = "")

table2 <- data %>%
  group_by(index_class) %>%
  summarize(
    prop_switch = sum(switch == 1)/n()
  )

print(table2)

# ============================================================================
# Switching patterns (from -> to)
# ============================================================================
cat("\n\n")
cat("TABLE 3: SWITCHING PATTERNS (FROM -> TO)\n")
cat("-" , rep("-", 70), "\n", sep = "")

data %<>%
  mutate(
    new_index_class = if_else(index_class == "GLP1", index_glp1, index_class)
  )

table3 <- data %>%
  filter(switch == 1) %>%
  tbl_cross(
    row = new_index_class,
    col = switch_type,
    percent = "row",
    label = list(new_index_class ~ "From", switch_type ~ "To")
  ) %>%
  bold_labels() %>%
  as_hux_table()

print(table3)

cat("\n")
cat("=" , rep("=", 70), "\n", sep = "")
cat("END OF REPORT\n")
cat("=" , rep("=", 70), "\n", sep = "")

# Close the text file
sink()


sink(file.path(results_dir, "ipcw_models_switch_novel.txt"))

cat("=" , rep("=", 70), "\n", sep = "")
cat("IPCW SWITCH MODELS\n")
cat("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("=" , rep("=", 70), "\n\n", sep = "")


data %<>%
  mutate(
    noswitch = if_else(switch == 1, 0, 1),
    novel_flag = if_else(index_glp1 == "semaglutide" | index_glp1 == "tirzepatide", 1, 0) # create indicator for novel GLP1s
  )

ipcw_switch_formula <- as.formula(paste("noswitch ~", paste(cov_list, collapse = " + ")))

ipcw_switch_mod1 <- glm(
  ipcw_switch_formula,
  data = data,
  family = binomial(),
  subset = (novel_flag == 1)
)

cat("\n\n")
cat("Novel GLP1s\n")
cat("-" , rep("-", 70), "\n", sep = "")

print(
  tidy(ipcw_switch_mod1) %>%
  arrange(desc(abs(estimate))),
  n=Inf
)

data$ipcw_switch <- NA
data$ipcw_switch[data$novel_flag == 1] <- 1/predict(ipcw_switch_mod1, type = "response", newdata = subset(data, novel_flag == 1))

# repeat for other medication groups
ipcw_switch_mod2 <- glm(
  ipcw_switch_formula,
  data = data,
  family = binomial(),
  subset = index_class == "SGLT2"
)

cat("\n\n")
cat("SGLT2\n")
cat("-" , rep("-", 70), "\n", sep = "")

print(
  tidy(ipcw_switch_mod2) %>%
  arrange(desc(abs(estimate))),
  n=Inf
)

data$ipcw_switch[data$index_class == "SGLT2"] <- 1/predict(ipcw_switch_mod2, type = "response", newdata = subset(data, index_class == "SGLT2"))


ipcw_switch_mod3 <- glm(
  ipcw_switch_formula,
  data = data,
  family = binomial(),
  subset = index_class == "DPP4"
)

cat("\n\n")
cat("DPP4\n")
cat("-" , rep("-", 70), "\n", sep = "")

print(  
  tidy(ipcw_switch_mod3) %>%
  arrange(desc(abs(estimate))),
  n=Inf
)

data$ipcw_switch[data$index_class == "DPP4"] <- 1/predict(ipcw_switch_mod3, type = "response", newdata = subset(data, index_class == "DPP4"))



ipcw_switch_mod4 <- glm(
  ipcw_switch_formula,
  data = data,
  family = binomial(),
  subset = index_class == "SULFO"
)


cat("\n\n")
cat("SULFO\n")
cat("-" , rep("-", 70), "\n", sep = "")

print(
  tidy(ipcw_switch_mod4) %>%
  arrange(desc(abs(estimate))),
  n=Inf
)
data$ipcw_switch[data$index_class == "SULFO"] <- 1/predict(ipcw_switch_mod4, type = "response", newdata = subset(data, index_class == "SULFO"))

sink()

summary(data$ipcw_switch)


#### DISCONTINUATION MODEL SEPARATELY BY TREATMENT ####

# we are modeling the probability of NOT discontinuing
data %<>%
  mutate(nodisc = if_else(disc == 1, 0, 1))

ipcw_disc_formula <- as.formula(paste("nodisc ~", paste(cov_list, collapse = " + ")))


sink(file.path(results_dir, "ipcw_models_disc_novel.txt"))

cat("=" , rep("=", 70), "\n", sep = "")
cat("IPCW DISCONTINUATION MODELS\n")
cat("Generated on:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("=" , rep("=", 70), "\n\n", sep = "")


ipcw_disc_mod1 <- glm(
  ipcw_disc_formula,
  data = data,
  family = binomial(),
  subset = novel_flag == 1
)

cat("\n\n")
cat("Novel GLP1\n")
cat("-" , rep("-", 70), "\n", sep = "")


print(
  tidy(ipcw_disc_mod1) %>%
  arrange(desc(abs(estimate))),
  n=Inf
)

# initialize the weights variable
data$ipcw_disc <- NA
data$ipcw_disc[data$novel_flag == 1] <- 1/predict(ipcw_disc_mod1, type = "response", newdata = subset(data, novel_flag == 1))

# repeat for other medication groups
ipcw_disc_mod2 <- glm(
  ipcw_disc_formula,
  data = data,
  family = binomial(),
  subset = index_class == "SGLT2"
)

cat("\n\n")
cat("SGLT2\n")
cat("-" , rep("-", 70), "\n", sep = "")

print(
  tidy(ipcw_disc_mod2) %>%
  arrange(desc(abs(estimate))),
  n=Inf
)

data$ipcw_disc[data$index_class == "SGLT2"] <- 1/predict(ipcw_disc_mod2, type = "response", newdata = subset(data, index_class == "SGLT2"))


ipcw_disc_mod3 <- glm(
  ipcw_disc_formula,
  data = data,
  family = binomial(),
  subset = index_class == "DPP4"
)

cat("\n\n")
cat("DPP4\n")
cat("-" , rep("-", 70), "\n", sep = "")

print(
  tidy(ipcw_disc_mod3) %>%
  arrange(desc(abs(estimate))),
  n=Inf
)

data$ipcw_disc[data$index_class == "DPP4"] <- 1/predict(ipcw_disc_mod3, type = "response", newdata = subset(data, index_class == "DPP4"))



ipcw_disc_mod4 <- glm(
  ipcw_disc_formula,
  data = data,
  family = binomial(),
  subset = index_class == "SULFO"
)

cat("\n\n")
cat("SULFO\n")
cat("-" , rep("-", 70), "\n", sep = "")

print(
  tidy(ipcw_disc_mod4) %>%
  arrange(desc(abs(estimate))),
  n=Inf
)

data$ipcw_disc[data$index_class == "SULFO"] <- 1/predict(ipcw_disc_mod4, type = "response", newdata = subset(data, index_class == "SULFO"))

sink()

summary(data$ipcw_disc)


saveRDS(data, file.path(output_dir, "ipcw_novel.rds"))


#### DESCRIBE CENSORING AND WEIGHTS ####

library(dplyr)
library(tidyr)
library(kableExtra)

data <- data %>%
  mutate(
    time_to_switch = as.numeric(switch_date - index_date),
    time_to_disc = as.numeric(disc_date - index_date)
  )


create_summary <- function(df) {
  df %>%
    summarise(
      Mean = round(mean(value, na.rm = TRUE), 1),
      Median = round(median(value, na.rm = TRUE), 1),
      Min = round(min(value, na.rm = TRUE), 1),
      Max = round(max(value, na.rm = TRUE), 1),
      Q1 = round(quantile(value, 0.25, na.rm = TRUE), 1),
      Q3 = round(quantile(value, 0.75, na.rm = TRUE), 1),
      IQR = round(IQR(value, na.rm = TRUE), 1)
    )
}


time_summary_overall <- data %>%
  pivot_longer(cols = c(time_to_switch, time_to_disc),
               names_to = "Variable", values_to = "value") %>%
  group_by(Variable) %>%
  create_summary() %>%
  mutate(Group = "Overall")

# By index_class time summary
time_summary_by_group <- data %>%
  pivot_longer(cols = c(time_to_switch, time_to_disc),
               names_to = "Variable", values_to = "value") %>%
  group_by(index_class, Variable) %>%
  create_summary() %>%
  rename(Group = index_class)

# Proportion who discontinued per class
disc_per_group <- data %>%
  group_by(index_class) %>%
  summarize(
    prop_disc = sum(disc == 1)/n()
  )


disc_per_glp1 <- data %>%
  group_by(index_glp1) %>%
  summarize(
    prop_disc = sum(disc == 1)/n()
  )


# Overall weights summary
weights_summary_overall <- data %>%
  pivot_longer(cols = c(ipcw_switch, ipcw_disc),
               names_to = "Weight_Type", values_to = "value") %>%
  group_by(Weight_Type) %>%
  summarise(
    Mean = round(mean(value, na.rm = TRUE), 3),
    Median = round(median(value, na.rm = TRUE), 3),
    SD = round(sd(value, na.rm = TRUE), 1),
    Min = round(min(value, na.rm = TRUE), 3),
    Max = round(max(value, na.rm = TRUE), 3),
    Q1 = round(quantile(value, 0.25, na.rm = TRUE), 3),
    Q3 = round(quantile(value, 0.75, na.rm = TRUE), 3),
    IQR = round(IQR(value, na.rm = TRUE), 3)
  ) %>%
  mutate(Group = "Overall")

# By index_class weights summary
weights_summary_by_group <- data %>%
  pivot_longer(cols = c(ipcw_switch, ipcw_disc),
               names_to = "Weight_Type", values_to = "value") %>%
  group_by(index_class, Weight_Type) %>%
  summarise(
    Mean = round(mean(value, na.rm = TRUE), 3),
    Median = round(median(value, na.rm = TRUE), 3),
    Min = round(min(value, na.rm = TRUE), 3),
    Max = round(max(value, na.rm = TRUE), 3),
    Q1 = round(quantile(value, 0.25, na.rm = TRUE), 3),
    Q3 = round(quantile(value, 0.75, na.rm = TRUE), 3),
    IQR = round(IQR(value, na.rm = TRUE), 3)
  ) %>%
  rename(Group = index_class)


# Save tables
write.csv(time_summary_by_group, file.path(results_dir, "time_to_censoring_group_novel.csv"), row.names = FALSE)
write.csv(time_summary_overall, file.path(results_dir, "time_to_censoring_overall_novel.csv"), row.names = FALSE)
write.csv(weights_summary_by_group, file.path(results_dir, "ipcw_weights_group_novel.csv"), row.names = FALSE)
write.csv(disc_per_group, file.path(results_dir, "disc_per_group_novel.csv"), row.names = FALSE)
write.csv(disc_per_glp1, file.path(results_dir, "disc_per_glp1_novel.csv"), row.names = FALSE)
write.csv(weights_summary_overall, file.path(results_dir, "ipcw_weights_overall_novel.csv"), row.names = FALSE)