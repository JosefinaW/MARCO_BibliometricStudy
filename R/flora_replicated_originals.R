# Writes data/flora_replicated_originals.csv: every original DOI with at least one
# replication record in FLoRA, whatever the outcome. The registration defines the
# comparator pool as non-replicated articles; this list removes the rest.
# Reproductions are not replications and are not listed.
# To update, set flora_commit to a newer fred-data commit and rerun.
suppressPackageStartupMessages(library(tidyverse))

flora_commit <- "aa55025cbcdb46860e73d77ec49a980bef2251d4" # 2026-09-21
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
  transmute(doi_o = norm_doi(doi_o), year_r = as.integer(year_r),
            outcome = coalesce(na_if(trimws(outcome), ""), "<missing>")) %>%
  filter(!is.na(doi_o))

replicated <- flora %>%
  group_by(doi_o) %>%
  summarise(n_replications = n(),
            outcomes = paste(sort(unique(outcome)), collapse = " | "),
            first_year_r = if (all(is.na(year_r))) NA_integer_ else min(year_r, na.rm = TRUE),
            .groups = "drop") %>%
  mutate(flora_commit = flora_commit) %>%
  arrange(doi_o)

stopifnot(nrow(replicated) > 2000, !anyDuplicated(replicated$doi_o))
write_csv(replicated, "data/flora_replicated_originals.csv")
message(nrow(replicated), " replicated originals written from fred-data@", substr(flora_commit, 1, 7))
