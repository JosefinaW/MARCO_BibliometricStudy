# Successful versus failed replications

This analysis estimates the difference between successful and failed
replications in their effects on annual citations, relative to a shared
no-recorded-replication counterfactual. It uses `fect(method = "ife")` with
paper and year effects, latent factors, and SJR. Article age squared is omitted,
consistent with the current first-stage specification.

## Run

From the repository root, with R packages `fect` (tested with 2.4.5), `dplyr`,
and `tidyr` installed:

```sh
Rscript R/prepare_replication_contrast_inputs.R
# Inspect data/replication_contrast/registry_coverage.csv and
# citation_collection_needed.csv before selecting the analysis sample.
Rscript R/run_replication_contrast.R \
  data/replication_contrast/panel.rds \
  data/replication_contrast/events.csv \
  results/replication_contrast 500
Rscript -e 'rmarkdown::render("_06b_replication_contrast.Rmd")'
```

The preparation script downloads `output/flora.csv` from
[FReD commit 9d77ad8](https://github.com/forrtproject/fred-data/tree/9d77ad8d801b4758cffe6a4d8ea7ce6902f39f45/output),
records checksums, and retains legacy replication records from
`metadata_OpenAlex.rds`. This reconciliation prevents papers with previously
known treatment dates from becoming untreated controls when a newer export
omits them. Conflicting first outcomes are excluded for review. Missing
original DOIs are saved separately. Outcome labels are the authors' judgements
recorded in FLoRA, not a significance criterion reconstructed from FReD effect sizes.

The optional first preparation argument supplies an expanded annual panel:

```sh
Rscript R/prepare_replication_contrast_inputs.R /path/to/expanded_panel.rds
```

An annual panel needs unique `doi_queried`/`year` rows, observed `n_citations`,
and either `sjr` or `issn_l` for the cached SJR join. The join uses observed
finite SJR values and forward fills within papers, as in the main workflow.
Missing SJR rows are audited and removed; conflicting SJR values stop the run.
Existing `D` values are checked against the registry before treatment is rebuilt.
The code never interprets absent citation records as zero. New papers need
complete, consistently retrieved citation histories from the same source as
the controls, including verified zero-citation years.

The checked-in citation panel was collected for failed replications and their
controls. A full FLoRA export alone does not supply the additional citation
histories or make this a representative success/failure sample. Use
`citation_collection_needed.csv` to extend the original-paper retrieval and
apply the same control-selection criteria to the successful papers. All
previously recorded replications, including mixed/unknown outcomes, must be
present in the registry to screen the donor pool. The runner stops when no
cohort has at least five usable papers and five independent replication
clusters in each outcome group. The preparation script still writes the full
support audit when no cohort qualifies.

## Treatment history and estimand

- Use the first recorded attempt, considering all available years before
  restricting cohorts to 2011–2021. A first reproduction is not an eligible
  replication. Mixed, unknown, or disagreeing same-year first outcomes exclude
  the original from the fit, including from controls. Any undated attempt also
  excludes the original because its treatment order is uncertain. Conflicting
  years for the same original/replication identifier exclude the original for
  reconciliation, rather than treating a date revision as another attempt.
- Same-year first attempts with matching outcomes form one annual exposure.
  Censor observations from the year of a subsequent recorded attempt, whatever
  its outcome. At annual resolution, same-year ordering cannot be recovered.
- Require at least five untreated observations per paper. Target papers must
  have every event year 0–6 observed before censoring. Other eligible papers
  can contribute to the counterfactual fit, but their post-replication outcomes
  remain masked even when they are outside the contrast sample.
- Retain cohorts with at least five target papers and five independent
  replication clusters in each outcome group. These are minimum support
  safeguards, not guarantees of reliable inference with few clusters. Weight
  each cohort by its share of pooled target papers across both groups, using
  the **same weights** for success and failure. The primary effect averages
  event years 2–6 equally. Positive delta means a more positive citation effect
  after successful replication. Results are in citations per paper-year.

For outcome type `r`, cohort `g`, and event year `k`, average the imputed
`Y - Y0` gaps within that cell. Then calculate
`delta(k) = sum_g w(g) * [ATT(success,g,k) - ATT(failed,g,k)]`.
The primary contrast is the mean of `delta(k)` over years 2–6. Balancing
follow-up changes the target population to papers observed without another
recorded attempt throughout that window. Common cohort weights do not balance
fields, original publication dates, or other differences between the groups.

## Model and uncertainty

Cross-validation selects 0–3 factors in the shared untreated outcome model.
Both successful and failed post-replication cells have `D = 1`, so neither
outcome group supplies treated observations to estimate the counterfactual.
IFE allows non-parallel trajectories explained by stable common latent
factors with paper-specific loadings; it does not allow arbitrary trend
violations or unmodelled shocks coinciding with replication publication.
See [Liu, Wang, and Xu](https://doi.org/10.1111/ajps.12723).

The code uses an explicit cluster bootstrap around `fect`, rather than
combining the package's marginal group confidence intervals. This makes the
custom cohort weighting and joint contrast transparent. Each draw resamples
whole clusters, gives duplicate draws new paper IDs, refits the IFE model,
and recomputes both group effects and delta. Connected components of shared
replication identifiers define clusters; unreplicated controls are paper
clusters. Missing replication identifiers are exposed in the audit; additional
dependence through shared projects/authors may require broader clusters.

The selected factor count and original target cohort weights are fixed during
bootstrapping. Intervals therefore condition on those choices and the selected
sample; they do not include factor-selection or registry-classification
uncertainty. The primary interval is normal/Wald using the bootstrap SD, with
percentile intervals also saved. Group covariance is retained because delta
is calculated inside each draw. Event-study intervals are pointwise.

Draws with missing group/cohort support or model errors are recorded, not
silently replaced. More than 5% failed draws withholds all intervals and
causes the CLI to exit unsuccessfully after saving diagnostics. A small
number of bootstrap draws is useful only for smoke testing. Two held-out
pretreatment years supply separate success, failure, and delta prediction
diagnostics; these have no inferential intervals.

The contrast describes differences in treatment effects between the observed
groups. A causal effect of changing a replication from failure to success
would require stronger identification assumptions about outcome assignment.

## Outputs and validation

Generated inputs and results have separate, gitignored directories. The runner
saves a reusable result RDS, group and delta estimates, common bootstrap draws,
failure messages, cohort counts/weights, exclusions, input checksums, and R
session information. The report reads these outputs without rerunning models.

### Current input coverage

The 14 September 2026 audit finds **no supported cohort for inference** under
the default paper and cluster thresholds. With complete event years 0–6,
2015 has 18 successful papers in one connected replication cluster and 56
failed papers in 15 clusters. In 2016, two successful papers represent two
clusters. No other cohort has a successful paper with the required follow-up.
The [cohort support table](replication_contrast_cohort_support.csv) records
all cohorts, including those with no common support.

Before the follow-up restriction, 24 eligible successful originals have
usable cached citation/SJR rows, and 525 eligible successful originals have
no such panel. The preparation script produces their collection list. The
current single success cluster in 2015 cannot support an independent-cluster
comparison, even though its paper count exceeds the minimum.

Audit inputs: FLoRA MD5 `211ddbc10b8075624d896e9549081742`, annual Scopus panel
MD5 `74709410d4a54f30497d807c726741d7`, and legacy metadata MD5
`ad6d91520b0a113bf5cc3a65116100b5`. The published FLoRA export has 37 records
without an original DOI; these cannot be linked to the citation panel and
are retained in a separate audit. This is a coverage assessment, not an
empirical treatment-effect result.

```sh
Rscript tests/test_replication_contrast.R
```

Tests cover treatment history, unknown/mixed outcomes, later attempts, duplicate
records, missing citation years, contaminated controls, shared clusters,
bootstrap multiplicity, matrix indexing, and cohort aggregation. An actual
IFE simulation with staggered timing and non-parallel untreated trajectories
checks recovery of a known success–failure contrast, joint covariance,
pretreatment prediction, and factor cross-validation.

The first-event rule and success/failure comparison extend the study design.
The preregistration, manuscript, and data-collection specification need to
state these rules and the resulting target population before substantive use.
