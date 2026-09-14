# Per-cell sampling variances for the second stage, taken by original identity.
# Run from project root: Rscript R/rebuild_stage2_variances.R <path to fect fit with bootstrap draws>
# The fit must come from fect(..., se = TRUE, vartype = "bootstrap", keep.sims = TRUE),
# so that eff.boot and colnames.boot are present. The run recorded in
# docs/stage2_sampling_variance.json used a 500-draw fit (461 MB, MD5
# c985c3ec5ed83e6dbb2139b327754432) that is too large for this repository.
suppressPackageStartupMessages(library(dplyr))
source('R/moderator_data.R')
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !file.exists(args[1]))
  stop('Usage: Rscript R/rebuild_stage2_variances.R <fect fit .rds with keep.sims = TRUE>')
source_path <- args[1]
f <- unclass(readRDS(source_path))
stopifnot(identical(f$vartype, 'bootstrap'), !is.null(f$eff.boot), !is.null(f$colnames.boot))
B <- dim(f$eff.boot)[3]
cat('Draws:', B, '; cells:', nrow(f$eff), 'x', ncol(f$eff),
    '; NAs in eff.boot:', sum(is.na(f$eff.boot)), '\n')
cv <- bootstrap_cell_variance(f)

e <- readRDS('data/eff_long_Scopus_citation.rds')
idx <- cbind(match(e$time, rownames(f$eff)), match(e$doi_o, colnames(f$eff)))
stopifnot(!anyNA(idx), max(abs(e$att - f$eff[idx])) < 1e-10,
          all(f$D.dat[idx] == 1), all(f$I.dat[idx] == 1))
e$sampling_var <- cv$var[idx]
e$sampling_se <- cv$se[idx]
e$boot_draws <- as.integer(cv$n_draws[idx])
stopifnot(all(is.finite(e$sampling_var)), all(e$sampling_var > 0),
          all(is.finite(e$sampling_se)), all(e$boot_draws >= 2L))
saveRDS(e, 'data/eff_long_Scopus_citation.rds')

per_original <- e |> distinct(doi_o, boot_draws)
stopifnot(!anyDuplicated(per_original$doi_o))
result <- list(
  source = normalizePath(source_path), source_md5 = unname(tools::md5sum(source_path)),
  bootstrap_replicates = B,
  definition = 'var over draws of eff.boot[, j, b] with colnames.boot[[b]][j] == original column; one column per original per draw',
  draws_per_original_range = range(per_original$boot_draws),
  draws_per_original_median = median(per_original$boot_draws),
  originals = nrow(per_original), rows = nrow(e),
  distinct_cells = nrow(distinct(e, doi_o, time)),
  median_sampling_var = median(e$sampling_var))
jsonlite::write_json(result, 'docs/stage2_sampling_variance.json', pretty = TRUE,
                     auto_unbox = TRUE, digits = 12)
str(result)
