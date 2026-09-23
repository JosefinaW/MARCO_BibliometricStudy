# Writes data/flora_replications.csv: every replication DOI recorded in FLoRA,
# whatever the outcome. The registration defines the comparator pool as articles
# that are neither replicated nor replications; this list removes the latter.
# Reproductions are not replications and are not listed.
# To update, set flora_commit to a newer fred-data commit and rerun.
suppressPackageStartupMessages(library(tidyverse))

flora_commit <- "cb02db7930176d05964d3afe98f460ffa364f366" # 2026-09-23
flora_url <- paste0("https://raw.githubusercontent.com/forrtproject/fred-data/",
                    flora_commit, "/output/flora.csv")

norm_doi <- function(x) {
  x <- tolower(gsub("[[:space:]]", "", as.character(x)))
  x <- sub("^https?://(dx\\.)?doi\\.org/", "", x)
  x[x %in% c("", "na")] <- NA_character_
  x
}

flora <- read_csv(flora_url, show_col_types = FALSE, guess_max = Inf) %>%
  filter(type == "replication") %>%
  transmute(doi_r = norm_doi(doi_r), year_r = as.integer(year_r),
            outcome = coalesce(na_if(trimws(outcome), ""), "<missing>")) %>%
  filter(!is.na(doi_r))

# One replication paper can replicate many originals, so n_originals counts the
# originals a given replication DOI reports on. year_r is the replication's own
# publication year and should be constant within doi_r.
replications <- flora %>%
  group_by(doi_r) %>%
  summarise(n_originals = n(),
            outcomes = paste(sort(unique(outcome)), collapse = " | "),
            year_r = if (all(is.na(year_r))) NA_integer_ else min(year_r, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(flora_commit = flora_commit) %>%
  arrange(doi_r)

stopifnot(nrow(replications) > 100, !anyDuplicated(replications$doi_r))
write_csv(replications, "data/flora_replications.csv")
message(nrow(replications), " replications written from fred-data@", substr(flora_commit, 1, 7))
