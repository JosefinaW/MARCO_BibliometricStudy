suppressMessages({
  library(dplyr)
  library(readr)
})

manual <- read_csv(
  here::here("field_classification", "manual_psych_classification.csv"),
  show_col_types = FALSE
) |>
  filter(nzchar(field_id)) |>
  rename(field_manual = field_id)

llm <- read_csv(
  here::here("field_classification", "classified_articles_pilot.csv"),
  show_col_types = FALSE
) |>
  select(
    doi, title, source_display_name,
    cluster_llm = cluster_id,
    field_llm = field_id,
    field_confidence,
    field_reasoning
  )

cmp <- manual |>
  inner_join(llm, by = "doi") |>
  mutate(agree = field_manual == field_llm)

n <- nrow(cmp)
cat(sprintf("Joined rows: %d (of %d manually coded)\n\n", n, nrow(manual)))

# LLM only ran field-stage on articles it put in psychology.
# Report the subset where LLM also has a field_llm.
has_llm <- cmp |> filter(!is.na(field_llm))
cat(sprintf(
  "Rows where LLM also assigned a psychology subfield: %d\n", nrow(has_llm)
))
cat(sprintf(
  "Primary field agreement: %d / %d  (%.1f%%)\n\n",
  sum(has_llm$agree, na.rm = TRUE), nrow(has_llm),
  100 * mean(has_llm$agree, na.rm = TRUE)
))

# For articles the LLM did NOT classify as psychology, note the cluster it chose
cat("=== Rows where manual = psychology-subfield but LLM put article outside psychology ===\n")
outside <- cmp |>
  filter(is.na(field_llm)) |>
  count(field_manual, cluster_llm, name = "n") |>
  arrange(desc(n))
if (nrow(outside) > 0) {
  print(outside, n = Inf)
} else {
  cat("(none)\n")
}

cat("\n=== Per-manual-subfield agreement (within shared set) ===\n")
per_sub <- has_llm |>
  group_by(field_manual) |>
  summarise(
    n = n(),
    agree = sum(agree, na.rm = TRUE),
    pct = round(100 * mean(agree, na.rm = TRUE), 1),
    .groups = "drop"
  ) |>
  arrange(desc(n))
print(per_sub, n = Inf)

cat("\n=== Confusion (manual -> LLM) for disagreements ===\n")
conf <- has_llm |>
  filter(!agree) |>
  count(field_manual, field_llm, name = "n") |>
  arrange(desc(n))
print(conf, n = Inf)

cat("\n=== Discrepancies (ordered by LLM confidence) ===\n")
disc <- has_llm |>
  filter(!agree) |>
  select(doi, title, source_display_name,
         field_manual, field_llm, field_confidence) |>
  arrange(desc(field_confidence))
cat(sprintf("Total discrepancies: %d (%.1f%%)\n\n",
            nrow(disc), 100 * nrow(disc) / nrow(has_llm)))
disc |>
  mutate(title = substr(title, 1, 65)) |>
  print(n = Inf, width = Inf)

cat("\n=== Confidence vs. agreement (field stage) ===\n")
cat(sprintf(
  "Mean LLM field confidence when agreeing:    %.3f\n",
  mean(has_llm$field_confidence[has_llm$agree], na.rm = TRUE)
))
cat(sprintf(
  "Mean LLM field confidence when disagreeing: %.3f\n",
  mean(has_llm$field_confidence[!has_llm$agree], na.rm = TRUE)
))

cat("\n=== Cohen's kappa (field stage, shared set) ===\n")
all_lvls <- union(has_llm$field_manual, has_llm$field_llm)
tab <- table(
  factor(has_llm$field_manual, levels = all_lvls),
  factor(has_llm$field_llm,    levels = all_lvls)
)
po <- sum(diag(tab)) / sum(tab)
pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
kappa <- (po - pe) / (1 - pe)
cat(sprintf("Observed agreement: %.3f\nExpected agreement: %.3f\nCohen's kappa:     %.3f\n",
            po, pe, kappa))

write_csv(
  disc,
  here::here("field_classification", "manual_llm_psych_discrepancies.csv")
)
cat("\nDiscrepancies saved to field_classification/manual_llm_psych_discrepancies.csv\n")
