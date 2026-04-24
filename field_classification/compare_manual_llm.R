suppressMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
})

manual <- read_csv(
  here::here("field_classification", "manual_classification.csv"),
  show_col_types = FALSE
) |>
  rename(cluster_manual = cluster_id)

llm <- read_csv(
  here::here("field_classification", "classified_articles_pilot.csv"),
  show_col_types = FALSE
) |>
  select(
    doi, title, source_display_name,
    cluster_llm = cluster_id,
    confidence,
    secondary_cluster_llm = secondary_cluster_id,
    secondary_confidence,
    reasoning
  )

cmp <- manual |>
  inner_join(llm, by = "doi") |>
  mutate(
    agree_primary = cluster_manual == cluster_llm,
    agree_any = cluster_manual == cluster_llm |
      (!is.na(secondary_cluster_llm) & cluster_manual == secondary_cluster_llm)
  )

n <- nrow(cmp)

cat("=== Overall agreement ===\n")
cat(sprintf(
  "Primary agreement:  %3d / %d  (%.1f%%)\n",
  sum(cmp$agree_primary), n, 100 * mean(cmp$agree_primary)
))
cat(sprintf(
  "Primary OR secondary: %d / %d  (%.1f%%)\n\n",
  sum(cmp$agree_any), n, 100 * mean(cmp$agree_any)
))

cat("=== Per-cluster agreement (from manual label) ===\n")
per_cluster <- cmp |>
  group_by(cluster_manual) |>
  summarise(
    n = n(),
    agree = sum(agree_primary),
    pct = round(100 * mean(agree_primary), 1),
    .groups = "drop"
  ) |>
  arrange(desc(n))
print(per_cluster, n = Inf)

cat("\n=== Confusion (manual -> LLM), showing all rows where they differ ===\n")
conf <- cmp |>
  filter(!agree_primary) |>
  count(cluster_manual, cluster_llm, name = "n") |>
  arrange(desc(n))
print(conf, n = Inf)

cat("\n=== Discrepancies (top 20 by LLM confidence) ===\n")
disc <- cmp |>
  filter(!agree_primary) |>
  select(
    doi, title, source_display_name,
    cluster_manual, cluster_llm, confidence,
    secondary_cluster_llm, secondary_confidence
  ) |>
  arrange(desc(confidence))
cat(sprintf("Total discrepancies: %d (%.1f%%)\n\n",
            nrow(disc), 100 * nrow(disc) / n))
disc |>
  head(20) |>
  mutate(title = substr(title, 1, 70)) |>
  print(n = 20, width = Inf)

cat("\n=== Confidence and discrepancies ===\n")
cat(sprintf(
  "Mean LLM confidence when agreeing:    %.3f\n",
  mean(cmp$confidence[cmp$agree_primary], na.rm = TRUE)
))
cat(sprintf(
  "Mean LLM confidence when disagreeing: %.3f\n",
  mean(cmp$confidence[!cmp$agree_primary], na.rm = TRUE)
))
cat(sprintf(
  "Discrepancy rate among conf >= 0.9:   %d / %d  (%.1f%%)\n",
  sum(!cmp$agree_primary & cmp$confidence >= 0.9, na.rm = TRUE),
  sum(cmp$confidence >= 0.9, na.rm = TRUE),
  100 * sum(!cmp$agree_primary & cmp$confidence >= 0.9, na.rm = TRUE) /
    sum(cmp$confidence >= 0.9, na.rm = TRUE)
))
cat(sprintf(
  "Discrepancy rate among conf <  0.9:   %d / %d  (%.1f%%)\n",
  sum(!cmp$agree_primary & cmp$confidence < 0.9, na.rm = TRUE),
  sum(cmp$confidence < 0.9, na.rm = TRUE),
  100 * sum(!cmp$agree_primary & cmp$confidence < 0.9, na.rm = TRUE) /
    sum(cmp$confidence < 0.9, na.rm = TRUE)
))

cat("\n=== Cohen's kappa ===\n")
# Simple unweighted kappa
all_lvls <- union(cmp$cluster_manual, cmp$cluster_llm)
tab <- table(
  factor(cmp$cluster_manual, levels = all_lvls),
  factor(cmp$cluster_llm,    levels = all_lvls)
)
po <- sum(diag(tab)) / sum(tab)
pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
kappa <- (po - pe) / (1 - pe)
cat(sprintf("Observed agreement: %.3f\nExpected agreement: %.3f\nCohen's kappa:     %.3f\n",
            po, pe, kappa))

# Save discrepancies CSV for review
write_csv(
  disc,
  here::here("field_classification", "manual_llm_discrepancies.csv")
)
cat("\nAll discrepancies saved to field_classification/manual_llm_discrepancies.csv\n")
