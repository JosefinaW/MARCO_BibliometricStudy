# Aggregate citation reduction relative to fitted counterfactual citations.
# Run from project root: Rscript R/overall_percent_reduction.R <path to fect fit with bootstrap draws>
# The fit must come from fect(..., se = TRUE, vartype = "bootstrap", keep.sims = TRUE),
# so that eff.boot, D.boot, I.boot and colnames.boot are present. The run recorded in
# docs/overall_percent_reduction.json used a 500-draw fit (461 MB, MD5
# c985c3ec5ed83e6dbb2139b327754432) that is too large for this repository.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !file.exists(args[1]))
  stop('Usage: Rscript R/overall_percent_reduction.R <fect fit .rds with keep.sims = TRUE>')
source <- args[1]
f <- readRDS(source)
stopifnot(!is.null(f$eff.boot), !is.null(f$colnames.boot))
stopifnot(identical(f$vartype, 'bootstrap'), is.null(f$W), is.null(f$norm.para))
B <- dim(f$eff.boot)[3]
stopifnot(B > 1L, length(f$colnames.boot) == B,
          identical(dim(f$eff.boot), dim(f$D.boot)),
          identical(dim(f$eff.boot), dim(f$I.boot)))
aggregate_reduction <- function(Y, eff, D, I) {
  use <- D == 1 & I == 1
  stopifnot(!anyNA(use), all(is.finite(Y[use])), all(is.finite(eff[use])))
  observed <- sum(Y[use])
  gap <- sum(eff[use])
  counterfactual <- observed - gap
  stopifnot(sum(use) > 0, counterfactual > 0)
  c(n = sum(use), observed = observed, counterfactual = counterfactual,
    att = gap / sum(use), reduction_pct = -100 * gap / counterfactual,
    negative_counterfactual_cells = sum((Y - eff)[use] < 0))
}
point <- aggregate_reduction(f$Y.dat, f$eff, f$D.dat, f$I.dat)
draws <- t(vapply(seq_len(B), function(b) {
  # fect's nonparametric bootstrap stores ORIGINAL column indices, including
  # duplicate sampled units, in colnames.boot. Never deduplicate these indices.
  ids <- f$colnames.boot[[b]]
  stopifnot(length(ids) == ncol(f$Y.dat), all(ids %in% seq_len(ncol(f$Y.dat))),
            all(f$D.boot[, , b] == f$D.dat[, ids]),
            all(f$I.boot[, , b] == f$I.dat[, ids]))
  aggregate_reduction(f$Y.dat[, ids], f$eff.boot[, , b],
                      f$D.boot[, , b], f$I.boot[, , b])
}, point))
# Strong alignment checks: reconstruct the package's point ATT and EVERY draw.
stopifnot(abs(point['att'] - f$est.avg[1, 'ATT.avg']) < 1e-8,
          max(abs(draws[, 'att'] - as.numeric(f$att.avg.boot))) < 1e-8)
theta <- unname(point['reduction_pct'])
se <- sd(draws[, 'reduction_pct'])
q <- unname(quantile(draws[, 'reduction_pct'], c(.025, .975), type = 7))
intervals <- data.frame(
  method = c('normal', 'percentile', 'basic'), estimate = theta,
  lower = c(theta - qnorm(.975) * se, q[1], 2 * theta - q[2]),
  upper = c(theta + qnorm(.975) * se, q[2], 2 * theta - q[1]))
dir.create('docs', showWarnings = FALSE)
write.csv(data.frame(draw = seq_len(B), draws),
          'docs/overall_percent_reduction_bootstrap_draws.csv', row.names = FALSE)
write.csv(intervals, 'docs/overall_percent_reduction_intervals.csv', row.names = FALSE)
result <- list(source = normalizePath(source), source_md5 = unname(tools::md5sum(source)),
  bootstrap_replicates = B, estimand = '-100 * sum(Y - Y0) / sum(Y0), observed treated post cells',
  point = as.list(point), bootstrap_se_percentage_points = se,
  intervals = intervals, primary_interval = 'normal',
  rationale = 'Normal/Wald bootstrap-SE interval, consistent with saved model; percentile and basic sensitivities also reported.',
  bootstrap_counterfactual_total_range = range(draws[, 'counterfactual']),
  raw_att = as.list(f$est.avg[1, ]),
  max_bootstrap_att_reconstruction_error = max(abs(draws[, 'att'] - as.numeric(f$att.avg.boot))))
jsonlite::write_json(result, 'docs/overall_percent_reduction.json', pretty = TRUE, auto_unbox = TRUE, digits = 12)
print(point)
print(intervals)
cat('Bootstrap counterfactual range:', result$bootstrap_counterfactual_total_range, '\n')
