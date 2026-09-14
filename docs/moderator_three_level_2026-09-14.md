# Replication-level dependence in the moderator model, 14 September 2026

## Why a replication level

The second stage treats each original paper as the unit whose yearly effects are
correlated, with a random intercept per original and CR2 intervals clustered by
original. Originals that were tested in the same replication publication are
also dependent: they share the replication's authors, venue, publication date,
access status and reception. In the years 2–6 sample, 101 of the 591 originals
share 21 replication DOIs, and six replication publications test more than three
originals each (69 originals; the Reproducibility Project: Psychology alone
covers 40). Every replication-level moderator (publisher access, author
overlap, same journal, SNIP, publication form) takes one value for all
originals of a replication, so its effective sample size is the number of
replications, not the number of originals.

## Specification

`R/refit_moderators_publisher_threelevel.R` fits the primary publisher-access
model with random intercepts for the replication and for the original within
the replication (`random = ~1 | replication_id/doi_o`), and clusters the CR2
intervals by replication. `moderator_replication_id()` builds the cluster from
the recovered replication DOI where one exists, else the cached DOI; each of the
six originals whose replication has neither forms its own cluster. Fixed
effects, weights and sample are identical to the two-level model.

| Quantity | Two-level | Three-level |
|---|---:|---:|
| Clusters | 591 originals | 511 replications |
| Between-replication SD | – | 20.0 |
| Between-original SD | 21.8 | 10.3 (within replication) |

Four fifths of the between-paper variance sits at the replication level. The
two-level model attributes all of it to originals and treats the 40
Reproducibility Project originals as 40 independent observations of the same
replication's characteristics.

## Results

Differences in citations per original per year, positive = smaller citation
loss; CR2 intervals clustered by replication with Satterthwaite degrees of
freedom.

| Contrast | Three-level | Two-level |
|---|---:|---:|
| Publisher-OA article vs no publisher OA | −0.30 [−5.10, 4.50] | −0.38 [−4.90, 4.13] |
| Preprint or working paper vs no publisher OA | 3.57 [−9.70, 16.85] | 4.53 [−7.93, 16.99] |
| Online deposit vs no publisher OA | 3.06 [−11.25, 17.36] | 6.14 [−8.01, 20.30] |
| Shared author vs none | −2.76 [−7.74, 2.21] | −0.15 [−5.18, 4.89] |
| Same journal vs different | 3.00 [−2.17, 8.18] | 0.34 [−5.14, 5.82] |
| SNIP, per one-point increase | −2.27 [−4.70, 0.16] | −0.51 [−1.84, 0.82] |
| Publication gap, per year | −0.13 [−0.30, 0.04] | −0.16 [−0.36, 0.05] |
| Multi-original replication | 4.22 [−9.37, 17.81] | 3.00 [−4.40, 10.41] |

No contrast is distinguishable from zero in either model. Shared author and
SNIP move by more than their two-level standard error, same journal by about
one. All three are replication-level characteristics whose values are repeated
across the originals of the large projects, so the two-level model gave those
projects the weight of many independent observations. The multi-original
interval widens because its CR2 degrees of freedom fall to 6, the number of
replications with more than three originals.

## What this does and does not address

- It partitions the between-paper variance and clusters the intervals at the
  level where the moderators vary. It does not reconstruct the covariance of the
  first-stage effects across originals from the bootstrap; that would need the
  draws for every pair of originals and is left for a first-stage rerun with
  `keep.sims = TRUE`.
- Moderators such as author overlap mean different things for a replication
  that tests one original and for a project that tests forty. In the large
  projects an overlapping author is a consortium member. The model adjusts for
  the more-than-three-original indicator as preregistered and does not restrict
  the sample; whether the large projects should enter the moderator comparisons
  at all is a design question that the preregistration does not settle.
