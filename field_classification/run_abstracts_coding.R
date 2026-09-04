# Classify a CSV of abstracts (doi_o; abstract; title, semicolon-separated) into
# discipline clusters and subfields, reusing the functions defined in
# article_classification_pipeline - integrated.qmd.
#
# Usage (from project root):
#   Rscript field_classification/run_abstracts_coding.R <input.csv> [output.csv] [max_field_rows]
#
# Safe to rerun. Rows already in the output keep their cluster code; the field
# stage is run for rows that lack a field code in a cluster that has a field
# schema (e.g. after a new schema is enabled), and rows with unparseable model
# output are redone. max_field_rows caps how many such rows get field-coded in
# this run (useful for a validation sample); default is all.

args <- commandArgs(trailingOnly = TRUE)
input_path <- if (length(args) >= 1) args[1] else "~/Downloads/abstracts.csv"
output_path <- if (length(args) >= 2) args[2] else here::here("field_classification", "classified_abstracts.csv")
max_field_rows <- if (length(args) >= 3) as.integer(args[3]) else Inf

readRenviron("~/.Renviron")
suppressMessages({ library(dplyr); library(readr); library(knitr) })

# Load pipeline functions and schemas: purl the qmd and drop the chunks that
# run the pilot itself (everything from 'load-pilot-abstracts' onwards).
qmd <- here::here("field_classification", "article_classification_pipeline - integrated.qmd")
purled <- tempfile(fileext = ".R")
knitr::purl(qmd, output = purled, quiet = TRUE)
code <- readLines(purled)
cut <- grep("label: load-pilot-abstracts", code, fixed = TRUE)[1]
stopifnot(!is.na(cut))
source(textConnection(code[seq_len(cut - 2)]))

field_cols <- c("field_id", "field_confidence", "field_reasoning")

articles <- read_delim(input_path, delim = ";", show_col_types = FALSE) |>
  select(doi = doi_o, title, abstract) |>
  mutate(
    doi = tolower(sub("^https?://(dx\\.)?doi\\.org/", "", trimws(doi), ignore.case = TRUE)),
    title = clean_json_text(coalesce(title, "")),
    abstract = clean_json_text(abstract)
  ) |>
  distinct(doi, .keep_all = TRUE)

done <- if (file.exists(output_path)) read_csv(output_path, show_col_types = FALSE) else NULL
if (!is.null(done)) {
  done <- filter(done, !is.na(cluster_id))   # unparseable cluster output: redo from scratch
  articles <- filter(articles, !doi %in% done$doi)
}
cat(sprintf("%d new articles to classify (%d already done)\n", nrow(articles), if (is.null(done)) 0 else nrow(done)))

# --- Cluster stage for new articles ---------------------------------------
new_results <- NULL
if (nrow(articles) > 0) {
  options(openalexR.mailto = Sys.getenv("OPENALEX_EMAIL", "l.wallrich@bbk.ac.uk"))
  oa_journals <- openalexR::oa_fetch(entity = "works", doi = articles$doi, verbose = TRUE) |>
    as_tibble() |>
    transmute(doi = tolower(sub("^https?://(dx\\.)?doi\\.org/", "", doi, ignore.case = TRUE)),
              source_display_name) |>
    distinct(doi, .keep_all = TRUE)
  articles <- articles |>
    left_join(oa_journals, by = "doi") |>
    mutate(source_display_name = coalesce(source_display_name, ""))
  cat(sprintf("Journal resolved for %d of %d\n", sum(nzchar(articles$source_display_name)), nrow(articles)))
  new_results <- classify_articles_batch(articles, journal_col = "source_display_name")
}

# --- Field stage ------------------------------------------------------------
# Rows needing a field code: new rows, plus existing rows in a cluster with a
# field schema that have no field code yet.
all_rows <- bind_rows(done, new_results)
if (!"field_id" %in% names(all_rows)) all_rows[field_cols] <- NA
needs_field <- all_rows$cluster_id %in% names(cluster_breakdowns) & is.na(all_rows$field_id)
idx <- which(needs_field)
if (length(idx) > max_field_rows) idx <- idx[seq_len(max_field_rows)]
cat(sprintf("%d rows need field coding; coding %d in this run\n", sum(needs_field), length(idx)))

if (length(idx) > 0) {
  # On a first full run the >=100 threshold applies; on top-ups the cluster
  # has already qualified, so every row in a covered cluster gets coded.
  threshold <- if (is.null(done)) 100 else 1
  coded <- classify_cluster_fields(
    all_rows[idx, ] |> select(-all_of(field_cols)),
    journal_col = "source_display_name",
    cluster_breakdowns = cluster_breakdowns,
    field_threshold = threshold
  )
  all_rows <- bind_rows(all_rows[-idx, ], coded)
}

write_csv(all_rows, output_path)
cat(sprintf("Wrote %d rows to %s\n", nrow(all_rows), output_path))
print(count(all_rows, cluster_id, sort = TRUE))
for (cl in names(cluster_breakdowns)) {
  cat("\nFields in", cl, "\n")
  print(all_rows |> filter(cluster_id == cl) |> count(field_id, sort = TRUE))
}
