# Classify a CSV of abstracts (doi_o; abstract; title, semicolon-separated) into
# discipline clusters and psychology subfields, reusing the functions defined in
# article_classification_pipeline - integrated.qmd.
#
# Usage (from project root):
#   Rscript field_classification/run_abstracts_coding.R <input.csv> [output.csv]
#
# Safe to rerun: DOIs already present in the output file are skipped and the
# new results are appended.

args <- commandArgs(trailingOnly = TRUE)
input_path <- if (length(args) >= 1) args[1] else "~/Downloads/abstracts.csv"
output_path <- if (length(args) >= 2) args[2] else here::here("field_classification", "classified_abstracts.csv")

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
  # Redo rows where a stage returned nothing (unparseable model output)
  redo <- done$doi[is.na(done$cluster_id) |
                   (done$cluster_id %in% names(cluster_breakdowns) & is.na(done$field_id))]
  done <- filter(done, !doi %in% redo)
  articles <- filter(articles, !doi %in% done$doi)
}
cat(sprintf("%d articles to classify (%d already done)\n", nrow(articles), if (is.null(done)) 0 else nrow(done)))
if (nrow(articles) == 0) quit(save = "no")

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

results <- classify_articles_batch(articles, journal_col = "source_display_name")
# On a rerun the >=100 threshold is judged on the full set, so top-up batches
# get field coding for every cluster that already qualified.
results <- classify_cluster_fields(results, journal_col = "source_display_name",
                                   cluster_breakdowns = cluster_breakdowns,
                                   field_threshold = if (is.null(done)) 100 else 1)

results <- bind_rows(done, results)
write_csv(results, output_path)
cat(sprintf("Wrote %d rows to %s\n", nrow(results), output_path))
print(count(results, cluster_id, sort = TRUE))
