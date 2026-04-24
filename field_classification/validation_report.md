# LLM Field-Classification Pilot — Validation Report

**Date:** 2026-04-24
**Sample:** 250-DOI pilot from `data/abstracts_pilot.rds`
**LLM:** `openai/gpt-oss-120b` via DeepInfra, `temperature = 0`
**Pipeline:** `field_classification/article_classification_pipeline - integrated.qmd`
**Ground truth:** single coder (Lukas), blinded to LLM output, using
`manual_coding_app.html` (cluster stage) and `manual_coding_app_psych.html`
(psychology subfield stage).

## 1. Data

- 250 abstracts in the pilot; 249 reached the LLM output (1 dropped — see §4.3).
- 249 abstracts coded manually at cluster level → `manual_classification.csv`.
- All 201 manual-psychology abstracts coded at subfield level →
  `manual_psych_classification.csv`.

## 2. Cluster-level agreement

### Headline

| metric | value |
|---|---|
| Primary agreement | **231 / 249 = 92.8 %** |
| Primary *or* LLM secondary matches manual | 239 / 249 = 96.0 % |
| Cohen's κ | **0.79** (substantial) |
| Mean LLM confidence — agree | 0.966 |
| Mean LLM confidence — disagree | 0.894 |
| Disagreement rate at LLM conf ≥ 0.9 | 11 / 228 = 4.8 % |
| Disagreement rate at LLM conf < 0.9 | 7 / 21 = 33 % |

LLM self-reported confidence is a usable filter: dropping the 21 low-confidence
items removes ~40 % of errors while losing <10 % of data.

### Per-cluster (manual label)

| manual cluster | n | agree | % |
|---|---:|---:|---:|
| psychology | 201 | 193 | 96 |
| economics_business | 25 | 22 | 88 |
| philosophy | 10 | 6 | 60 |
| education | 4 | 3 | 75 |
| political_science | 3 | 2 | 67 |
| computer_science | 1 | 1 | 100 |
| general_comparative_literature_linguistics | 1 | 1 | 100 |
| media_communication_studies | 1 | 1 | 100 |
| public_administration | 1 | 0 | 0 |
| sociology_social_sciences | 1 | 1 | 100 |
| sport_sciences | 1 | 1 | 100 |

### Disagreement patterns (18 total)

| manual → LLM | n | interpretation |
|---|---:|---|
| philosophy → psychology | 4 | experimental-philosophy papers (*Cognition*, PNAS, *Mind & Language*, *Philosophical Psychology*) classified as psychology |
| psychology → economics_business | 4 | PNAS / *Science* studies framed in economic language (inequality, punishment, charitable giving) |
| economics_business → psychology | 3 | applied-psych framing of *AER* / management items pushed them to psychology |
| psychology → general_comp_lit_linguistics | 2 | L2/phonology papers in *Second Language Research*, *Language Learning* |
| education → linguistics (1), political_science → public_administration (1), psychology → biology (1), psychology → philosophy (1), public_administration → economics (1) | 5 | miscellaneous single cases |

Most errors sit on either (a) genuinely multi-disciplinary PNAS / *Science*
papers where the journal-first heuristic gives no signal, or (b) the
experimental-philosophy boundary. On single-discipline journals the LLM is
essentially error-free.

## 3. Psychology subfield agreement

LLM ran field-stage classification on the 200 items it sent to the psychology
cluster; 192 of those were also manual-psychology, giving a shared evaluation
set of 192.

### Headline (shared set, n = 192)

| metric | value |
|---|---|
| Field agreement | **152 / 192 = 79.2 %** |
| Cohen's κ | **0.66** (substantial) |
| Mean LLM field confidence — agree | 0.940 |
| Mean LLM field confidence — disagree | 0.870 |

Confidence still separates agreement from disagreement but less sharply than at
the cluster stage.

### 9 articles placed *outside* psychology by the LLM

For 9 manual-psychology articles the LLM assigned a non-psychology cluster,
so no subfield comparison is possible:

- social → economics_business (3)
- cognitive → general_comp_lit_linguistics (2)
- cognitive → psychology cluster, no subfield recorded (1)
- social → biology (1), social → philosophy (1)
- psychology_general → economics_business (1)

### Per manual subfield (shared set)

| manual subfield | n | agree | % |
|---|---:|---:|---:|
| cognitive_psychology | 95 | 77 | 81 |
| social_psychology | 72 | 64 | 89 |
| biological_neuropsychology | 6 | 4 | 67 |
| methods_evaluation_psychology | 6 | 2 | 33 |
| developmental_psychology | 4 | 0 | **0** |
| differential_personality_diagnostics | 4 | 4 | 100 |
| educational_psychology | 3 | 0 | **0** |
| clinical_psychology | 1 | 0 | 0 |
| occupational_organisational_business | 1 | 1 | 100 |

### Disagreement patterns (40 total)

| manual → LLM | n |
|---|---:|
| cognitive → social | 13 |
| social → cognitive | 4 |
| developmental → social | 3 |
| methods → cognitive | 3 |
| cognitive → biological | 2 |
| cognitive → developmental | 2 |
| 12 single-instance patterns | 13 |

- **Cognitive ↔ social confusion dominates** (17 of 40 errors). Many are
  PNAS / *Psychological Science* / *JPSP* papers on judgment, disclosure, or
  counterfactual reasoning where content straddles both subfields.
- **Methods is under-called** (33 % recall on n=6): papers introducing new
  measures/techniques were classified by the domain they illustrate instead.
- **Developmental (0/4) and Educational (0/3)** are zero-recall in the pilot.
  Small sample, but worth watching — the LLM seems to ignore "learning in
  children" or "classroom setting" cues when the underlying mechanism is
  cognitive/social.

## 4. Notes and caveats

### 4.1 Single rater
Ground truth is a single expert coder, not adjudicated inter-rater agreement.
Boundary cases (e.g. experimental philosophy vs. cognitive psychology) would
benefit from a second coder before we treat the reported rates as absolute.

### 4.2 Pilot sample
Many subfields have n ≤ 6 in this pilot. Subfield-level percentages outside
cognitive/social should be read as directional, not conclusive.

### 4.3 One row dropped in the LLM output
249 of 250 input abstracts are in the LLM output CSV. Cause: a single cluster-
stage API response failed JSON parsing, so `extract_cluster_results()` wrote
`cluster_id = NA` for that row. In `classify_cluster_fields()`, the line
`filter(cluster_id != current_cluster)` then silently excludes NA rows
(`NA != "psychology"` evaluates to `NA`, and `filter()` drops `NA`). Fix for
the next run: `filter(is.na(cluster_id) | cluster_id != current_cluster)`.

## 5. Recommendations

1. **Fix the NA-drop bug** in `classify_cluster_fields()` before the next run.
2. **Prompt tuning — psychology subfield stage:** add explicit guidance on
   (a) cognitive vs. social for judgment/decision-making content, (b) when
   methodological contribution should trump the substantive domain, and
   (c) developmental / educational as age- or setting-defined, not
   content-defined.
3. **Keep confidence as a filter:** the pilot supports a `confidence ≥ 0.9`
   rule at the cluster stage as a cheap way to concentrate manual review on
   ~10 % of items while catching ~40 % of errors.
4. **Multidisciplinary journals:** for PNAS / *Science* / PLOS ONE, consider
   a second pass that is explicitly instructed to ignore the journal cue and
   classify on content only — the current prompt already flags these but still
   leans on the journal name in practice.
5. **Scale validation:** re-run on a larger (e.g. 500–1000 DOI) sample with a
   second coder on the disagreement cases, to turn the subfield estimates
   from directional to defensible.

## Files

| purpose | path |
|---|---|
| LLM output | `classified_articles_pilot.csv` |
| Cluster-level manual codings | `manual_classification.csv` |
| Psychology-subfield manual codings | `manual_psych_classification.csv` |
| Cluster discrepancies | `manual_llm_discrepancies.csv` |
| Psychology subfield discrepancies | `manual_llm_psych_discrepancies.csv` |
| Cluster comparison script | `compare_manual_llm.R` |
| Subfield comparison script | `compare_psych_manual_llm.R` |
| Pipeline | `article_classification_pipeline - integrated.qmd` |
