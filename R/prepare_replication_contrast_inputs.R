# Run from project root. Optional arguments: annual_panel.rds output_directory
# Fetch a pinned FLoRA export and reconcile it with known legacy treatments.
source("R/replication_contrast.R")
suppressPackageStartupMessages(library(dplyr))
args <- commandArgs(trailingOnly = TRUE)
panel_path <- if (length(args)) args[1] else "data/analysis_pad_Scopus.rds"
out <- if (length(args) > 1L) args[2] else "data/replication_contrast"
dir.create(out, recursive = TRUE, showWarnings = FALSE)
revision <- "9d77ad8d801b4758cffe6a4d8ea7ce6902f39f45"
url <- paste0("https://raw.githubusercontent.com/forrtproject/fred-data/", revision, "/output/flora.csv")
raw_path <- file.path(out, "flora.csv")
utils::download.file(url, raw_path, mode = "wb", quiet = TRUE)
flora <- read.csv(raw_path, stringsAsFactors = FALSE)
flora$source_snapshot <- paste0("fred-data@", revision)
columns <- c("doi_o", "doi_r", "url_r", "year_r", "outcome", "type", "source_snapshot")
rc_require(flora, columns)
missing_doi <- is.na(rc_doi(flora$doi_o))
write.csv(flora[missing_doi, columns], file.path(out, "missing_original_doi.csv"), row.names = FALSE)
events <- flora[!missing_doi, columns]
# A newer registry may remove/revise legacy records. Retain all known attempts
# so previously treated controls cannot silently enter the untreated donor pool.
legacy <- readRDS("data/metadata_OpenAlex.rds")
legacy$year_r <- legacy$publication_year_r
legacy$type <- legacy$type.x
legacy$source_snapshot <- "legacy_metadata_OpenAlex.rds"
events <- unique(rbind(events, as.data.frame(legacy)[columns]))
events <- events[!is.na(rc_doi(events$doi_o)), ]
write.csv(events, file.path(out, "events.csv"), row.names = FALSE)
panel <- readRDS(panel_path)
if (!"sjr" %in% names(panel)) {
  rc_require(panel, "issn_l")
  panel <- panel %>% mutate(issn_l = gsub("-", "", issn_l))
  journals <- readRDS("data/df_journals_L.rds")
  journals <- journals %>% transmute(year, issn_l = gsub("-", "", issn), sjr) %>%
    filter(!is.na(issn_l), grepl("^[0-9]{7}[0-9Xx]$", issn_l), is.finite(sjr)) %>%
    semi_join(panel, by = c("year", "issn_l")) %>% distinct()
  if (anyDuplicated(journals[c("year", "issn_l")])) stop("Conflicting journal-year SJR values.")
  panel <- panel %>% left_join(journals, by = c("year", "issn_l")) %>%
    arrange(doi_queried, year) %>% group_by(doi_queried) %>%
    tidyr::fill(sjr, .direction = "down") %>% ungroup()
}
write.csv(panel[!is.finite(panel$sjr), c("doi_queried", "year")],
  file.path(out, "missing_sjr.csv"), row.names = FALSE)
panel <- panel[is.finite(panel$sjr), ]
saveRDS(panel, file.path(out, "panel.rds"))
registry <- replication_registry(events)
registry$in_panel <- registry$doi_queried %in% rc_doi(panel$doi_queried)
write.csv(registry, file.path(out, "registry_coverage.csv"), row.names = FALSE)
write.csv(registry[registry$reason == "eligible" & !registry$in_panel, ],
  file.path(out, "citation_collection_needed.csv"), row.names = FALSE)
prepared <- prepare_replication_contrast(panel, events, require_support = FALSE)
write.csv(prepared$support, file.path(out, "cohort_support.csv"), row.names = FALSE)
write.csv(prepared$audit, file.path(out, "sample_audit.csv"), row.names = FALSE)
writeLines(c(paste("FLoRA URL:", url), paste("FLoRA MD5:", tools::md5sum(raw_path)),
  paste("Panel:", panel_path), paste("Panel MD5:", tools::md5sum(panel_path)),
  paste("Legacy metadata MD5:", tools::md5sum("data/metadata_OpenAlex.rds")),
  paste("Missing original DOI records:", sum(missing_doi))), file.path(out, "sources.txt"))
print(with(registry, table(reason, replication_outcome, in_panel)))
print(prepared$support)
message("Inputs and coverage audit written to ", out,
  ". Inspect citation_collection_needed.csv before interpreting a fitted contrast.")
