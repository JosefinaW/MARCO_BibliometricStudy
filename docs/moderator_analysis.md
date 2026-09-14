# Moderator analysis: current specification, sensitivities and reproduction

Entry point for the second-stage (moderator) analysis of the Scopus citation
outcome. The dated notes in this folder are the audit trail of how the
specification was reached; this file states what is current.

## Primary model

Multilevel meta-regression (`metafor::rma.mv`, REML) of the first-stage FECT
effect for each original paper and year, two to six years after the replication.
Weights are the inverse of the per-cell bootstrap sampling variance from the
first stage; a random intercept per original absorbs within-paper dependence.

| Quantity | Value |
|---|---|
| Originals | 591 |
| Original-by-year observations | 2,690 (one row per original and year) |
| Response | first-stage estimated yearly citation difference from the counterfactual, in citations per year |
| Covariates | years since replication and its square; field shares (no intercept); author overlap; same journal; journal SNIP with missing indicator; missing-journal indicator; multi-original replication (more than three originals per replication DOI) |
| Publication and access | four joint categories: journal article with publisher OA; journal article without publisher OA (reference); preprint or working paper; other online deposit; plus a nuisance group of 11 other publisher outputs |
| Access definition | Unpaywall status gold, hybrid or bronze counts as publisher OA; green (repository-only) and closed do not; five articles without cached status carry source-audited values |
| Intervals | CR2 cluster-robust by original with Satterthwaite degrees of freedom, reported next to model-based intervals |

Results (differences in citations per original per year; positive means a smaller citation loss):

| Contrast | Difference | 95% CR2 interval | p |
|---|---:|---:|---:|
| Publisher-OA article vs no publisher OA | −0.13 | [−4.64, 4.38] | .95 |
| Preprint or working paper vs no publisher OA | 4.95 | [−7.61, 17.51] | .42 |
| Online deposit vs no publisher OA | 6.40 | [−7.88, 20.67] | .36 |
| Shared author vs none | 0.25 | [−4.80, 5.30] | .92 |
| Same journal vs different | 0.58 | [−4.88, 6.04] | .83 |
| SNIP, per one-point increase | −0.46 | [−1.78, 0.87] | .49 |
| Multi-original replication | 3.33 | [−4.14, 10.81] | .37 |

The years-since-replication terms are read jointly: year 6 versus year 2 is
about +0.7 citations per year, CR2 SE 0.30. Between-original standard deviation
is about 22 citations per year. No contrast in the table above is
distinguishable from zero; the intervals are too wide to claim equivalence.
Full account, including the 22 source-audited records and the protocol
deviations: `moderator_publisher_access_audit_2026-09-08.md`.

## Deviations from the preregistration

Both are exploratory, made after inspecting the data, and are labelled as such
wherever the results appear.

- **Publisher access instead of any-copy access.** The preregistration specifies
  a binary Unpaywall open-access indicator. The primary model counts only
  publisher-hosted access; the any-copy models are kept as sensitivities.
- **Joint publication-and-access categories** replace the preregistered separate
  three-level publication strategy and binary access terms, because access
  coverage differs sharply by publication form (68 of 88 missing access values
  are preprints or repository records). The preregistered more-than-three-original
  threshold stays as a separate covariate.

## Sensitivity models

Each answers a narrower question. Outputs carry the suffix in the file names.

| Suffix | Question | Note |
|---|---|---|
| `corrected` | Preregistered additive terms after the row-selection and binary-coding fix | `moderator_correction_2026-09-08.md` |
| `publication_form` | Publication form without any access term | `moderator_access_publication_correction_2026-09-08.md` |
| `oa_within_journal` | Any-copy OA among the 355 ordinary journal articles with observed status | same note |
| `metadata_coverage` | Whether missing Unpaywall status (81 originals with a DOI) is associated with the effect | same note |
| `publication_access` | Joint categories with any-copy access | `moderator_combined_publication_access_2026-09-08.md` |
| `publisher_access` | **Primary model above** | `moderator_publisher_access_audit_2026-09-08.md` |

`R/refit_moderators_corrected.R` produces the `corrected` model.
`R/refit_moderators.R` produces the `publication_form`, `oa_within_journal` and
`metadata_coverage` models.

## Data corrections applied to the second stage

- **One row per original and year.** The join of first-stage effects to
  replication metadata expanded 2,690 original-by-year cells to 3,305 rows,
  because OpenAlex returns several location records per replication DOI and
  because replication DOIs were stored as URLs while original DOIs were bare.
  `R/moderator_data.R` normalises DOIs, collapses location records with an error
  on any conflicting analytical value, and enforces many-to-one joins.
- **Binary coding.** `as.integer()` on factor-valued TRUE/FALSE columns gave
  codes 1 and 2. `moderator_binary()` decodes labels explicitly; missing same-journal
  gets its own indicator.
- **Missing replication DOI** is a separate category, so the seven originals
  without one do not form an apparent multi-original replication.
- **Sampling variances by original identity.** `fect` stores each bootstrap
  draw's columns in resampled order: `eff.boot[, j, b]` belongs to the original
  column `colnames.boot[[b]][j]` of `eff`, and a unit drawn several times in one
  draw fills several columns with identical values. `bootstrap_cell_variance()`
  in `R/moderator_data.R` maps every draw's columns back through
  `colnames.boot` and takes the variance per original, counting each unit once
  per draw. Each original appears in 290 to 356 of the 500 draws, recorded in
  the `boot_draws` column of `data/eff_long_Scopus_citation.rds`.
  `R/rebuild_stage2_variances.R` regenerates the variances from a first-stage
  fit saved with `keep.sims = TRUE`.

## Aggregate percentage reduction (main effect, not a moderator)

`R/overall_percent_reduction.R` expresses the first-stage ATT as a percentage of
the fitted counterfactual citations: −100 × Σ(effect) / Σ(counterfactual) over
observed treated post-replication cells, recomputed in every bootstrap draw so
that numerator and denominator vary together.

| Quantity | Value |
|---|---|
| Point estimate | 17.9% fewer citations than the counterfactual |
| Normal (Wald) interval, chosen before inspection | [−19.9%, 55.6%] |
| Percentile interval | [−50.9%, 27.2%] |
| Basic interval | [8.6%, 86.7%] |

The bootstrap distribution is strongly skewed and the three intervals disagree;
all three are reported and none supports a directional claim. This is a ratio of
sums, so long-followed and highly cited papers weigh more. The script needs a
first-stage fit saved with `keep.sims = TRUE`; the 500-draw fit used
(461 MB, MD5 `c985c3ec5ed83e6dbb2139b327754432`) is not in the repository. Full
provenance: `overall_percent_reduction.json` and `overall_percent_reduction_2026-09-09.md`.

## Reproduction, in order, from the project root

```
Rscript R/rebuild_stage2_variances.R <path to fect fit with keep.sims = TRUE>
Rscript tests/test_moderator_data.R
Rscript tests/test_bootstrap_variance.R
Rscript R/refit_moderators_corrected.R
Rscript R/refit_moderators_publisher.R
Rscript R/refit_moderators_combined.R
Rscript R/refit_moderators.R
Rscript R/overall_percent_reduction.R <path to fect fit with keep.sims = TRUE>
```

Apart from the two scripts that take a first-stage fit with bootstrap draws, all
scripts read only cached files in `data/` and `models/`; no API calls. The tests
check DOI normalisation, the row collapse, binary decoding, group sizes,
design-matrix rank, and the mapping of bootstrap draws to originals. `_07_moderator_analysis.Rmd` uses the same helpers for
its primary section; its later exploratory sections keep their original coding
and are not used for reported results.

## Open items

- The committed first-stage fit `models/fit_citation_Scopus.rds` has no bootstrap
  draws (`_06_fect_analysis.Rmd` sets `keep.sims = FALSE`), so the per-cell
  variances in `data/eff_long_Scopus_citation.rds` cannot be regenerated from it.
  They were last regenerated from the 500-draw fit (461 MB, MD5
  `c985c3ec5ed83e6dbb2139b327754432`) held outside the repository; provenance is
  in `stage2_sampling_variance.json`.
- The Saffran replication has Crossref year 2017 (`10.31234/osf.io/qsyd2`) but
  cached year 2018; the treatment date needs checking in a first-stage rerun.
- 101 originals share 21 replication DOIs. CR2 intervals handle dependence within
  an original, not across originals that share a replication.
- Author seniority is missing for 527 of 591 originals and is not in any model.
- Access is documented availability at the time of retrieval or audit, not access
  at the replication's publication date.
