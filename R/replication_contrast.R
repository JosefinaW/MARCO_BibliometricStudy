# Success minus failure in citation effects relative to no recorded replication.
# All model fits mask post-replication observations in BOTH outcome groups.

rc_require <- function(x, columns) {
  missing <- setdiff(columns, names(x))
  if (length(missing)) stop("Missing columns: ", paste(missing, collapse = ", "))
}

rc_doi <- function(x) {
  x <- tolower(gsub("\\s+", "", as.character(x)))
  x <- sub("^(https?://(dx\\.)?doi\\.org/|doi:)", "", x)
  x[x %in% c("", "na")] <- NA_character_
  x
}

rc_year <- function(x) {
  z <- suppressWarnings(as.numeric(as.character(x)))
  z[!is.finite(z) | z != floor(z) | z < 1000 | z > 3000] <- NA_real_
  as.integer(z)
}

# Keep every recorded attempt, including unknown outcomes and out-of-window years.
# Same-year first attempts must agree. Later attempts censor follow-up, regardless
# of outcome; undated attempts prevent establishing a paper's treatment history.
replication_registry <- function(events, cohort_years = 2011:2021) {
  rc_require(events, c("doi_o", "outcome"))
  if (!"year_r" %in% names(events)) {
    rc_require(events, "publication_year_r")
    events$year_r <- events$publication_year_r
  }
  events$doi_o <- rc_doi(events$doi_o)
  if (anyNA(events$doi_o)) stop("Every replication record needs an original DOI.")
  events$year_r <- rc_year(events$year_r)
  events$outcome <- tolower(trimws(as.character(events$outcome)))
  events$outcome[events$outcome %in% c("success", "succeeded")] <- "successful"
  if (!"doi_r" %in% names(events)) events$doi_r <- NA_character_
  if (!"url_r" %in% names(events)) events$url_r <- NA_character_
  events$replication_id <- rc_doi(events$doi_r)
  no_id <- is.na(events$replication_id)
  events$replication_id[no_id] <- trimws(events$url_r[no_id])
  events$replication_id[events$replication_id == ""] <- NA_character_
  registry <- do.call(rbind, lapply(split(events, events$doi_o), function(x) {
    dated <- !anyNA(x$year_r)
    inconsistent_dates <- any(vapply(split(x$year_r, x$replication_id),
      function(y) length(unique(y[!is.na(y)])) > 1L, logical(1)))
    first <- if (dated) min(x$year_r) else NA_integer_
    first_outcomes <- if (dated) unique(x$outcome[x$year_r == first]) else NA_character_
    known <- length(first_outcomes) == 1L && !is.na(first_outcomes) &&
      first_outcomes %in% c("successful", "failed")
    replication <- !"type" %in% names(x) || (dated &&
      all(!is.na(x$type[x$year_r == first]) & x$type[x$year_r == first] == "replication"))
    reason <- if (!dated) "undated_attempt" else if (inconsistent_dates) "conflicting_attempt_year" else
      if (!known) "ambiguous_first_outcome" else
      if (!replication) "first_event_not_replication" else
      if (!first %in% cohort_years) "cohort_outside_window" else "eligible"
    later <- if (dated) x$year_r[x$year_r > first] else integer()
    data.frame(doi_queried = x$doi_o[1], cohort = first,
      replication_outcome = if (known) first_outcomes else NA_character_,
      censor_year = if (length(later)) min(later) else Inf, reason = reason)
  }))
  if (is.null(registry)) stop("The full replication registry is empty.")
  rownames(registry) <- NULL

  # Connected components retain dependence when replication publications overlap
  # across originals. Missing replication IDs are audited, not assumed observed.
  parent <- seq_len(nrow(registry))
  root <- function(i) { while (parent[i] != i) i <- parent[i]; i }
  for (ids in split(events$doi_o, events$replication_id)) {
    ids <- unique(match(ids, registry$doi_queried))
    if (length(ids) > 1L) for (j in ids[-1]) parent[root(j)] <- root(ids[1])
  }
  registry$cluster <- paste0("rep_", vapply(seq_len(nrow(registry)), root, integer(1)))
  registry$missing_replication_id <- vapply(registry$doi_queried, function(id)
    anyNA(events$replication_id[events$doi_o == id]), logical(1))
  registry
}

# Input is an explicitly observed annual panel; absent rows are never converted to
# zero citations here. Missing retrievals must be resolved upstream.
prepare_replication_contrast <- function(panel, events, cohort_years = 2011:2021,
    event_times = 0:6, min_pre = 5L, min_cell = 5L, min_clusters = 5L,
    require_support = TRUE) {
  rc_require(panel, c("doi_queried", "year", "n_citations", "sjr"))
  if (!length(event_times) || anyNA(event_times) || any(event_times < 0) ||
      any(event_times != floor(event_times)) || anyDuplicated(event_times))
    stop("event_times must be distinct non-negative integers.")
  if (min_pre < 2 || min_cell < 1 || min_clusters < 2) stop("Invalid minimum sample sizes.")
  registry <- replication_registry(events, cohort_years)
  panel <- as.data.frame(panel)
  panel$doi_queried <- rc_doi(panel$doi_queried)
  panel$year <- rc_year(panel$year)
  if (anyNA(panel[c("doi_queried", "year")]) ||
      anyDuplicated(panel[c("doi_queried", "year")])) stop("Invalid or duplicate paper-year rows.")
  if (!is.numeric(panel$n_citations) || !is.numeric(panel$sjr) ||
      any(!is.finite(panel$n_citations)) || any(panel$n_citations < 0) ||
      any(!is.finite(panel$sjr))) stop("Resolve missing/non-finite citations and SJR before fitting.")
  if ("D" %in% names(panel) && any(panel$D == 1 &
      !panel$doi_queried %in% registry$doi_queried, na.rm = TRUE))
    stop("Input-treated papers are missing from the replication registry.")
  audit <- merge(registry, data.frame(doi_queried = unique(panel$doi_queried),
    in_panel = TRUE), all.x = TRUE, sort = FALSE)
  audit$in_panel[is.na(audit$in_panel)] <- FALSE
  if (any(!audit$in_panel & audit$reason == "eligible"))
    warning("Eligible replicated papers lack citation panels; inspect the coverage audit.")
  # Discard stale treatment/group columns before rebuilding from the full registry.
  panel <- panel[c("doi_queried", "year", "n_citations", "sjr")]
  panel <- merge(panel, registry, by = "doi_queried", all.x = TRUE, sort = FALSE)
  control <- is.na(panel$reason)
  panel$replication_outcome[control] <- "control"
  panel$cluster[control] <- paste0("control_", panel$doi_queried[control])
  panel <- panel[control | panel$reason == "eligible", ]
  panel <- panel[is.na(panel$censor_year) | panel$year < panel$censor_year, ]
  panel$D <- as.integer(!is.na(panel$cohort) & panel$year >= panel$cohort)
  panel$event_time <- panel$year - panel$cohort
  groups <- split(panel, panel$doi_queried)
  enough_pre <- vapply(groups, function(x) sum(x$D == 0) >= min_pre, logical(1))
  panel <- panel[panel$doi_queried %in% names(groups)[enough_pre], ]
  # Balance the target papers across the entire event window. Other eligible
  # papers still enter the model, with all their post-treatment outcomes masked.
  target <- vapply(groups, function(x) any(x$D == 1) &&
    sum(x$D == 0) >= min_pre && all(event_times %in% x$event_time), logical(1))
  panel$target <- panel$doi_queried %in% names(groups)[target]
  units <- unique(panel[panel$target, c("doi_queried", "cohort", "replication_outcome", "cluster")])
  counts <- table(factor(units$cohort, levels = cohort_years),
                  factor(units$replication_outcome, levels = c("successful", "failed")))
  independent <- unique(units[c("cohort", "replication_outcome", "cluster")])
  cluster_counts <- table(factor(independent$cohort, levels = cohort_years),
    factor(independent$replication_outcome, levels = c("successful", "failed")))
  common <- rowSums(counts >= min_cell) == 2L & rowSums(cluster_counts >= min_clusters) == 2L
  if (!any(common) && require_support) stop("No common cohorts with sufficient successful AND failed papers and independent clusters. ",
    "Supply the full outcome registry and expanded citation panel; the failed-only caches are insufficient.")
  support <- data.frame(cohort = cohort_years, successful = counts[, 1], failed = counts[, 2],
    successful_clusters = cluster_counts[, 1], failed_clusters = cluster_counts[, 2],
    included = common, row.names = NULL)
  weights <- rowSums(counts[common, , drop = FALSE])
  weights <- weights / sum(weights)
  panel$target <- panel$target & panel$cohort %in% as.integer(names(weights))
  panel <- panel[order(panel$doi_queried, panel$year), ]
  if (!any(panel$replication_outcome == "control")) stop("Never-replicated controls are required.")
  audit$in_fit <- audit$doi_queried %in% panel$doi_queried
  audit$in_contrast <- audit$doi_queried %in% panel$doi_queried[panel$target]
  list(panel = panel, audit = audit, support = support, weights = weights,
       event_times = event_times, min_pre = min_pre, min_cell = min_cell,
       min_clusters = min_clusters)
}

fit_replication_ife <- function(panel, r, min_pre, seed, cv = FALSE) {
  fect::fect(n_citations ~ D + sjr, data = panel,
    index = c("doi_queried", "year"), method = "ife", force = "two-way",
    r = r, CV = cv, se = FALSE, min.T0 = min_pre, parallel = FALSE, seed = seed)
}

# Hold out the two years immediately preceding publication. These are prediction
# diagnostics, not fitted pre-period residuals or tests proving identification.
replication_placebo <- function(prepared, r, seed, periods = 2L) {
  p <- prepared$panel
  p <- p[is.na(p$cohort) | p$year < p$cohort, ]
  complete <- vapply(split(p[p$target, ], p$doi_queried[p$target]),
    function(x) all(seq.int(-periods, -1L) %in% (x$year - x$cohort)), logical(1))
  if (!all(complete)) stop("Target papers lack complete held-out pretreatment years.")
  p$cohort <- p$cohort - periods
  p$D <- as.integer(!is.na(p$cohort) & p$year >= p$cohort)
  p$event_time <- p$year - p$cohort
  w <- prepared$weights
  names(w) <- as.character(as.integer(names(w)) - periods)
  f <- fit_replication_ife(p, r, prepared$min_pre, seed)
  out <- contrast_from_fit(f, p, w, 0:(periods - 1L), 0:(periods - 1L))
  out$period[out$period != "primary"] <- as.character(
    as.integer(out$period[out$period != "primary"]) - periods)
  out
}

contrast_from_fit <- function(fit, panel, weights, event_times, primary_times = 2:6) {
  if (!all(primary_times %in% event_times) || !length(primary_times))
    stop("Primary times must be contained in event_times.")
  x <- panel[panel$target & panel$event_time %in% event_times, ]
  row <- match(as.character(x$year), rownames(fit$eff))
  col <- match(x$doi_queried, colnames(fit$eff))
  if (anyNA(row) || anyNA(col)) stop("fect dropped target paper-years.")
  at <- cbind(row, col)
  if (any(fit$D.dat[at] != 1) || any(fit$I.dat[at] != 1)) stop("Target cells are not observed treated cells.")
  x$effect <- fit$eff[at]
  if (any(!is.finite(x$effect))) stop("Non-finite counterfactual gaps.")
  effects <- do.call(rbind, lapply(event_times, function(k) {
    att <- vapply(c("successful", "failed"), function(type) {
      by_cohort <- vapply(names(weights), function(g) {
        z <- x$effect[x$event_time == k & x$replication_outcome == type & x$cohort == as.integer(g)]
        if (!length(z)) stop("A bootstrap sample lacks a target outcome/cohort cell.")
        mean(z)
      }, numeric(1))
      sum(weights * by_cohort)
    }, numeric(1))
    data.frame(period = as.character(k), successful = att[1], failed = att[2],
      delta = unname(att[1] - att[2]), row.names = NULL)
  }))
  primary <- colMeans(effects[effects$period %in% as.character(primary_times),
                              c("successful", "failed", "delta"), drop = FALSE])
  rbind(effects, data.frame(period = "primary", as.list(primary), row.names = NULL))
}

# Repeated cluster draws receive NEW paper identifiers; multiplicity is retained.
resample_replication_clusters <- function(panel, sampled = NULL) {
  clusters <- unique(panel$cluster)
  if (is.null(sampled)) sampled <- sample(clusters, length(clusters), replace = TRUE)
  if (any(!sampled %in% clusters)) stop("Unknown sampled cluster.")
  do.call(rbind, lapply(seq_along(sampled), function(i) {
    x <- panel[panel$cluster == sampled[i], ]
    x$doi_queried <- paste0("draw", i, "_", x$doi_queried)
    x$cluster <- paste0("draw", i)
    x
  }))
}

run_replication_contrast <- function(prepared, nboots = 500L, r = 0:3,
    seed = 422L, primary_times = 2:6, max_failed_fraction = 0.05) {
  if (nboots < 2 || nboots != as.integer(nboots)) stop("At least two bootstrap draws are required.")
  if (!length(r) || anyNA(r) || any(r < 0 | r != floor(r)) || max(r) >= prepared$min_pre)
    stop("Factor counts must be non-negative integers below min_pre.")
  if (!all(primary_times %in% prepared$event_times) || !length(primary_times))
    stop("Primary times must be contained in event_times.")
  if (max_failed_fraction < 0 || max_failed_fraction >= 1) stop("Invalid failure tolerance.")
  if (!length(prepared$weights)) stop("No supported cohorts: inspect the preparation audit.")
  p <- prepared$panel
  fit <- fit_replication_ife(p, r, prepared$min_pre, seed, cv = length(r) > 1L)
  selected_r <- fit$r.cv
  if (length(selected_r) != 1L || !selected_r %in% r) stop("Cannot identify selected factor count.")
  point <- contrast_from_fit(fit, p, prepared$weights, prepared$event_times, primary_times)
  draws <- vector("list", nboots)
  failures <- rep(NA_character_, nboots)
  # Independent seeds avoid dependence on fect's internal RNG consumption.
  set.seed(seed)
  seeds <- sample.int(.Machine$integer.max, nboots)
  for (b in seq_len(nboots)) {
    message("Joint cluster bootstrap ", b, "/", nboots)
    draws[[b]] <- tryCatch({
      set.seed(seeds[b])
      boot <- resample_replication_clusters(p)
      fb <- fit_replication_ife(boot, selected_r, prepared$min_pre, seeds[b])
      result <- contrast_from_fit(fb, boot, prepared$weights, prepared$event_times, primary_times)
      result$draw <- b
      result
    }, error = function(e) { failures[b] <<- conditionMessage(e); NULL })
  }
  valid <- sum(is.na(failures))
  inference_ok <- valid >= 2L && (nboots - valid) / nboots <= max_failed_fraction
  boot <- do.call(rbind, draws)
  intervals <- do.call(rbind, lapply(seq_len(nrow(point)), function(i) {
    do.call(rbind, lapply(c("successful", "failed", "delta"), function(estimand) {
      values <- if (valid) boot[boot$period == point$period[i], estimand] else numeric()
      se <- if (inference_ok) sd(values) else NA_real_
      estimate <- point[[estimand]][i]
      q <- if (inference_ok) unname(quantile(values, c(.025, .975))) else c(NA_real_, NA_real_)
      data.frame(period = point$period[i], estimand = estimand, estimate = estimate,
        se = se, lower = estimate - qnorm(.975) * se, upper = estimate + qnorm(.975) * se,
        percentile_lower = q[1], percentile_upper = q[2], valid_draws = valid)
    }))
  }))
  if (!inference_ok) warning("Too many failed bootstrap draws; intervals withheld. Inspect failures.")
  placebo <- tryCatch(replication_placebo(prepared, selected_r, seed),
    error = function(e) data.frame(error = conditionMessage(e)))
  list(estimates = intervals, draws = boot,
    failures = data.frame(draw = seq_len(nboots), error = failures),
    inference_ok = inference_ok, fit = fit, audit = prepared$audit,
    support = prepared$support, weights = prepared$weights, placebo = placebo,
    settings = list(nboots = nboots, selected_r = selected_r, candidate_r = r,
      seed = seed, primary_times = primary_times, event_times = prepared$event_times,
      min_pre = prepared$min_pre, max_failed_fraction = max_failed_fraction,
      min_cell = prepared$min_cell, min_clusters = prepared$min_clusters,
      fect_version = as.character(utils::packageVersion("fect"))))
}
