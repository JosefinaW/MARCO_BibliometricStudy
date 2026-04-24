# Shared data preparation helpers for pre-analysis
# Used by _05a_pre_analysis_data_prep_Scopus.Rmd and _05b_preanalysis_data_prep_OC.Rmd

#' Assign treatment variable D, clean up types, filter to valid years
prep_analysis_df <- function(df, replic_year, orig_year) {
  # join replication and original metadata
  df <- merge(df, replic_year, by.x = "doi_queried", by.y = "doi_o", all.x = TRUE)
  df <- merge(df, orig_year, by.x = "doi_queried", by.y = "doi", all.x = TRUE)

  # assign the treatment variable
  df <- df %>%
    dplyr::mutate(
      D = as.integer(!is.na(publication_year_r) & year >= publication_year_r)
    )

  # clean up types, deduplicate, filter
  df <- df %>%
    dplyr::distinct(doi_queried, year, .keep_all = TRUE) %>%
    dplyr::transmute(
      doi_queried = doi_queried,
      year = as.integer(year),
      n_citations = as.numeric(n_citations),
      D = as.integer(D),
      publication_year_r = as.integer(publication_year_r),
      publication_year = as.integer(publication_year),
      issn_l = issn_l
    ) %>%
    dplyr::arrange(doi_queried, year) %>%
    dplyr::filter(year < 2026, year >= publication_year)

  df
}

#' Pad panel so every doi-year from publication to y_max has a row (0 citations for missing years)
pad_panel <- function(df, y_max = 2025) {
  padded <- df %>%
    dplyr::arrange(doi_queried, year) %>%
    dplyr::mutate(.orig = TRUE) %>%
    dplyr::group_by(doi_queried) %>%
    dplyr::mutate(
      start_year = if (all(is.na(publication_year))) {
        min(year, na.rm = TRUE)
      } else {
        min(publication_year, na.rm = TRUE)
      }
    ) %>%
    tidyr::complete(
      year = seq(first(start_year), y_max),
      fill = list(.orig = FALSE)
    ) %>%
    dplyr::arrange(year, .by_group = TRUE) %>%
    dplyr::mutate(D_filled = D) %>%
    tidyr::fill(D_filled, .direction = "down") %>%
    dplyr::mutate(
      D_filled = tidyr::replace_na(D_filled, 0),
      D = ifelse(.orig, D, D_filled),
      n_citations = ifelse(.orig, n_citations, 0)
    ) %>%
    dplyr::select(-D_filled, -.orig, -start_year) %>%
    dplyr::ungroup() %>%
    dplyr::arrange(doi_queried, year)

  # forward/backward fill metadata columns (not the core panel columns)
  lock_cols <- c("doi_queried", "year", "n_citations", "D")
  cols_to_fill <- setdiff(names(padded), lock_cols)

  padded %>%
    dplyr::group_by(doi_queried) %>%
    tidyr::fill(dplyr::all_of(cols_to_fill), .direction = "downup") %>%
    dplyr::mutate(
      # Recompute treatment after padding so post-replication zero years
      # are correctly marked as treated.
      D = as.integer(!is.na(publication_year_r) & year >= publication_year_r)
    ) %>%
    dplyr::ungroup()
}

#' Compute citations excluding co-citations with the replication study
#' @param citations_raw Raw citing data (with a column identifying the citing study)
#' @param citations_rep Replication citing data (with doi_queried_r renamed, joined to replic_year)
#' @param citing_id_col Name of the column identifying the citing study in both datasets
#'   (e.g. "citing_eid" for Scopus, "citing" for OC)
#' @param analysis_padded The padded analysis dataframe to add n_nococit to
add_nococit <- function(citations_raw, citations_rep, citing_id_col,
                        analysis_padded) {
  # exclude co-citations: remove rows where the same paper cites both the original and its replication
  no_cocit <- citations_raw %>%
    dplyr::anti_join(
      citations_rep,
      by = stats::setNames(c(citing_id_col, "doi_o"), c(citing_id_col, "doi_queried"))
    )

  no_cocit_counts <- no_cocit %>%
    dplyr::group_by(doi_queried, year) %>%
    dplyr::summarise(n_nococit = dplyr::n(), .groups = "drop") %>%
    dplyr::mutate(year = as.numeric(year))

  analysis_padded %>%
    dplyr::left_join(
      no_cocit_counts %>% dplyr::select(doi_queried, year, n_nococit),
      by = c("doi_queried", "year")
    ) %>%
    # if there are no co-citations of the replication study,
    # n_nococit will be NA, and should be replaced by all citations
    dplyr::mutate(
      n_nococit = dplyr::coalesce(n_nococit, n_citations)
    )
}
