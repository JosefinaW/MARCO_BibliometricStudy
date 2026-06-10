# Shared lightweight API cache helpers.
# Cache keys are based on serialized request parameters and stored under data/api_cache/.

api_cache_normalize <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }

  if (is.list(x) && !is.data.frame(x)) {
    nms <- names(x)
    if (!is.null(nms) && any(nzchar(nms))) {
      x <- x[order(nms)]
    }
    return(lapply(x, api_cache_normalize))
  }

  if (is.atomic(x)) {
    return(unname(x))
  }

  x
}

api_cache_key <- function(key) {
  payload <- api_cache_key_json(key)
  tf <- tempfile(fileext = ".json")
  on.exit(unlink(tf), add = TRUE)
  writeLines(payload, tf, useBytes = TRUE)
  unname(tools::md5sum(tf))
}

api_cache_key_json <- function(key) {
  as.character(jsonlite::serializeJSON(api_cache_normalize(key), digits = NA))
}

save_rds_atomic <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(
    pattern = paste0(basename(path), "_"),
    tmpdir = dirname(path),
    fileext = ".tmp"
  )
  saveRDS(object, tmp)
  if (file.exists(path)) {
    file.remove(path)
  }
  ok <- file.rename(tmp, path)
  if (!ok) {
    stop("Failed to atomically write ", path)
  }
  invisible(path)
}

write_csv_atomic <- function(df, path, na = "") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(
    pattern = paste0(basename(path), "_"),
    tmpdir = dirname(path),
    fileext = ".tmp"
  )
  utils::write.csv(df, tmp, row.names = FALSE, na = na)
  if (file.exists(path)) {
    file.remove(path)
  }
  ok <- file.rename(tmp, path)
  if (!ok) {
    stop("Failed to atomically write ", path)
  }
  invisible(path)
}

append_csv_atomic <- function(df, path, dedupe_by = NULL, na = "") {
  existing <- if (file.exists(path)) {
    utils::read.csv(path, stringsAsFactors = FALSE)
  } else {
    df[0, , drop = FALSE]
  }

  combined <- dplyr::bind_rows(existing, df)

  if (!is.null(dedupe_by)) {
    combined <- combined[!duplicated(combined[dedupe_by]), , drop = FALSE]
  }

  write_csv_atomic(combined, path, na = na)
}

write_lines_atomic <- function(lines, path, unique_only = FALSE) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  existing <- if (file.exists(path)) readLines(path, warn = FALSE) else character()
  combined <- c(existing, lines)
  if (unique_only) {
    combined <- unique(combined)
  }

  tmp <- tempfile(
    pattern = paste0(basename(path), "_"),
    tmpdir = dirname(path),
    fileext = ".tmp"
  )
  writeLines(combined, tmp, useBytes = TRUE)
  if (file.exists(path)) {
    file.remove(path)
  }
  ok <- file.rename(tmp, path)
  if (!ok) {
    stop("Failed to atomically write ", path)
  }
  invisible(path)
}

api_cache_identifier <- function(key) {
  key <- api_cache_normalize(key)

  if (!is.list(key)) {
    return(substr(api_cache_key_json(key), 1, 120))
  }

  parts <- character()
  candidate_names <- c("doi", "id", "issn", "publication_year", "query", "cursor", "base_url", "stage")
  for (nm in candidate_names) {
    if (!is.null(key[[nm]])) {
      val <- paste(as.character(key[[nm]]), collapse = "|")
      parts <- c(parts, paste0(nm, "=", val))
    }
  }

  if (length(parts) == 0) {
    parts <- substr(api_cache_key_json(key), 1, 120)
  }

  paste(parts, collapse = "; ")
}

api_cache_update_index <- function(service, key, path, cache_root = "data/api_cache") {
  index_path <- file.path(cache_root, "index.csv")
  key_json <- api_cache_key_json(key)

  row <- tibble::tibble(
    service = service,
    identifier = api_cache_identifier(key),
    cache_path = path,
    cache_key_json = key_json,
    created_at = as.character(Sys.time())
  )

  existing <- if (file.exists(index_path)) {
    utils::read.csv(index_path, stringsAsFactors = FALSE)
  } else {
    row[0, , drop = FALSE]
  }

  existing <- existing[existing$cache_path != path, , drop = FALSE]
  combined <- dplyr::bind_rows(existing, row)
  combined <- dplyr::arrange(combined, service, identifier, created_at)

  write_csv_atomic(combined, index_path, na = "")
}

api_cache_path <- function(service, key, cache_root = "data/api_cache") {
  file.path(cache_root, service, paste0(api_cache_key(key), ".rds"))
}

api_cache <- function(service, key, code, cache_root = "data/api_cache") {
  expr <- substitute(code)
  path <- api_cache_path(service = service, key = key, cache_root = cache_root)

  if (file.exists(path)) {
    return(readRDS(path))
  }

  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  value <- eval(expr, envir = parent.frame())
  save_rds_atomic(value, path)
  api_cache_update_index(service = service, key = key, path = path, cache_root = cache_root)
  value
}

cached_oa_fetch <- function(..., cache_key = list(), cache_root = "data/api_cache") {
  args <- list(...)
  args_for_key <- args
  args_for_key$verbose <- NULL
  args_for_key$mailto <- NULL

  api_cache(
    service = "openalex_oa_fetch",
    key = c(cache_key, args_for_key),
    cache_root = cache_root,
    code = do.call(openalexR::oa_fetch, args)
  )
}

cached_citation_retrieval <- function(doi, api_key, date_range = c("1900", "2025"),
                                      cache_root = "data/api_cache") {
  api_cache(
    service = "scopus_citation_retrieval",
    key = list(doi = doi, date_range = date_range),
    cache_root = cache_root,
    code = {
      res <- rscopus::citation_retrieval(
        doi = doi,
        api_key = api_key,
        date_range = date_range
      )
      status <- httr::status_code(res$get_statement)
      parsed <- if (status < 400) rscopus::parse_citation_retrieval(res) else NULL
      list(status_code = status, parsed = parsed)
    }
  )
}

cached_scopus_cite_count <- function(doi, api_key, cache_root = "data/api_cache") {
  api_cache(
    service = "scopus_cite_count",
    key     = list(doi = doi),
    cache_root = cache_root,
    code = {
      res    <- rscopus::abstract_retrieval(
        id         = doi,
        identifier = "doi",
        api_key    = api_key
      )
      status <- httr::status_code(res$get_statement)
      # 200 = found, 404 = not indexed in Scopus, other = API error
      found  <- if (status == 200) TRUE
                else if (status == 404) FALSE
                else NA
      ct     <- if (!isTRUE(found)) NULL
                else res$content$`abstracts-retrieval-response`$coredata$`citedby-count`
      list(
        status_code = status,
        found       = found,
        count       = if (is.null(ct)) NA_integer_ else as.integer(ct)
      )
    }
  )
}

cached_abstract_retrieval <- function(id, identifier = "doi", api_key,
                                      cache_root = "data/api_cache") {
  api_cache(
    service = "scopus_abstract_retrieval",
    key = list(id = id, identifier = identifier),
    cache_root = cache_root,
    code = {
      res <- rscopus::abstract_retrieval(
        id = id,
        identifier = identifier,
        api_key = api_key
      )
      list(content = res$content)
    }
  )
}
