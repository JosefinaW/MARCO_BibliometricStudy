# Shared OpenCitations helper functions for citing-study retrieval

oc_needed_cols <- c("citing", "cited", "source", "creation", "timespan", "journal_sc", "doi_queried")

oc_ensure_output <- function(outfile) {
  if (!file.exists(outfile)) {
    data.table::fwrite(
      data.frame(
        citing = character(),
        cited = character(),
        source = character(),
        creation = character(),
        timespan = character(),
        journal_sc = character(),
        doi_queried = character(),
        stringsAsFactors = FALSE
      ),
      file = outfile
    )
  }
}

oc_sleep_from_resp <- function(resp, default = 0.5) {
  ra <- httr::headers(resp)[["retry-after"]]
  secs <- suppressWarnings(as.numeric(ra))
  if (!is.null(ra) && !is.na(secs)) secs else default
}

oc_parse_payload <- function(txt, doi) {
  parsed <- tryCatch(jsonlite::fromJSON(txt, flatten = TRUE), error = function(e) NULL)
  if (is.null(parsed)) {
    return(NULL)
  }

  if (is.data.frame(parsed) && nrow(parsed) > 0) {
    parsed$doi_queried <- doi
    missing <- setdiff(oc_needed_cols, names(parsed))
    if (length(missing)) parsed[missing] <- NA_character_
    parsed[oc_needed_cols]
  } else {
    NULL
  }
}

oc_base_fetch <- function(doi, base_url, access_token) {
  url <- paste0(base_url, utils::URLencode(doi, reserved = TRUE))

  resp <- httr::GET(
    url,
    httr::accept_json(),
    if (nzchar(access_token)) httr::add_headers(authorization = access_token)
  )

  code <- httr::status_code(resp)

  if (code == 200) {
    txt <- httr::content(resp, as = "text", encoding = "UTF-8")
    df <- oc_parse_payload(txt, doi)
    if (is.null(df)) {
      stop(sprintf("Parse failed for %s", doi))
    }
    return(list(df = df, failed = FALSE, not_found = FALSE))
  }

  if (code == 404) {
    message("  Not found in OpenCitations index: ", doi)
    return(list(df = NULL, failed = FALSE, not_found = TRUE))
  }

  if (code %in% c(429, 500, 502, 503, 504)) {
    Sys.sleep(oc_sleep_from_resp(resp, default = 1))
    stop(sprintf("Retryable HTTP %s for %s", code, doi))
  }

  warning(sprintf("Non-retryable HTTP %s for %s", code, doi))
  list(df = NULL, failed = TRUE, not_found = FALSE)
}

run_oc_citing_pipeline <- function(dois, access_token,
                                   base_url = "https://api.opencitations.net/index/v2/citations/doi:",
                                   outfile, checkpoint_rds, failed_log,
                                   chunk_size = 100, throttle_s = 0.15) {

  oc_ensure_output(outfile)

  # resume support
  start_idx <- if (file.exists(checkpoint_rds)) as.integer(readRDS(checkpoint_rds)) else 1L
  if (start_idx == 1L && file.exists(failed_log)) file.remove(failed_log)

  # purrr rate & retry wrappers
  backoff <- purrr::rate_backoff(pause_base = 1, pause_cap = 60, jitter = TRUE)
  throttle <- purrr::rate_delay(pause = throttle_s)

  # closure over base_url and access_token
  fetch_one <- function(doi) oc_base_fetch(doi, base_url, access_token)

  fetch_wrapped <- purrr::slowly(
    purrr::insistently(fetch_one, rate = backoff, quiet = TRUE),
    rate = throttle,
    quiet = TRUE
  )

  fetch_safe <- purrr::safely(fetch_wrapped, otherwise = NULL)

  # chunked processing with append & checkpoint
  n <- length(dois)

  if (start_idx > n) {
    message("All DOIs already processed according to checkpoint. Nothing to do.")
    return(invisible(NULL))
  }

  remaining <- dois[start_idx:n]
  groups <- split(remaining, ceiling(seq_along(remaining) / chunk_size))

  purrr::walk2(groups, seq_along(groups), function(chunk, gidx) {
    rng <- c(
      start_idx + (gidx - 1L) * chunk_size,
      min(start_idx + gidx * chunk_size - 1L, n)
    )
    message(sprintf("Processing DOIs %d-%d of %d", rng[1], rng[2], n))

    res <- purrr::map(rlang::set_names(chunk, chunk), fetch_safe)

    ok <- purrr::keep(res, ~ is.null(.x$error) && !is.null(.x$result$df))
    dfs <- purrr::map(ok, ~ .x$result$df)

    if (length(dfs)) {
      out <- data.table::rbindlist(dfs, use.names = TRUE, fill = TRUE)
      if (nrow(out)) data.table::fwrite(out, file = outfile, append = TRUE)
      rm(out)
    }

    failed_nonretry <- names(purrr::keep(res, ~ is.null(.x$error) && isTRUE(.x$result$failed)))
    failed_errors <- names(purrr::keep(res, ~ !is.null(.x$error)))
    failed_local <- c(failed_nonretry, failed_errors)

    if (length(failed_local)) {
      write(failed_local, file = failed_log, append = TRUE, ncolumns = 1)
    }

    last_idx <- rng[2]
    saveRDS(last_idx + 1L, checkpoint_rds)

    rm(res, dfs, ok)
    gc()
  })
}
