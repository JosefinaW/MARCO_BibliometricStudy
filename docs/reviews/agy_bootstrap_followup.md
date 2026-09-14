This bounded, read-only follow-up review assesses whether the implemented updates resolve the two blockers (B1, B2) and advisories identified in [`opus_bootstrap_percent.md`](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/docs/reviews/opus_bootstrap_percent.md).

---

### Evaluation of Blocker 1: Slide 6 Interval Representation & Framing

* **Original Issue:** The previous slide presented solely the symmetric normal/Wald interval `[−19.88%, 55.64%]`, drawing an upper whisker into an unobserved tail (where zero bootstrap replicates occurred) under a dominant "18% reduction" headline. Additionally, `scale_x_continuous(limits = ...)` risked clipping the percentile lower whisker (−50.93%).
* **Verification of Changes:**
  1. **Headline & Framing:** In [`slide_content.json`](file:///Users/lukaswallrich/Documents/Coding/presentations/dgps_replication_citations/slide_content.json#L64-L65), the slide title was updated to `"The citation response remains uncertain"`. The point estimate was demoted from a standalone giant number to contextualized body text: `<p style="font-size:36px;margin:32px 0 10px">Point estimate: <strong>18% reduction</strong></p>`.
  2. **Dual-Interval Visualization:** In [`build_charts.R`](file:///Users/lukaswallrich/Documents/Coding/presentations/dgps_replication_citations/build_charts.R#L17-L29), both intervals are plotted:
     * **Percentile** `[−50.93%, 27.19%]` plotted prominently in dark blue (`#167a9b`).
     * **Normal** `[−19.88%, 55.64%]` plotted in muted grey (`#84919a`).
  3. **Axis & Whiskers:**
     * The x-axis breaks at `-50`, `0`, and `50` are explicitly labeled `"50% increase"`, `"No change"`, and `"50% reduction"`.
     * `coord_cartesian(xlim = c(-60, 65))` is used instead of scale clipping, ensuring that the −50.93% percentile lower limit and the +55.64% normal upper limit are fully visible with intact error bar caps.
  4. **Footnote & Notes:** The slide footnote reads `"95% bootstrap intervals. Both include an increase and a reduction."` Notes explicitly document the strong skew, state that both intervals cross zero, and present the basic interval `[8.56%, 86.69%]` strictly as a sensitivity check without directional claims.
  5. **Rendered Output:** Visual inspection of [`slide-06.png`](file:///private/tmp/dgps-bootstrap-opus-final/slide-06.png) confirms clean alignment, zero clipping or collision, legible typography, and faithful representation of the bootstrap uncertainty.
* **Status:** **RESOLVED.**

---

### Evaluation of Blocker 2: Speaker Note on Negative Fitted Counterfactuals

* **Original Issue:** Note 4 previously stated `"No negative cell-level fitted counterfactuals were truncated"`, which ambiguously suggested that no negative fitted counterfactual values existed, masking the 407 treated cells with negative values.
* **Verification of Changes:**
  1. In [`slide_content.json`](file:///Users/lukaswallrich/Documents/Coding/presentations/dgps_replication_citations/slide_content.json#L70), Note 4 now states:
     > *"407 of 5,041 treated cells (8.1%) have negative fitted counterfactuals; none were dropped or clamped. Every bootstrap draw has a positive aggregate counterfactual total."*
  2. The exact cell count and percentage are disclosed, the handling (no truncation/clamping) is transparently articulated, and the denominator validity across bootstrap draws is confirmed.
* **Status:** **RESOLVED.**

---

### Evaluation of Advisories

* **Fit Consistency Guard:** Line 15 in [`build_charts.R`](file:///Users/lukaswallrich/Documents/Coding/presentations/dgps_replication_citations/build_charts.R#L15) now enforces agreement between the 6 MB companion fit and the JSON output:
  ```R
  stopifnot(abs(f$est.avg[1, 'ATT.avg'] - pct$raw_att$ATT.avg) < 1e-8)
  ```
* **Audit Reconciliation:** Lines 29–30 and 89–91 in [`evidence_audit.md`](file:///Users/lukaswallrich/Documents/Coding/presentations/dgps_replication_citations/evidence_audit.md#L30) resolve the earlier contradiction: the median individual percentage ratios remain omitted, while the aggregate percentage reduction with bootstrap uncertainty is documented as an aggregate ratio of sums.
* **Scale Assertion:** Line 7 in [`overall_percent_reduction.R`](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/R/overall_percent_reduction.R#L7) now explicitly asserts `is.null(f$norm.para)` alongside `is.null(f$W)`.
* **Status:** **RESOLVED.**

---

## Answer

**Verdict: PASS.**

All issues raised in [`opus_bootstrap_percent.md`](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/docs/reviews/opus_bootstrap_percent.md) have been substantively and completely resolved:
1. **Blocker B1 is resolved:** Slide 6 demotes the standalone 18% claim, leads with an uncertain response title, plots both the empirical percentile and pre-specified normal intervals with clear increase/reduction axis labels, preserves both whiskers via `coord_cartesian(-60, 65)`, and accurately footnotes the overlap with zero.
2. **Blocker B2 is resolved:** Speaker Note 4 explicitly quantifies the 407/5,041 (8.1%) negative counterfactual cells, clarifies that none were dropped or clamped, and verifies positive aggregate denominators across all bootstrap replicates.
3. **Advisories are resolved:** The source fit guard in `build_charts.R`, the scale assertion in `overall_percent_reduction.R`, and the historical narrative reconciliation in `evidence_audit.md` are in place.

There are no remaining blocking issues.
