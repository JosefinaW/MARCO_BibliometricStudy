Both blockers are addressed. Verdict below.

## Answer

**PASS.** Both blockers from `docs/reviews/opus_bootstrap_percent.md` are resolved; no remaining blocking issues.

**B1 (normal/Wald interval plotted alone) — resolved.** `build_charts.R` now plots both intervals from `pct$intervals`: percentile [−50.93, 27.19] in blue as the top/primary row, normal [−19.88, 55.64] in grey below. `scale_x_continuous(limits=…)` is gone; `coord_cartesian(xlim=c(-60,65))` clips the panel without dropping data, and the rendered slide shows both whiskers complete — the percentile left end at −51 and the normal right end at +56 are both inside the panel. Breaks are labelled "50% increase / No change / 50% reduction", so sign direction is explicit rather than inferred. The dashed zero line makes "both include no change" readable from the chart itself, and the footnote states it. Title is now "The citation response remains uncertain"; the 18% is demoted to a 36 px line prefixed "Point estimate:" rather than a standalone headline. Alt text matches all four plotted bounds.

**B2 (negative counterfactuals misstated) — resolved.** Note 4 now reads "407 of 5,041 treated cells (8.1%) have negative fitted counterfactuals; none were dropped or clamped. Every bootstrap draw has a positive aggregate counterfactual total." The false-reassurance reading ("there were none") is gone, the count is correct, and the per-draw positivity claim is enforced in code by `stopifnot(counterfactual > 0)` inside `aggregate_reduction`, which runs on every draw. The materiality mitigation differs from the wording I suggested (aggregate-total positivity instead of the −1,100 / 0.7% share), but it is verifiable, true, and does the same job. Note 4 also keeps the basic interval [8.56%, 86.69%] as a sensitivity result with an explicit statement that it is not used for a directional claim.

**Advisories — all closed except one that is stale-but-harmless.**
- Fit-agreement guard: `stopifnot(abs(f$est.avg[1,'ATT.avg'] - pct$raw_att$ATT.avg) < 1e-8)` added before the interval chart, so the 6 MB event-study fit and the JSON from the 461 MB run cannot silently diverge.
- Scale assertion: `is.null(f$norm.para)` added to the line-7 `stopifnot` alongside `is.null(f$W)`.
- Audit contradiction: `evidence_audit.md:30` now states that the omission applies to the −28% median-of-individual-ratios and that the aggregate percentage was restored on 9 September as an explicit ratio of summed totals. The two entries no longer tell different stories.
- Non-blocking leftover: `evidence_audit.md:84` still says "No firm directional conclusion is warranted given interval-method sensitivity." The sharper statement is that *every* defensible interval (percentile, BCa, normal) includes zero and only the least defensible one (basic) does not, so direction is undetermined regardless of method. This was advisory in the original review and remains so — the current sentence is not wrong, just weaker than the evidence.

**Not re-verified here** (per the read-only scope): the computation and its outputs, which passed in the original review and are unchanged.
