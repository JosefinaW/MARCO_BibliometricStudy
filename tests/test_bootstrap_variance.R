# Per-cell bootstrap variances must follow the original unit, not the column
# position within a draw. Run from the project root: Rscript tests/test_bootstrap_variance.R
source('R/moderator_data.R')
set.seed(20260914)

# Synthetic fect-like fit: T x N effects, B draws of N resampled columns.
Tn <- 3L; N <- 6L; B <- 300L
eff <- matrix(rnorm(Tn * N, 0, 10), Tn, N,
  dimnames = list(as.character(2011:2013), paste0('10.1/', seq_len(N))))
unit_sd <- c(0.5, 1, 2, 3, 4, 5)
cols <- lapply(seq_len(B), function(b) sample(N, N, replace = TRUE))
boot <- array(NA_real_, c(Tn, N, B))
# One draw-and-unit-specific noise vector per unit; repeated copies of a unit
# inside a draw carry identical values, exactly as fect's resampling produces.
noise <- lapply(seq_len(B), function(b)
  vapply(seq_len(N), function(i) rnorm(Tn, 0, unit_sd[i]), numeric(Tn)))
for (b in seq_len(B)) {
  ids <- cols[[b]]
  boot[, , b] <- eff[, ids, drop = FALSE] + noise[[b]][, ids, drop = FALSE]
}
fit <- list(eff = eff, eff.boot = boot, colnames.boot = cols)

out <- bootstrap_cell_variance(fit)
stopifnot(identical(dimnames(out$var), dimnames(eff)),
  identical(dimnames(out$se), dimnames(eff)),
  identical(dimnames(out$n_draws), dimnames(eff)),
  max(abs(out$se - sqrt(out$var))) < 1e-12)

# Draw counts: each unit is counted once per draw that contains it.
expected_n <- vapply(seq_len(N), function(i)
  sum(vapply(cols, function(s) i %in% s, logical(1))), integer(1))
stopifnot(identical(as.integer(out$n_draws[1, ]), expected_n),
  all(apply(out$n_draws, 2, function(x) length(unique(x)) == 1L)))

# Direct per-unit computation, deduplicating copies within each draw.
direct <- matrix(NA_real_, Tn, N)
for (i in seq_len(N)) {
  draws <- which(vapply(cols, function(s) i %in% s, logical(1)))
  m <- vapply(draws, function(b) boot[, which(cols[[b]] == i)[1], b], numeric(Tn))
  direct[, i] <- apply(m, 1, var)
}
stopifnot(max(abs(out$var - direct)) < 1e-8)

# The variances recover the generating unit SDs.
stopifnot(all(abs(sqrt(out$var) - rep(unit_sd, each = Tn)) / rep(unit_sd, each = Tn) < 0.25))

# Variance taken by column position mixes different originals and is larger.
position <- apply(boot, c(1, 2), var)
stopifnot(max(abs(position - out$var)) > 1, median(position / out$var) > 2)
cat('Synthetic bootstrap variance tests passed\n')

# Cached second-stage variances, as rebuilt by R/rebuild_stage2_variances.R.
e <- readRDS('data/eff_long_Scopus_citation.rds')
stopifnot('boot_draws' %in% names(e), is.integer(e$boot_draws),
  all(e$boot_draws >= 200L), all(e$boot_draws <= 500L),
  all(is.finite(e$sampling_var)), all(e$sampling_var > 0),
  max(abs(e$sampling_se - sqrt(e$sampling_var))) < 1e-12)
cat('Cached identity-based sampling variances verified\n')
