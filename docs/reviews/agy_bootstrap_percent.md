An independent, read-only review of the percent reduction computation was conducted by examining [overall_percent_reduction.R](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/R/overall_percent_reduction.R), [overall_percent_reduction.json](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/docs/overall_percent_reduction.json), [overall_percent_reduction_intervals.csv](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/docs/overall_percent_reduction_intervals.csv), [overall_percent_reduction_bootstrap_draws.csv](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/docs/overall_percent_reduction_bootstrap_draws.csv), [overall_percent_reduction_2026-09-09.md](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/docs/overall_percent_reduction_2026-09-09.md), and the installed `fect` source extracts [/private/tmp/fect_fect_boot.R](file:///private/tmp/fect_fect_boot.R) and [/private/tmp/fect_getEffect.R](file:///private/tmp/fect_getEffect.R).

---

### 1. Code Correctness and Resampling Mapping

The code in [overall_percent_reduction.R](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/R/overall_percent_reduction.R) is **correct, defensive, and mathematically faithful** to the package implementation:
1. **Resampling alignment**: In `fect`, nonparametric bootstrap draws resample unit columns with replacement (`boot.id`). The column indices (including duplicates) are stored in `colnames.boot[[b]]` ([fect_fect_boot.R:L1141-1145](file:///private/tmp/fect_fect_boot.R#L1141-L1145)). In [overall_percent_reduction.R:L27-30](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/R/overall_percent_reduction.R#L27-L30), `ids <- f$colnames.boot[[b]]` preserves the duplicate columns in their exact resampled order, and explicit checks confirm `all(f$D.boot[, , b] == f$D.dat[, ids])` and `all(f$I.boot[, , b] == f$I.dat[, ids])`.
2. **Reconstruction fidelity**: The script verifies that the point raw ATT and all 500 bootstrap draws of raw ATT match the package output:
   - Point ATT match: $|-5.6171667 - (-5.6171667)| < 1\text{e-}8$.
   - Max bootstrap raw ATT error across all 500 draws: `max_bootstrap_att_reconstruction_error = 0` ([overall_percent_reduction.json:L45](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/docs/overall_percent_reduction.json#L45)).
   This proves that cell selection (`D == 1 & I == 1`), unit mapping, and effect extraction match `fect`'s internal engine with zero discrepancy.

---

### 2. Estimand: Ratio of Sums vs. Mean Paper Percentages

The estimand is:
$$\text{Reduction \%} = -100 \times \frac{\sum_{(i,t) \in \mathcal{S}} \hat{\tau}_{it}}{\sum_{(i,t) \in \mathcal{S}} \hat{Y}_{it}(0)} = 100 \times \left(1 - \frac{\sum_{(i,t) \in \mathcal{S}} Y_{it}}{\sum_{(i,t) \in \mathcal{S}} \hat{Y}_{it}(0)}\right)$$
where $\mathcal{S} = \{(i,t) : D_{it} = 1, I_{it} = 1\}$ across the 5,041 observed treated post-treatment cells.

- **Statistical necessity**: Computing an average of individual paper percentage changes ($\frac{1}{N} \sum_i \frac{\hat{\tau}_i}{\hat{Y}_{i0}}$) is statistically invalid here. Individual paper counterfactuals frequently approach zero, causing severe ratio explosion. Crucially, **407 treated cells have negative individual fitted counterfactual values** ($\hat{Y}_{it}(0) < 0$). In an individual percentage calculation, negative denominators invert signs (making a citation loss appear as a positive percentage gain) and would require arbitrary ad-hoc trimming or clipping.
- **Handling of negative cells**: The ratio-of-sums estimand aggregates across all cells without truncating or discarding the 407 negative fitted values. Because the aggregate counterfactual total across all papers is large and strictly positive ($\sum \hat{Y}_{it}(0) = 158,387.14$ at the point estimate), the negative individual values simply offset positive values naturally without inducing denominator pathologies.
- **Substantive relevance**: The ratio of sums answers the primary policy/meta-scientific question: *"Across the entire corpus of replicated studies, what percentage of total counterfactual citations was lost?"* It naturally weights papers proportional to their citation volume.

---

### 3. Denominator Uncertainty

- In naive analyses, researchers frequently divide the ATT confidence limits by a fixed point estimate of the counterfactual mean, ignoring denominator variance and the covariance between numerator and denominator.
- Here, denominator uncertainty is **fully propagated**: both numerator $\sum \hat{\tau}_{it}^*$ and denominator $\sum \hat{Y}_{it}^*(0)$ are recomputed jointly within every single bootstrap draw $b \in \{1, \dots, 500\}$.
- **Denominator stability**: Across the 500 bootstrap draws, the aggregate counterfactual denominator $\sum \hat{Y}_{it}^*(0)$ ranges from **71,320.84 to 241,618.78 citations** ([overall_percent_reduction.json:L37](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/docs/overall_percent_reduction.json#L37)). Because the minimum is far above zero ($> 71,000$), there is no division-by-zero or near-zero denominator singularity in the bootstrap distribution.

---

### 4. Confidence Interval Choice, Distribution Skew, and Sensitivities

Three 95% bootstrap intervals are generated:
- **Normal / Wald (SE = 19.26 percentage points)**: **$[-19.88\%, 55.64\%]$**
- **Percentile**: **$[-50.93\%, 27.19\%]$**
- **Basic (Empirical Pivot)**: **$[8.56\%, 86.69\%]$**

#### Key Insights on the Skewness and the Basic Interval
1. **Severe negative skew**: The bootstrap distribution of `reduction_pct` has a heavy left tail (draws extending down to $-50\%$ to $-91\%$, representing large citation increases in samples where high-volume papers have positive estimated effects). Conversely, the right tail is constrained (the 97.5th percentile is only $+27.19\%$).
2. **Artifactual exclusion of zero in the basic interval**: The basic interval formula reflects bootstrap deviations around $\hat{\theta}$: $[2\hat{\theta} - q_{0.975},\, 2\hat{\theta} - q_{0.025}]$. Because $q_{0.975}$ ($27.19\%$) is only 9.3 points above $\hat{\theta}$ ($17.88\%$), the lower bound becomes $17.88 - 9.31 = 8.56\%$. Because the left tail is so long ($q_{0.025} = -50.93\%$), the upper bound is pushed to $86.69\%$. **The exclusion of zero in the basic interval is a mathematical artifact of quantile reflection on a heavily skewed distribution, NOT evidence of statistical significance.**
3. **Primary reporting choice**: Using the **Normal / Wald interval** ($[-19.88\%, 55.64\%]$) as the headline is justified because it was pre-specified to maintain consistency with `fect`'s own raw ATT interval convention ([fect_fect_boot.R:L2611](file:///private/tmp/fect_fect_boot.R#L2611)). However, because the normal approximation imposes symmetry on a skewed distribution, it overstates the upper reduction bound ($55.6\%$ vs. percentile $27.2\%$) and understates the magnitude of the left tail ($-19.9\%$ vs. percentile $-50.9\%$).

---

### 5. Responsible Presentation Recommendations

You can responsibly present the headline as **18% reduction, 95% CI [−20%, 56%]**, provided the following reporting standards are maintained:
1. **Explicit method labeling**: Explicitly label the interval as the **Normal / Wald bootstrap-SE interval** (consistent with the model's reported raw ATT interval).
2. **Plain-language interval interpretation**: State clearly that the interval spans from a **20% citation increase to a 56% citation reduction**.
3. **Mandatory footnote / caveat on skewness and sensitivity**:
   - Report the **percentile interval [−51%, 27%]** alongside the headline to provide a transparent picture of the heavy left tail.
   - Clarify that neither the raw ATT ($p = 0.21$) nor the percentage reduction provides evidence of a statistically significant or reliable directional citation decline.
   - Note that the basic interval ($[9\%, 87\%]$) is an artifact of quantile reflection under skewness and must not be cherry-picked to claim statistical significance.
   - Acknowledge that with $B = 500$, tail quantiles have finite simulation precision, and unit-level resampling does not account for potential clustering across papers evaluated within the same replication project.

---

## Answer

### Verdict: **PASS**

1. **Code Correctness**: **Verified.** The script [overall_percent_reduction.R](file:///Users/lukaswallrich/Documents/Coding/Marco_BibliometricStudy/R/overall_percent_reduction.R) correctly handles unit column resampling, maintains duplicate column structures via `colnames.boot`, and reproduces all 500 package bootstrap draws of raw ATT with zero discrepancy (`max_bootstrap_att_reconstruction_error = 0`).
2. **Estimand**: **Sound.** The ratio of sums ($-100 \sum \text{eff} / \sum (Y - \text{eff})$) avoids individual paper denominator collapse, correctly incorporates the 407 negative counterfactual cells without arbitrary truncation, and accurately reflects aggregate citation volume.
3. **Denominator Uncertainty**: **Properly propagated.** Both numerator and counterfactual denominator vary jointly in each bootstrap replicate; the aggregate counterfactual total is strictly positive across all 500 draws (range: $71,321$ to $241,619$).
4. **Presentation**: You can responsibly report **"18% reduction, 95% CI [−20%, 56%]"** (or 17.9% [−19.9%, 55.6%]), provided that:
   - It is explicitly identified as the **normal/Wald bootstrap-SE interval** matching the saved FECT raw ATT specification.
   - The accompanying text or notes transparently caveat the distribution's negative skew and report the **percentile sensitivity interval [−51%, 27%]**.
   - No claim of directional statistical significance is made, recognizing that the basic interval's exclusion of zero is an artifact of quantile reflection on a skewed distribution.
