# Run: Rscript tests/test_replication_contrast.R
source("R/replication_contrast.R")
expect_error <- function(expr, pattern) {
  error <- tryCatch({ force(expr); NULL }, error = identity)
  stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error)))
}

events <- data.frame(doi_o = c("a", "a", "b", "b", "c", "d", "d", "e", "f"),
  doi_r = c("shared", "later", "shared", "shared", "c1", "d1", "d2", "e1", "f1"),
  year_r = c(2011, 2015, 2011, 2011, 2012, 2011, 2011, NA, 2010),
  outcome = c("successful", "failed", "failed", "failed", NA,
              "successful", "failed", "failed", "successful"))
r <- replication_registry(events)
stopifnot(r$censor_year[r$doi_queried == "a"] == 2015,
  r$cluster[r$doi_queried == "a"] == r$cluster[r$doi_queried == "b"],
  r$reason[r$doi_queried == "c"] == "ambiguous_first_outcome",
  r$reason[r$doi_queried == "d"] == "ambiguous_first_outcome",
  r$reason[r$doi_queried == "e"] == "undated_attempt",
  r$reason[r$doi_queried == "f"] == "cohort_outside_window")
events$type <- "replication"
events$type[events$doi_o == "b"] <- "reproduction"
stopifnot(replication_registry(events)$reason[2] == "first_event_not_replication")
conflict <- events[events$doi_o == "a", ]
conflict$doi_r <- "same_attempt"
stopifnot(replication_registry(conflict)$reason == "conflicting_attempt_year")
stopifnot(identical(rc_doi(c(" HTTPS://doi.org/10.X/ABC ", "doi:10.x/abc")), rep("10.x/abc", 2)))

set.seed(31)
units <- data.frame(doi_queried = sprintf("p%03d", 1:120),
  cohort = rep(c(2011, 2013, NA), each = 40),
  outcome = c(rep(rep(c("successful", "failed"), each = 20), 2), rep("control", 40)))
e <- data.frame(doi_o = units$doi_queried[1:80],
  doi_r = paste0("rep", rep(1:40, 2)), year_r = units$cohort[1:80], outcome = units$outcome[1:80])
p <- merge(expand.grid(doi_queried = units$doi_queried, year = 2000:2020), units)
id <- match(p$doi_queried, units$doi_queried)
p$sjr <- 1 + runif(nrow(p))
treated <- !is.na(p$cohort) & p$year >= p$cohort
p$n_citations <- 30 + id / 10 + (id / 30) * sin((p$year - 2000) / 2) +
  2 * p$sjr + rnorm(nrow(p), sd = 0.1) +
  ifelse(treated, ifelse(p$outcome == "successful", 2, -5), 0)
p$D <- as.integer(treated)
a <- prepare_replication_contrast(p, e)
stopifnot(sum(a$panel$target) == 80 * 21, length(a$weights) == 2,
  all(a$panel$D[a$panel$replication_outcome == "successful" & a$panel$event_time >= 0] == 1))

# Duplicate cluster draws preserve both original histories and their multiplicity.
cl <- a$panel$cluster[1]
b <- resample_replication_clusters(a$panel, c(cl, cl))
stopifnot(nrow(b) == 2 * sum(a$panel$cluster == cl),
  !anyDuplicated(b[c("doi_queried", "year")]), length(unique(b$doi_queried)) == 4)

# Model-independent check: common cohort weights, period averaging, and mapping
# must survive non-lexicographic rows/columns and unequal group sizes.
fake <- list(eff = matrix(NA_real_, 21, 120,
  dimnames = list(as.character(2020:2000), rev(units$doi_queried))))
fake$D.dat <- fake$I.dat <- fake$eff
for (i in seq_len(nrow(a$panel))) {
  x <- a$panel[i, ]; at <- cbind(match(as.character(x$year), rownames(fake$eff)),
                              match(x$doi_queried, colnames(fake$eff)))
  fake$eff[at] <- if (x$replication_outcome == "successful") 2 else -5
  fake$D.dat[at] <- x$D; fake$I.dat[at] <- 1
}
est <- contrast_from_fit(fake, a$panel, a$weights, 0:6)
stopifnot(all(est$delta == 7), all(est$successful == 2), all(est$failed == -5))
# Change cohort-specific effects and group composition: use the same explicit
# weights in each arm rather than each arm's marginal cohort proportions.
fake$eff[, units$doi_queried[units$cohort == 2013 & !is.na(units$cohort)]] <- 10
weighted <- contrast_from_fit(fake, a$panel, c(`2011` = .25, `2013` = .75), 0:6)
stopifnot(all(weighted$successful == 8), all(weighted$failed == 6.25), all(weighted$delta == 1.75))

# Never fill absent years with zero, silently use unknown outcomes as controls,
# retain follow-up after another replication, or admit stale treated controls.
later <- rbind(e, transform(e[1, ], doi_r = "second", year_r = 2015, outcome = "failed"))
censored <- prepare_replication_contrast(p, later)
stopifnot(!any(censored$panel$doi_queried == "p001" & censored$panel$year >= 2015),
  !any(censored$panel$target[censored$panel$doi_queried == "p001"]))
unknown <- e; unknown$outcome[1] <- NA
stopifnot(!"p001" %in% prepare_replication_contrast(p, unknown)$panel$doi_queried)
gapped <- p[!(p$doi_queried == "p001" & p$year == 2014), ]
stopifnot(!any(prepare_replication_contrast(gapped, e)$panel$target[
  prepare_replication_contrast(gapped, e)$panel$doi_queried == "p001"]))
expect_error(prepare_replication_contrast(p, e[-1, ]), "missing from the replication registry")
expect_error(prepare_replication_contrast(rbind(p, p[1, ]), e), "duplicate")
bad <- p; bad$sjr[1] <- NA
expect_error(prepare_replication_contrast(bad, e), "non-finite")
failed_only <- e; failed_only$outcome <- "failed"
expect_error(prepare_replication_contrast(p, failed_only), "No common cohorts")
one_cluster <- e
one_cluster$doi_r[one_cluster$outcome == "successful"] <- "one_success_project"
expect_error(prepare_replication_contrast(p, one_cluster), "independent clusters")
no_support <- prepare_replication_contrast(p, one_cluster, require_support = FALSE)
stopifnot(!any(no_support$support$included), length(no_support$weights) == 0)
expect_error(run_replication_contrast(no_support, nboots = 2), "No supported cohorts")

# Real fect fits on non-parallel untreated trajectories, with two staggered
# cohorts and a known 7-citation contrast. Every draw refits the latent factors.
result <- run_replication_contrast(a, nboots = 12, r = 1, seed = 91)
primary <- result$estimates[result$estimates$period == "primary", ]
stopifnot(result$inference_ok, all(is.finite(primary$se)),
  abs(primary$estimate[primary$estimand == "delta"] - 7) < 0.2,
  max(abs(result$draws$delta - (result$draws$successful - result$draws$failed))) < 1e-12,
  !"error" %in% names(result$placebo), max(abs(result$placebo$delta)) < 0.3)
v <- subset(result$draws, period == "primary")
stopifnot(abs(var(v$delta) - (var(v$successful) + var(v$failed) -
  2 * cov(v$successful, v$failed))) < 1e-12)
# Exercise factor selection used by the command-line default.
cv <- fit_replication_ife(a$panel, 0:1, a$min_pre, 91, cv = TRUE)
stopifnot(cv$r.cv %in% 0:1)
# A failed bootstrap must leave auditable failures and withhold every interval.
test_failed_bootstrap <- function() {
  original_fit <- fit_replication_ife
  on.exit(assign("fit_replication_ife", original_fit, envir = .GlobalEnv))
  calls <- 0L
  assign("fit_replication_ife", function(...) {
    calls <<- calls + 1L
    if (calls > 1L) stop("Deliberate bootstrap failure")
    fake$r.cv <- 1
    fake
  }, envir = .GlobalEnv)
  failed <- suppressWarnings(run_replication_contrast(a, nboots = 4, r = 1))
  stopifnot(!failed$inference_ok, all(is.na(failed$estimates$lower)),
    all(is.na(failed$estimates$se)), all(!is.na(failed$failures$error)))
}
test_failed_bootstrap()
cat("Replication contrast tests passed (including real IFE, CV, and joint bootstrap).\n")
