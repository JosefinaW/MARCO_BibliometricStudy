*Coefficients in this note use sampling variances taken by bootstrap column position. Current estimates, with variances by original identity, are in [moderator_analysis.md](moderator_analysis.md).*

Current specification: see [publication form, access, and metadata coverage](moderator_access_publication_correction_2026-09-08.md). This report documents the earlier duplicate/binary-coding correction; its additive OA/missing-OA model is superseded.

# Moderator correction, 8 September 2026

The corrected fit retains 591 original papers and years 2–6, with 2,690 unique original/year observations. The previous fit contained 3,305 rows because publication and repository locations expanded the replication-metadata joins. Non-missing analytical values agree within each original/year. We coalesce those values and combine descriptive host names, with an error on any conflicting analytical value. Upstream joins now enforce one row per DOI and a many-to-one relationship.

The raw replication metadata uses DOI URLs whereas the original-study metadata uses bare DOIs. The pipeline now normalises these identifiers before joining. Location records for unrelated DOI keys are excluded before checking scalar conflicts. No ambiguous analytical value in a used record is silently selected.

A second issue affects reruns: applying `as.integer()` to factor-valued logical labels turns FALSE/TRUE into 1/2. The saved model has this encoding for same-journal and open-access indicators. Explicit label decoding now gives 0/1 regardless of input class. Open-access missingness already has an indicator, so that recoding alone can be a reparameterisation of the known-status contrast. Same-journal missingness now also gets its own indicator instead of lying on the same numeric continuum as FALSE/TRUE.

The corrected refit retains the model’s original age and age-squared terms, field shares, publication indicators, REML fitting, sampling-variance weights, and original-paper random intercept. CR2 intervals clustered by original are supplied alongside model-based intervals to assess within-original dependence. This is an additional sensitivity analysis, not a reconstruction of the common first-stage bootstrap covariance. The old model and cached effects remain intact.

Cached effect estimates match the saved FECT effects exactly; every fitted corrected row is observed and treated. We reuse cached per-cell bootstrap variances. The saved main model does not contain bootstrap arrays, so a new joint first-stage uncertainty analysis would require a refit. The full Rmd also contains network/data-fetching and exploratory CART chunks; it has not been rendered end-to-end in this correction. The offline refit is reproducible with `Rscript R/refit_moderators.R`.

## Results

All six substantive visibility/link coefficients have 95% CR2 intervals including zero. This is uncertain evidence, not evidence of no association. Open access versus closed: +5.19 citations/year, 95% CI [−2.59, +12.96]. Shared author: −0.20 [−6.03, +5.63]. Same journal: −0.72 [−8.77, +7.32]. Preprint versus article: +3.61 [−12.66, +19.89]. Multi-study project versus article: −0.96 [−10.67, +8.76]. Journal impact per SNIP unit: −0.23 [−2.13, +1.68]. Positive values indicate a higher (less negative) fitted citation gap.

Unknown open-access status changes from +18.74 in the prior model to +13.13, with a model-based interval [1.29, 24.97] but CR2 interval [−3.50, 29.76]. It is a nuisance missingness category, not an identified repository-publication effect. Time coefficients must be interpreted jointly: the year-6 versus year-2 point contrast is −3.08 citations/year, CR2 SE 1.76.

## Validation

`Rscript tests/test_moderator_data.R` checks complementary missingness, rejects genuine scalar conflicts, confirms factor/logical/numeric binary invariance, checks DOI URL normalisation and actual upstream metadata collapse, and verifies the corrected sample. The refit additionally checks first-stage effect agreement, observed/treated cells, positive variances, unique keys, and field-share sums. Both scripts passed.

Statistical reference: [metafor documentation for cluster-adjusted inference](https://wviechtb.github.io/metafor/reference/robust.html).

## Independent review

Claude, invoked with `claude -p`, passed the initial correction and the final code review. Its final verdict was "Code: PASS", with no introduced regressions. Fable and agy (Gemini 3.8 Flash High) also passed the revised presentation after inspecting all 18 rendered slides. Reviews are saved under `presentations/dgps_replication_citations/reviews/`. The documented first-stage covariance limitation remains.
