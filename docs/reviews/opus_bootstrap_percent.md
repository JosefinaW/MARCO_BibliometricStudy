Both reviews are complete and independent. Writing the verdict.

## Answer

**Verdict: PASS on the computation. PASS-WITH-REQUIRED-CHANGES on the slide.** Two blocking presentation items; no bugs in `R/overall_percent_reduction.R`.

My review and the agy (Gemini 3.8 Flash High) review were run separately and reached the same conclusion: the code is correct, the normal/Wald interval cannot stand alone on the slide.

### Verified — computation and code

I reproduced the point estimate **without loading the 461 MB file**, using the 6 MB companion fit in the repo (`models/fit_citation_Scopus.rds`): ATT.avg −5.617167, n = 5,041 treated post cells, observed 130,071, counterfactual 158,387.14, reduction 17.8778%. Exact match to the JSON. All three intervals recompute exactly from `overall_percent_reduction_bootstrap_draws.csv`.

- **Bootstrap mapping is right.** `fect_boot` fits replicate *b* on `Y.input[, boot.id]` and stores `boot.id` (original indices, duplicates kept) in `colnames.boot[[b]]`; `eff.boot`/`D.boot`/`I.boot` are in resampled column order. The script's `f$Y.dat[, ids]` matches. Failed replicates are dropped from all five objects together via `boot.rm`, so alignment survives. Reconstruction error over 500 draws is exactly 0.
- **Scale is right.** `norm.para` is NULL and `W` is NULL, so `Y.dat` is raw citation counts. Sums are integers, confirming it.
- **Estimand is right.** `-100·sum(eff)/sum(Y−eff)` = `100·(Σcf − Σobs)/Σcf`. Ratio of sums, correctly described in the notes as an aggregate, not a mean of paper percentages.
- **Event-time shift is right.** fect sets T.on = 1 at the first treated period (verified empirically: all 591 treated units), so `rownames − 1` maps correctly to "0 = replication year". Documented in `speaker_notes.md:46`.
- **Do not cross-check against the installed fect's `estimand("aptt")` or `"log.att"`.** Their bootstrap branches pair original-order `Y.dat` cells with resampled-order `eff.boot`. The script is correct where the package is not.

### Blocking — slide 6

**B1. The plotted interval is the one method the bootstrap does not support.** The normal upper limit is 55.6%; the maximum of all 500 draws is 31.8%. Zero draws fall between them. The bootstrap mass sits in the *left* tail (citation increases: skewness −2.77, kurtosis 12.2, 14.6% of draws below zero), and the symmetric Wald interval moves that width to the right. So it understates the increase side (−20% vs percentile −51%) and overstates the reduction side (+56% vs +27%) — skewed in the hypothesis-favouring direction. Drawing a whisker to "60% reduction" on a slide asserts a scenario no replicate produced.

**B2. Speaker note 4 misstates the negative counterfactuals.** "No negative cell-level fitted counterfactuals were truncated" reads as "there were none." There are **407 of 5,041 treated cells (8.1%)** with a negative fitted counterfactual, and 98–871 across draws. Rewrite as: *"407 of 5,041 treated cells (8%) have a negative fitted counterfactual; none were dropped or clamped. They sum to −1,100 citations, 0.7% of the 158,387 total, so they do not materially move the point estimate."* That last clause is the mitigation and it holds — I computed it. Without it the current wording is a false reassurance; with the numbers it is a fair one.

### The robust conclusion you can state

Every interval that respects the observed bootstrap shape — percentile [−50.9%, +27.2%], bias-corrected [−29.2%, +29.7%] (z₀ = 0.202) — **includes zero**, as does the normal one. Only the *basic* interval [+8.6%, +86.7%] excludes it, and basic is the least defensible here: it reflects a long left tail onto the right of a statistic bounded above at 100%, manufacturing significance the raw ATT does not have (p = .21). So the **direction is undetermined under every defensible method**; only the endpoints are method-sensitive. That is a cleaner and more honest sentence than the current "interval-method sensitivity precludes a firm conclusion."

### Can you responsibly show "18% reduction, 95% CI [−20%, 56%]"?

**In the JSON and speaker notes, yes** — labelled normal/Wald and pre-specified. The pre-commitment is real and should be honoured in the record.

**On the slide as the only interval, no.** Concrete fix, in order of preference:

1. **Plot the percentile interval [−51% increase, +27% reduction]** as the primary whisker; keep the normal one in the notes as the pre-specified method with one line explaining why it is not plotted. Note explicitly in your write-up that this change moves the reported range *away* from the favourable direction (reduction ceiling 56% → 27%), so it is the opposite of cherry-picking.
2. **Or plot both** — normal as a light bar, percentile as the dark one — footnoted "Both include no change; raw-count ATT p = .21."
3. Either way, demote the standalone giant "18%". Something like "No clear citation change · point estimate 18% reduction" carries what the data support. The bare "18%" is what an audience will remember.

If you change the plotted interval, `scale_x_continuous(limits = c(-30, 65))` in `build_charts.R:21` will **silently drop** the −51% whisker (ggplot removes out-of-range data with only a warning). Use `coord_cartesian(xlim = …)` instead, or widen to `c(-60, 40)` and relabel the breaks.

### Advisory

| Item | Where | Action |
|---|---|---|
| Two fits mixed with no guard | `build_charts.R:4` reads the 6 MB fit for the event-study and unit-effect charts; line 14 reads the JSON derived from the 461 MB run. They currently agree (ATT −5.617167 both) but nothing enforces it. | Add `stopifnot(abs(f$est.avg[1,'ATT.avg'] - pct$raw_att$ATT.avg) < 1e-8)` before building. |
| Audit contradicts itself | `evidence_audit.md:30` records that the −18% aggregate re-expression "has been omitted to avoid treating different quantities as equivalent"; the 9 September entry makes it the slide 6 headline. | Reconcile — a reader of the audit currently gets both stories. |
| Headline not reproducible from a clone | Source is `~/Downloads/fit_citation_Scopus.rds`, outside the repo. Disclosed with MD5 in note 5, which is good practice, but a clone cannot regenerate the number. | Flag only; archive the draws CSV as the reproducible artefact (it already is). |
| Missing scale assertion | `overall_percent_reduction.R:8` asserts `is.null(f$W)` but not `is.null(f$norm.para)`. NULL in this fit. | One-line addition if the script is reused. |
| Minor wording | Note 1: "100 × (counterfactual − observed) / counterfactual, summed over 5,041 … cells" could parse as a sum of per-cell ratios. The next sentence resolves it. | Optional: "…, computed on the summed totals across 5,041 cells". |

Everything else on the slide checks out: headline 18%, CI text, alt text (17.9% / 19.9% / 55.6%), n = 5,041, 130,071, 158,387, SE 19.26, percentile and basic bounds, raw ATT and p, and the MD5 are all accurate.
