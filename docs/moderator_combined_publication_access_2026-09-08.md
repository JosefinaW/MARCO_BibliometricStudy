Superseded main model: see [publisher access and complete source audit](moderator_publisher_access_audit_2026-09-08.md). This any-copy model remains a sensitivity.

# Current moderator model: publication form with article access

We use the user's proposed joint categories: **OA journal article, closed journal article, preprint, and other online deposit**. Closed journal articles are the reference. We retain three additional nuisance categories for records that cannot safely enter those four groups. These are exploratory, post-inspection classifications and associations.

## Coding and sample

| Category | Originals | Operational definition |
|---|---:|---|
| OA journal article | 277 | Journal output; cached Unpaywall OA status is true |
| Closed journal article | 155 | Journal output; cached Unpaywall OA status is false |
| Preprint | 105 | Explicit cached OpenAlex type `preprint`; a repository DOI alone is insufficient |
| Other online deposit | 32 | Identified OSF/PsychArchives/Zenodo record without preprint type; DOI-bearing dissertation; or individually audited repository/data deposit |
| Article, access unknown | 4 | Verified journal article but no retrieved Unpaywall status |
| Other / unclassified output | 11 | Conference outputs, a book chapter, peer-review materials, and one unidentified DOI-bearing output |
| Replication DOI unavailable | 7 | No replication DOI; not interpreted as a multi-original replication or failed indexing |

Journal outputs include metadata types article, review, letter, or editorial with a journal ISSN. Five DOI-specific corrections address four journal articles with absent ISSN in the cache and one journal article incorrectly typed as a book chapter. These corrections identify publication form only; we do not replace missing cached OA with contemporary website accessibility. A repository location for a published journal article does not make its journal DOI a deposit. Conversely, a repository DOI is a deposit unless metadata explicitly identifies a preprint. This avoids the earlier blanket treatment of OSF records as preprints. “Online deposit” describes the registered output, not a guarantee that its contents are currently public or a claim that it was never published in another form.

The five journal corrections are supported by the [IREE publisher PDF](https://jcr-econ.org/wp-content/uploads/2022/06/2018-3-Roodman-D-Hookworm-Eradication.pdf), [authors' institutional record for Scandinavian Journal of Laboratory Animal Science](https://researchprofiles.ku.dk/da/publications/failure-to-replicate-exacerbated-8-oh-dpat-induced-hypothermia-co/), [AIS publisher record](https://aisel.aisnet.org/trr/vol6/iss1/1/), [NLM journal metadata](https://pubmed.ncbi.nlm.nih.gov/26604997/), and [Springer journal article](https://link.springer.com/article/10.1007/s41811-019-00044-8). Each correction and the five specifically classified deposits have a DOI, source URL, and rationale in `data/moderator_publication_overrides.csv`. All 591 original-level assignments are exported to `docs/moderator_publication_access_coding_audit.csv`.

The four access-unknown articles are genuine journal articles whose replication DOIs are 10.18718/81781.7, 10.23675/sjlas.v45i0.614, 10.17705/1atrr.00044, and 10.3205/zma000997. Their absence from retrieved Unpaywall metadata is not evidence of closed access or lack of scholarly indexing. The preprint group contains 55 observed OA, two observed closed, and 48 missing statuses; none is recoded based on form. Deposits contain four observed OA and 28 missing statuses.

## Model and interpretation

The model retains all 2,690 original/year observations from 591 originals, two to six years after replication publication. The outcome is the first-stage estimated annual citation difference relative to its counterfactual. Coefficients are differences in citations per original per year. REML multilevel meta-regression uses cached first-stage bootstrap sampling variances, a random intercept per original, age and age squared, all subject shares without an intercept, shared authors, same journal, journal SNIP, and the existing missing-SNIP and missing-journal indicators. First-stage point estimates and variances are unchanged.

Multi-original replication is a separate covariate, defined by more than three distinct originals per replication DOI in the full effect cache before selecting years two to six. Six such replication DOIs cover 69 originals in the analysis; all are OA journal articles. The covariate is estimable because the OA group also includes ordinary replication articles. It does not identify a multi-original association among closed articles. With no closed multi-original cases, the OA-versus-closed contrast relies on ordinary articles and on the additive specification; it should not be presented as evidence about a full access-by-scale interaction. Missing DOI is never grouped into a spurious shared replication.

The publication/access coefficients compare observed categories against closed journal articles, conditional on the listed controls. They are not independent effects of preprint publication and OA, and they are not causal effects of choosing publication form. OA means an OA copy detected by Unpaywall, including repository copies, rather than an OA-journal classification. The cache cannot establish access at the date of replication publication. [Unpaywall's definition](https://unpaywall.org/data-format).

Intervals use CR2 with original-DOI clusters and Satterthwaite degrees of freedom. This accounts for within-original dependence conditional on the cached first-stage quantities. It does not recover cross-original first-stage bootstrap covariance or dependence among originals sharing a replication DOI; full joint bootstrap draws are unavailable. Publication form and missing metadata also overlap with field and venue, so adjusted associations may still reflect selection. Full matrix rank is checked before fitting; algebraic estimability does not ensure strong overlap or causal identification.

## Missing metadata retained as a useful variable

The saved data retain `unpaywall_coverage`: status available (503 originals), status not retrieved despite a DOI (81), and DOI unavailable (seven). `unpaywall_status_not_retrieved` marks only the 81 DOI-present records. This is a retrieval-quality and metadata-coverage variable, not a verified indexing indicator: upstream code stored both request failures and absent records as missing and no HTTP-status log is available. Indeed, 63 of the 81 DOI-present cases with missing Unpaywall status have OpenAlex type metadata.

A separately labelled earlier coverage sensitivity adds the not-retrieved indicator to the publication-form model. Its estimate is 11.17 citations/year, 95% CR2 interval [−2.35, 24.69], p = .105, supported by within-form variation among preprint/repository and other outputs. It is not an indexing effect. The separate ordinary-journal OA sensitivity estimates 3.68 [−3.84, 11.21], p = .336, in 355 originals. Both are retained as sensitivity analyses; neither supplies the current main-slide coefficients.

## Reproduction

Run `Rscript tests/test_moderator_data.R`, then `Rscript R/refit_moderators_combined.R`. The current outputs use the `publication_access` suffix. Previous `publication_form`, `oa_within_journal`, `metadata_coverage`, and earlier `corrected` model/data files are preserved. The earlier three sensitivity models can be reproduced with `Rscript R/refit_moderators.R`. Main-slide estimates must come from `docs/moderator_coefficients_publication_access.csv`, including its `lower_CR2` and `upper_CR2` columns.

## Current estimates

| Contrast | Difference in citations/original/year | 95% CR2 interval | p |
|---|---:|---:|---:|
| OA article vs closed article | 5.39 | [−2.86, 13.64] | .200 |
| Preprint vs closed article | 4.28 | [−15.61, 24.18] | .639 |
| Other online deposit vs closed article | 5.20 | [−16.05, 26.44] | .597 |
| Shared author vs none | 0.44 | [−5.49, 6.37] | .882 |
| Same journal vs different | −0.02 | [−8.10, 8.06] | .996 |
| SNIP, per one-point increase | −0.96 | [−2.91, 0.99] | .332 |

The multi-original adjustment is 4.96 [−4.32, 14.23], p = .288. None of the displayed moderator associations is clearly distinguished from zero. This does not establish equivalent citation effects across categories: the preprint and deposit intervals remain wide, with Satterthwaite degrees of freedom of only 9.28 and 9.84. The OA contrast has approximately 243 degrees of freedom. All estimates, including nuisance and subject coefficients, remain in the CSV.

Brief speaker note: “We use joint categories because article access and publication form overlap. Preprints require an explicit metadata label; an OSF DOI alone is a deposit. Unknown access and unresolved forms stay in nuisance groups. These exploratory models cover years two to six, adjust for time, field, publication category, multi-original replication, and the other features, and use intervals clustered by original paper. They do not recover dependence across originals sharing a replication, and the wide intervals, especially for preprints and deposits, leave substantial uncertainty.”


## Recorded DOI form, not latest publication status

The displayed categories describe the **recorded replication DOI**. For example,
[PubData 10.48548/pubdata-2250](https://pubdata.leuphana.de/entities/publication/03f8abf4-42a2-42b9-b60b-99e0e387b0d1)
is explicitly a working paper, while
[Bamberg 10.20378/irb-49996](https://fis.uni-bamberg.de/bitstreams/25ede061-f037-4299-9a23-4b360cf79190/download)
is a repository DOI for a copy of a published Frontiers article with another DOI.
Both remain in the deposit category under the stated rule. We do not selectively
switch known examples to a work-level classification without auditing alternative
versions for all repository records. Therefore use **“Replication records: form
and access”** for the slide heading; do not label this an effect of publication
strategy or imply preprints/deposits were never subsequently published. A future
work-level analysis should resolve version relations and explicitly define the
publication state at replication time.
