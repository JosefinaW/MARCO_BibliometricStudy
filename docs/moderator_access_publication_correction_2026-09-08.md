*Coefficients in this note use sampling variances taken by bootstrap column position. Current estimates, with variances by original identity, are in [moderator_analysis.md](moderator_analysis.md).*

Current presentation model: [combined publication/access categories](moderator_combined_publication_access_2026-09-08.md). The models in this report are retained as sensitivities.

# Publication form and access: corrected moderator specification

We separate publication form from access. The primary analysis adjusts for publication form without OA, and an additional analysis compares observed access status within ordinary journal articles. Missing access metadata is not a substantive moderator. These choices were made after inspecting the data and are exploratory.

## What the metadata showed

Among the 591 originals in the years 2–6 sample:

| Previous publication label | OA | Closed | Missing OA |
|---|---:|---:|---:|
| published | 216 | 161 | 13 |
| preprint | 55 | 2 | 68 |
| meta | 69 | 0 | 7 |

The previous independent OA and publication coefficients therefore relied on extremely uneven support. The two closed preprints are OSF records (`10.31219/osf.io/pzy5q`, `10.31234/osf.io/bjmyx`); we retain their observed metadata rather than relabelling them. All seven missing-OA 'meta' cases have missing replication DOI. Grouping missing DOIs together had incorrectly treated them as a common replication of more than three originals.

The upstream Rmd queries Unpaywall by replication DOI. Failures explicitly receive missing `is_oa` and `oa_status`; a left join can also leave missing fields. The separate `oa_unpaywall.rds` cache is absent here, so the exact failure mechanism for each record cannot be reconstructed. However, 68 of 88 missing values occur in preprints/repository records, seven lack replication DOI, and the remaining 13 occur outside the documented journal-article group. Thus missingness strongly tracks metadata coverage; it is not an access regime. We do not assume missing means closed or all preprints are OA.

Unpaywall defines `is_oa` by whether it has identified an OA copy, including repository copies; it does not mean the journal itself is OA. Its status is mutable, and our cache does not identify status at replication publication. [Unpaywall data format](https://unpaywall.org/data-format), [data sources](https://www.unpaywall.org/sources).

## Publication form

The baseline is replication metadata type `article` with a nonmissing journal ISSN, covering at most three originals (355 originals). This is a metadata-supported classification, not a fresh verification of peer review. The categories are:

- **Preprints / identified repository records:** 125 originals. Metadata type `preprint`, or an explicitly matched OSF (`10.17605/osf.io/`), PsychArchives (`10.23668/psycharchives.`), or Zenodo (`10.5281/zenodo.`) namespace. This reproduces the 125 cached preprint cases but does not imply all are manuscripts, openly available, or unpublished elsewhere. A different version elsewhere is outside this DOI-level classification.
- **Multi-original journal articles:** 69 originals. Article metadata plus journal ISSN and the cached threshold of more than three originals per replication DOI. Every identified case has OA metadata. This is not a classification of meta-analysis methods.
- **Other / unclassified outputs:** 35 originals. Includes dissertations, conference materials, reviews, letters, repository deposits, and articles without a journal ISSN. Kept as a heterogeneous nuisance category rather than forcing 'published journal article'. The identified-repository group above is not an exhaustive inventory of repository records.
- **Unidentified replication DOI:** seven originals. Separate nuisance category; not a multi-original article or an OA category.

The primary estimand is the adjusted difference in the estimated citation effect associated with these observed publication forms, without holding OA constant. It can include correlated differences in availability. It is not a causal effect of choosing a form. We retain author overlap, same journal, journal SNIP, their existing missingness controls, age and age squared, and subject shares. Missing form and other-output coefficients are available for audit but are not central substantive results.

## Results

The full model uses 2,690 unique original/year observations from 591 originals, two to six years after replication publication. The response is the first-stage estimated annual citation difference relative to the counterfactual; coefficient units are citations per original per year. REML multilevel meta-regression uses cached bootstrap sampling variances and a random intercept per original. Intervals below use CR2 with original-DOI clusters and Satterthwaite degrees of freedom.

| Contrast | Difference | 95% CR2 interval |
|---|---:|---:|
| Preprint/repository vs ordinary journal article | −8.89 | [−29.71, 11.94] |
| Multi-original vs ordinary journal article | 6.32 | [−4.30, 16.95] |
| Shared author vs none | 1.03 | [−5.02, 7.09] |
| Same journal vs different | −0.89 | [−9.26, 7.48] |
| SNIP, per one-point increase | −0.92 | [−2.82, 0.98] |

The ordinary-journal OA analysis uses 1,632 original/year observations from 355 originals: 202 with OA copies detected and 153 coded closed. All ordinary journal articles have observed OA in this cache; hence there are no missing-OA cases to impute within this restricted group. We exclude the multi-original articles because none is closed. The adjusted OA-minus-closed difference is **3.68 [−3.84, 11.21]**, p = .336. This is a separate restricted-sample association, not the independent contribution of OA across all publication forms.

The revised results do not support a clear association for any of these moderators. They also do not establish equivalence: publication-form intervals, in particular, remain wide. In the earlier corrected additive model OA was 5.19; the restricted estimate is 3.68, but both the sample and estimand change. Shared-author, same-journal, and SNIP estimates also shift, with all intervals still including zero. Cached first-stage effects and variances are unchanged and checked against saved FECT point estimates and treatment/observation masks.

CR2 accounts for dependence within originals, conditional on the fitted first-stage quantities. It does not recover cross-original bootstrap covariance or dependence induced by originals sharing one replication; the full bootstrap draws are unavailable. Publication-form comparisons can have limited effective degrees of freedom (preprint/repository approximately 24), and residual confounding remains possible. A full inferential update would rerun the first stage with retained joint bootstrap draws and assess replication-level dependence.

## Reproduction and audit

Run `Rscript tests/test_moderator_data.R`, then `Rscript R/refit_moderators.R`. Both run without metadata APIs. New outputs use `publication_form` and `oa_within_journal` suffixes; prior corrected fit files are preserved. The refit script rejects rank-deficient design matrices before fitting and checks that every selected first-stage effect matches the saved FECT fit. Tests cover group sizes, missing-DOI correction, no missing-as-closed OA inclusion, factor decoding, upstream duplicate control, design rank, and a journal DOI prefix previously prone to false preprint classification.

The Rmd now uses the same primary formula helper and includes the restricted OA model. Its later historical exploratory sections retain their original specifications and are explicitly labelled as unsuitable for the presentation's revised moderator claims. Running the entire historical Rmd is not required to reproduce these models and was not attempted.

Speaker-note version: “We model years two to six using multilevel meta-regression, controlling for time, field, and the other displayed features. Publication form is analysed without OA because access coverage differs sharply by form. We compare OA separately within 355 journal-article cases with known status; missing OA is never treated as closed. Intervals cluster by original paper, with cross-original dependence still unresolved.”

## Additional user-requested metadata-coverage variable

We recode missing access status into **Unpaywall metadata coverage**, while separating unavailable DOI:

| Coverage | Originals | Meaning |
|---|---:|---|
| Status available | 503 | Cached `is_oa` is observed, whether open or closed |
| Status not retrieved despite DOI | 81 | Replication DOI exists, but cached `is_oa` is missing |
| DOI unavailable | 7 | No replication DOI for a DOI lookup |

This is not a verified indexing classification. The retrieval code stores both failed requests and absent records as missing, and the separate Unpaywall cache/HTTP logs are unavailable. Moreover, 63 of the 81 DOI-present cases with missing Unpaywall status have OpenAlex type metadata. Therefore missing Unpaywall status cannot be equated with absence from scholarly indexes. Of those 81 cases, 63 have OSF `10.17605` DOIs (these two counts of 63 refer to different subsets).

For an exploratory metadata-coverage model, we add `unpaywall_status_not_retrieved` to the publication-form model. It is one only for those 81 DOI-present records; the seven no-DOI originals remain in their separate form category. This is a comparison of unavailable versus available status within publication form, with a common adjusted association across the strata that provide variation. Preprint/repository records contribute 57 available versus 68 missing; other outputs contribute 22 versus 13. Both journal-article groups have complete status, so they provide no within-form coverage contrast. The model does not establish an effect of indexing or a coverage association among journal articles. OA remains in its separate within-journal analysis. The coverage model is a separately labelled exploratory sensitivity, not a replacement for that analysis.

The new indicator is useful both as a retrieval-quality flag for future metadata repair and as a descriptive moderator of the first-stage estimates. It should be labelled **“Unpaywall status not retrieved (DOI known)”**, never “not indexed” or “not OA”. Its association may reflect repository, field, or other selection differences despite adjustment. Retrieving HTTP status and registration-agency provenance in a future targeted metadata pass would distinguish genuine coverage gaps from request failures.

Coverage outputs use the `metadata_coverage` suffix; original-count cross-tabs are in `docs/moderator_metadata_coverage_crosstab.csv`. The three coverage states are retained on the saved model data as `unpaywall_coverage`, even in the primary and OA models that do not use this additional predictor.
