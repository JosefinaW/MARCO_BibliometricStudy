# Current moderator model: publisher access and replication records

We now distinguish **OA at the publisher**, including hybrid articles, from repository-only availability. We traced all 22 previously unresolved records to identifiable output types. The main model compares publisher-OA articles, articles without publisher OA, preprints/working papers, and other online deposits. Eleven genuine other publisher outputs remain a separate nuisance group; none is labelled unknown or forced into an unsuitable category.

## Access definition and protocol deviation

The [protocol](Replic_bibstudy_prereg.pdf), printed pp. 10–11, specifies whether the replication is open access or behind a paywall, measured using Unpaywall as a binary indicator. It does not name `is_oa`, specify publisher versus repository hosts, or prescribe an access observation date. The original any-copy coding was therefore a defensible operationalisation, but publisher-only access was not explicitly prescribed.

At the user's request, the current model narrows access to the publisher. Cached Unpaywall `oa_status` values **gold, hybrid, and bronze** count as publisher access; **green and closed** do not. Bronze means free-to-read at the publisher without an identified open licence and is included in this availability definition. Green denotes repository-only availability, so green articles are in the “without publisher OA” reference group even though a free repository copy exists. Use that reference label rather than implying those articles are inaccessible everywhere. [Unpaywall data format and OA-status definitions](https://unpaywall.org/data-format).

The protocol separately specified three publication-strategy categories: published, unpublished (e.g., preprint), and large meta-paper, with the latter defined by more than three originals. We replace the separate binary access and three-level strategy terms with joint publication/access categories to address their overlap. We retain the more-than-three-original threshold as a separate covariate, rather than using multi-original articles as an access category. **These are exploratory, post-inspection deviations**, justified by uneven access coverage across output types and the requested publisher-access estimand. Earlier any-copy and publication-form models are retained as sensitivity analyses. This correction does not establish that every other protocol element has been completed.

The cache does not establish access at replication publication. Five article records use openly available publisher sources audited on 8 September 2026 because cached status was absent; that provenance is explicitly recorded. We do not claim uniform publication-date access across the dataset. The archived status and source audit dates differ, so the variable describes documented publisher availability, not a historically harmonised exposure.

## What happened to the 22 records?

| Previously unresolved group | Source-audited result |
|---|---|
| Four journal articles with missing access | All four have publisher-hosted full text; source-audited publisher-OA overrides |
| Eleven other/unclassified DOI records | One honours thesis becomes an online deposit; ten are known publisher outputs (conference, book-chapter, or peer-review records) |
| Seven records with missing replication DOI | Two preprints/working papers, three deposits, one conference paper, and one publisher-OA journal article |

Thus the 22 comprise five publisher-OA articles, two preprints/working papers, four deposits, and eleven other publisher outputs. A separate consistency correction moves the already traced PubData working paper from deposit to preprint/working paper, applying the same explicit source-type rule as the Groningen working paper. There are 23 override rows in `data/moderator_publisher_trace_overrides.csv`: the 22 requested traces plus that consistency correction.

Every override is keyed by original DOI and records verified form, publisher-access override where applicable, source URL, rationale, and any recovered replication DOI. `docs/moderator_missing_doi_parent_audit.csv` provides the detailed seven missing-DOI traces. All original-level final classifications are exported to `docs/moderator_publisher_access_coding_audit.csv`.

Notable source resolutions include the [NC DOCKS honours thesis](https://libres.uncg.edu/IR/listing.aspx?id=35586), [UND undergraduate poster](https://commons.und.edu/es-showcase/18/), [Groningen working paper](https://research.rug.nl/en/publications/failure-to-replicate-increasing-generosity-by-eyes/), [AMCIS conference paper](https://aisel.aisnet.org/amcis2016/TRR/Presentations/5/), [Arizona bachelor's thesis](https://repository.arizona.edu/items/bb0bb3d7-335f-4cca-be56-ee423c97f4f6), and [Econ Journal Watch publisher PDF](https://econjwatch.org/file_download/538/FindlaySantosMay2012.pdf). The Pashler/Harris/Coburn online report was verified from the FLoRA-linked archived PDF saved at `docs/moderator_source_audit/pashler_psychfiledrawer_archived.pdf`.

The Saffran replication's exact title and 15 authors match [Crossref posted-content DOI 10.31234/osf.io/qsyd2](https://api.crossref.org/works/10.31234/osf.io/qsyd2). This recovered DOI is stored separately; the original cached DOI remains missing. Crossref gives 2017 whereas the cached replication year is 2018. We flag that discrepancy without silently changing the first-stage treatment date or yearly effect estimates. It needs resolution in a future full first-stage rerun. The later 2019 Collabra aggregate article is not substituted for this record.

The two eLife records are explicitly a decision letter and author response linked to parent articles; the [publisher's peer-review page](https://elifesciences.org/articles/40854/peer-reviews) and [publisher article PDF](https://cdn.elifesciences.org/articles/33105/elife-33105-v1.pdf) identify those relations. They remain ancillary publisher outputs under the recorded-reference classification. This is not a silent replacement of the recorded DOI with another version's DOI.

## Final categories

| Category | Originals |
|---|---:|
| Journal article: OA at publisher | 194 |
| Journal article: no publisher OA | 243 |
| Preprint / working paper | 108 |
| Other online deposit | 35 |
| Other publisher output (nuisance) | 11 |
| **Total** | **591** |

Journal articles include cached article, review, letter, or editorial types with journal ISSN, plus previously source-verified journal-form corrections and the newly traced no-DOI journal article. The preprint/working-paper group requires explicit metadata or source evidence. A repository namespace alone does not imply preprint. Other deposits include theses, posters, online reports, and repository records not specifically identified as preprints/working papers. The nuisance group comprises four conference papers, four conference abstracts (one DOI concerns two originals), one book chapter, and two peer-review documents.

These are **recorded replication-reference categories**, not a complete audit of later or alternative publication versions. For example, [PubData explicitly labels its record a working paper](https://pubdata.leuphana.de/entities/publication/03f8abf4-42a2-42b9-b60b-99e0e387b0d1), whereas a [Bamberg repository DOI stores a copy of a published Frontiers article](https://fis.uni-bamberg.de/bitstreams/25ede061-f037-4299-9a23-4b360cf79190/download) under another DOI. The latter remains a deposited record. Do not interpret the contrasts as effects of never versus eventually publishing a work.

## Model and results

We retain all 2,690 unique original/year observations from 591 originals, two to six years after the cached replication year. The response is the first-stage estimated annual citation difference from its counterfactual. Coefficients are differences in **citations per original per year**. First-stage effects, sampling variances, treatment years, and the cached raw DOI/access fields are unchanged.

REML multilevel meta-regression uses the cached first-stage bootstrap variances, a random intercept for original DOI, age and age squared, subject shares without an intercept, shared author, same journal, journal SNIP, and the existing missing-SNIP and missing-journal controls. More-than-three-original replication is a separate covariate, counted across the full cache before selecting years two to six; six replication DOIs cover 69 originals. Of these originals, 23 are in publisher-OA articles and 46 are in articles without publisher OA (the two Science records have green repository-only status). Thus multi-original status varies in both article access groups; the model assumes an additive scale association and does not estimate an access-by-scale interaction. The recovered DOI is used when counting distinct originals but does not change the threshold assignments in this sample. The scale covariate is concentrated: 40 of its 69 originals come from one Science replication, and all 46 multi-original originals in the reference group have green access status. Across the sample, 101 originals share 21 replication DOIs, reinforcing the caveat about dependence across originals.

| Contrast | Difference | 95% CR2 interval | p |
|---|---:|---:|---:|
| Publisher-OA article vs no publisher OA | −0.28 | [−6.22, 5.66] | .926 |
| Preprint/working paper vs no publisher OA | 5.99 | [−10.13, 22.12] | .443 |
| Online deposit vs no publisher OA | 5.42 | [−11.86, 22.70] | .521 |
| Shared author vs none | 1.02 | [−4.85, 6.88] | .731 |
| Same journal vs different | −0.59 | [−8.93, 7.76] | .890 |
| SNIP, per one-point increase | −0.85 | [−2.65, 0.95] | .352 |

The multi-original covariate is 6.55 [−3.39, 16.48], p = .192. No displayed moderator has a clearly distinguishable association from zero; the wide intervals do not establish equivalence. The publisher-access contrast has approximately 221 Satterthwaite degrees of freedom, the preprint contrast 16.8, and the deposit contrast 20.3.

Intervals use CR2 clustered by original DOI with Satterthwaite degrees of freedom. They address within-original dependence conditional on the cached first-stage estimates. They do not recover cross-original first-stage bootstrap covariance or dependence induced by several originals sharing a replication DOI; joint bootstrap draws are unavailable. Field/venue overlap and residual confounding remain possible. These are adjusted descriptive associations, not causal effects of choosing access or publication form. Full matrix rank is checked before fitting, but does not imply strong overlap.

## Metadata coverage and sensitivities

The useful coverage variable is retained unchanged: 503 originals have retrieved Unpaywall status, 81 have a recorded replication DOI but no status, and seven have no DOI in the original cache. Sixty-three of the 81 DOI-present missing-status cases nevertheless have OpenAlex type metadata. Missing access metadata therefore does not mean missing indexing generally. Because upstream errors and absent records were both saved as missing and HTTP logs are unavailable, we label this **metadata not retrieved**, not **not indexed**. Recovered identifiers and manually audited publisher access do not erase that original retrieval provenance.

Earlier model outputs are preserved. The ordinary-journal any-copy OA sensitivity was 3.68 [−3.84, 11.21] in 355 originals. The previous joint any-copy contrast was 5.39 [−2.86, 13.64]; its categories and audit coverage differ, so the numerical change to −0.28 cannot be attributed solely to the host restriction. The earlier metadata-coverage sensitivity was 11.17 [−2.35, 24.69], p = .105, for status not retrieved, within the strata supplying coverage variation. None is an indexing effect. The current main slides use only `publisher_access` coefficients.

## Reproduction and brief speaker note

Run `Rscript tests/test_moderator_data.R`, then `Rscript R/refit_moderators_publisher.R`. Current saved data, models, cross-tabs, and coefficients use `publisher_access`; source audit overrides are in `data/moderator_publisher_trace_overrides.csv`. Earlier `publication_access`, `publication_form`, `oa_within_journal`, `metadata_coverage`, and `corrected` outputs remain separate.

“OA here means available at the publisher, including hybrid and free-to-read bronze articles; repository-only copies do not qualify. We traced all 22 unclear records and kept eleven genuine conference, chapter, or peer-review outputs in a nuisance group. Joint categories and publisher-only access narrow the protocol after inspection, so these are exploratory analyses. We adjust for time, field, multi-original replication, and the other features, with intervals clustered by original paper. Cross-original dependence and historical access timing remain unresolved; wide intervals leave substantial uncertainty.”
