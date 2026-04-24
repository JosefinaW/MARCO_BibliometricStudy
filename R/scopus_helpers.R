# Shared Scopus helper functions for citing-study retrieval

source("R/api_cache.R")

scopus_search_cursor <- function(query, api_key, count = 200, view = "STANDARD",
                                 wait_time = 0.2, max_records = Inf) {
  out <- list()
  next_cursor <- "*"
  n_total <- 0L

  repeat {
    res <- api_cache(
      service = "scopus_search_cursor_page",
      key = list(
        query = query,
        count = count,
        cursor = next_cursor,
        view = view
      ),
      code = {
        r <- httr::GET(
          "https://api.elsevier.com/content/search/scopus",
          query = list(
            query = query,
            count = count,
            cursor = next_cursor,
            view = view,
            APIKey = api_key
          ),
          httr::add_headers("X-ELS-ResourceVersion" = "allexpand")
        )

        httr::stop_for_status(r)

        txt <- httr::content(r, as = "text", encoding = "UTF-8")
        jsonlite::fromJSON(txt, flatten = TRUE)
      }
    )
    sr  <- res$`search-results`

    entries <- sr$entry
    if (is.null(entries) || length(entries) == 0) break

    df <- tibble::as_tibble(entries)
    out[[length(out) + 1]] <- df
    n_total <- n_total + nrow(df)

    if (n_total >= max_records) break

    next_cursor <- sr$cursor$`@next`
    if (is.null(next_cursor) || is.na(next_cursor) || next_cursor == "") break

    Sys.sleep(wait_time)
  }

  dplyr::bind_rows(out)
}

sanitize_doi <- function(x) {
  gsub("[^A-Za-z0-9._-]", "_", x)
}

append_csv <- function(df, path) {
  append_csv_atomic(df, path, na = "")
}

append_results_csv <- function(df, path) {
  append_csv_atomic(df, path, dedupe_by = c("doi_queried", "citing_eid"), na = "")
}

append_log <- function(doi, status, log_csv, message = NA_character_, queried_eid = NA_character_) {
  log_row <- tibble::tibble(
    doi = doi,
    status = status,
    queried_eid = queried_eid,
    message = message,
    timestamp = as.character(Sys.time())
  )
  append_csv(log_row, log_csv)
}

pick_col <- function(df, candidates) {
  hit <- candidates[candidates %in% names(df)]
  if (length(hit) == 0) {
    return(rep(NA_character_, nrow(df)))
  }
  as.character(df[[hit[1]]])
}

empty_citers <- tibble::tibble(
  doi_queried    = character(),
  queried_eid    = character(),
  citing_eid     = character(),
  citing_doi     = character(),
  citing_title   = character(),
  citing_journal = character(),
  citing_date    = character()
)

process_one_doi <- function(doi, api_key, raw_dir, raw_suffix = "_doc.rds",
                            count = 200, max_count = 20000, wait_time = 0.2) {
  safe_doi <- sanitize_doi(doi)

  # 1) DOI -> target document
  res0 <- api_cache(
    service = "scopus_search_doi",
    key = list(doi = doi),
    code = rscopus::scopus_search(
      query = sprintf("DOI(%s)", doi),
      count = 1,
      start = 0,
      view = "STANDARD",
      max_count = 1,
      verbose = FALSE
    )
  )

  save_rds_atomic(res0, file.path(raw_dir, paste0(safe_doi, raw_suffix)))

  if (length(res0$entries) == 0) {
    stop("No Scopus document found for DOI query.")
  }

  df0 <- rscopus::gen_entries_to_df(res0$entries)$df
  if (nrow(df0) == 0 || !"eid" %in% names(df0)) {
    stop("Could not extract EID from DOI query result.")
  }

  queried_eid <- as.character(df0$eid[[1]])
  if (is.na(queried_eid) || queried_eid == "") {
    stop("EID is missing or empty.")
  }

  # 2) target EID -> citing documents
  citers_df <- scopus_search_cursor(
    query = sprintf("REFEID(%s)", queried_eid),
    api_key = api_key,
    count = 200,
    view = "STANDARD",
    wait_time = 0.2
  )

  # handle empty pseudo-result rows
  if (nrow(citers_df) == 0 || "error" %in% names(citers_df)) {
    return(empty_citers)
  }

  tibble::tibble(
    doi_queried    = doi,
    queried_eid    = queried_eid,
    citing_eid     = pick_col(citers_df, c("eid")),
    citing_doi     = pick_col(citers_df, c("prism.doi", "prism:doi", "doi")),
    citing_title   = pick_col(citers_df, c("dc:title", "dc.title", "title")),
    citing_journal = pick_col(citers_df, c("prism.publicationName", "prism:publicationName", "journal")),
    citing_date    = pick_col(citers_df, c("prism.coverDate", "prism:coverDate", "cover_date"))
  ) |>
    dplyr::distinct(doi_queried, citing_eid, .keep_all = TRUE)
}

run_scopus_citing_pipeline <- function(dois, api_key, raw_dir, out_csv, log_csv,
                                       raw_suffix = "_doc.rds") {
  dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)

  # restart-safe: skip DOIs already completed successfully
  done_ok <- character()
  if (file.exists(log_csv)) {
    log_df <- read.csv(log_csv, stringsAsFactors = FALSE)
    done_ok <- unique(log_df$doi[log_df$status == "ok"])
  }

  to_run <- setdiff(dois, done_ok)

  for (doi in to_run) {
    message("Processing: ", doi)

    tryCatch(
      {
        cleaned <- process_one_doi(doi, api_key = api_key, raw_dir = raw_dir,
                                   raw_suffix = raw_suffix)

        if (nrow(cleaned) > 0) {
          append_results_csv(cleaned, out_csv)
        }

        queried_eid <- if (nrow(cleaned) > 0) cleaned$queried_eid[1] else NA_character_
        append_log(
          doi = doi,
          status = "ok",
          log_csv = log_csv,
          message = paste("Rows written:", nrow(cleaned)),
          queried_eid = queried_eid
        )
      },
      error = function(e) {
        append_log(
          doi = doi,
          status = "error",
          log_csv = log_csv,
          message = conditionMessage(e),
          queried_eid = NA_character_
        )
        message("Failed: ", doi, " -- ", conditionMessage(e))
      }
    )
  }
}
