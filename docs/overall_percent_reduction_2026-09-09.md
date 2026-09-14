# Overall percentage reduction — 9 September 2026

Estimated aggregate citation reduction: **17.88%**. Normal/Wald 95% bootstrap interval: **−19.88% to 55.64% reduction** (a 19.88% increase to a 55.64% reduction).

This uses 130,071 observed versus 158,387.14 fitted counterfactual citations across 5,041 observed treated post-replication paper/year cells. It is a ratio of sums, not an average of individual percentage effects. Longer-followed and more highly cited papers contribute more to the aggregate. The raw-count ATT is −5.617 citations/year, with the supplied run's normal 95% interval [−14.431, 3.196].

`R/overall_percent_reduction.R` reads the user-supplied Downloads model without overwriting the repository model. It recomputes −100 × sum(eff) / sum(Y − eff) in each of 500 nonparametric whole-unit bootstrap samples. Original column identities and repeated sampled units come from `colnames.boot`; D/I alignment is checked for every cell. Every reconstructed bootstrap raw ATT exactly matches `att.avg.boot`. Numerator and denominator therefore vary together. No negative individual counterfactual predictions are dropped or truncated (407 at the point estimate); all 500 aggregate counterfactual totals are positive (71,321–241,619).

The normal interval uses the SD of percentage bootstrap draws (19.2646 percentage points) and the saved model's Wald convention. This convention was selected before inspecting the interval results. **The distribution is strongly skewed and interval-method sensitivity is substantial:** percentile [−50.93%, 27.19%]; basic [8.56%, 86.69%]. We retain all three, do not select the basic interval for its exclusion of zero, and do not claim a reliable directional effect. With 500 draws, tail-quantile intervals also have limited simulation precision. These intervals inherit the model's identification and resampling assumptions; they do not address confounding or dependence between papers sharing replication projects.

Source MD5: `c985c3ec5ed83e6dbb2139b327754432`. Full provenance and results: `overall_percent_reduction.json`; draws and intervals in adjacent CSVs. Percentage scaling is an interpretive addition to the preregistered raw-count outcome. The presentation's other FECT plots retain their previous saved bootstrap run; only the overall headline uses this new run.

Package bootstrap implementation checked against installed fect 2.4.5 and its [inference documentation](https://yiqingxu.org/packages/fect/07-inference.html). Independent review status is recorded in `docs/reviews/`; a failed authentication attempt is not a passing review.

Final presentation: show percentile and normal intervals together, with the title “The citation response remains uncertain”. Opus independently passed the computation, requested presentation corrections, and passed the follow-up; agy also passed the final follow-up. See `docs/reviews/opus_bootstrap_followup.md` and `agy_bootstrap_followup.md`.
