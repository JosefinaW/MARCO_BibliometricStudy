# LLM Field-Classification Pilot — Validation Report

**Date:** 2026-04-24
**Sample:** 250-DOI pilot from `data/abstracts_pilot.rds`
**Production LLM:** `openai/gpt-oss-120b` via DeepInfra, `temperature = 0`
**Comparison LLM:** `gemini-3.1-pro-preview` via Google, `temperature = 0`
**Pipeline:** `field_classification/article_classification_pipeline - integrated.qmd`
(production); `field_classification/validate_gemini.R` (Gemini comparison)
**Ground truth:** single coder, blinded to LLM output, using
`manual_coding_app.html` (cluster stage) and `manual_coding_app_psych.html`
(psychology subfield stage).

## 0. Changes since the first report

This is the second iteration of the report. Compared to the v1 run:

- **Secondary-cluster membership now triggers field classification.** v1 only
  sent articles with `cluster_id == "psychology"` to the subfield stage, so
  articles with psychology as the *secondary* cluster were silently excluded.
  v2 runs the field classifier on every article where psychology is primary
  OR secondary.
- **Field prompt now returns a secondary field** (`secondary_field_id`,
  `secondary_confidence`) — symmetric with the cluster stage. A
  cognitive/social paper can now be tagged as both.
- **NA-drop bug fixed.** v1 lost one row because `filter(cluster_id !=
  current_cluster)` silently drops `NA`s. v2 has all 250 input rows in the
  LLM output.
- Output CSVs gained per-cluster columns (`psychology_field_id`,
  `psychology_secondary_field_id`, …) plus unprefixed back-compat columns
  populated for primary-cluster matches.

## 1. Data

- 250 pilot abstracts; all 250 reach the LLM output in v2 (v1: 249).
- 249 manual cluster codings (the missing DOI post-dates the manual-coding
  CSV and remains unadjudicated; a clear CS paper).
- 201 manual psychology-subfield codings.

## 2. Cluster-level agreement (gpt-oss, production)

### Headline

| metric | value |
|---|---|
| Primary agreement | **230 / 249 = 92.4 %** |
| Primary *or* LLM secondary matches manual | **239 / 249 = 96.0 %** |
| Cohen's κ (primary) | **0.78** (substantial) |
| Mean LLM confidence — agree | 0.966 |
| Mean LLM confidence — disagree | 0.895 |
| Disagreement rate at LLM conf ≥ 0.9 | 12 / 229 = 5.2 % |
| Disagreement rate at LLM conf < 0.9 | 7 / 20 = 35 % |

Confidence remains a useful filter: dropping the 20 low-confidence items
catches ~37 % of cluster errors while losing <10 % of data. Allowing a
secondary-cluster match recovers an additional 9 items (the 96.0 % line).

### Per-cluster (manual label)

| manual cluster | n | agree | % |
|---|---:|---:|---:|
| psychology | 201 | 192 | 95.5 |
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

### Disagreement patterns (19 total)

| manual → LLM | n |
|---|---:|
| philosophy → psychology | 4 |
| psychology → economics_business | 4 |
| economics_business → psychology | 3 |
| psychology → general_comp_lit_linguistics | 2 |
| education → linguistics (1), political_science → public_administration (1), psychology → biology (1), psychology → philosophy (1), psychology → political_science (1), public_administration → economics (1) | 6 |

Most errors sit on either (a) genuinely multi-disciplinary PNAS / *Science*
papers where the journal-first heuristic gives no signal, or (b) the
experimental-philosophy boundary. Single-discipline journals are essentially
error-free.

## 3. Psychology subfield agreement (gpt-oss, production)

The field classifier now runs on all 209 articles where psychology is primary
(199) OR secondary (10). Of the 201 manual-psychology articles, 197 also have
a psychology field assignment from the LLM — up from 192 in v1.

### Headline (shared set, n = 197)

| metric | value |
|---|---|
| Primary agreement | **158 / 197 = 80.2 %** |
| Primary *or* LLM secondary field matches manual | **178 / 197 = 90.4 %** |
| Cohen's κ (primary) | **0.67** (substantial) |
| Mean LLM field confidence — agree | 0.931 |
| Mean LLM field confidence — disagree | 0.875 |

The secondary-field slot recovers 20 items — proportionally the largest
improvement in this iteration. It picks up exactly the cognitive↔social
overlap that dominated v1 errors.

### Articles placed outside psychology by the LLM (n = 3)

Down from 9 in v1, because articles with psychology as *secondary* are no
longer lost.

- cognitive → general_comp_lit_linguistics (2; no psychology in either slot)
- social → biology (primary) / economics_business (secondary) (1)
- social → economics_business (primary) / sociology (secondary) (1)

### Per manual subfield (shared set)

| manual subfield | n | agree | % |
|---|---:|---:|---:|
| cognitive_psychology | 96 | 78 | 81 |
| social_psychology | 75 | 68 | 91 |
| biological_neuropsychology | 6 | 4 | 67 |
| methods_evaluation_psychology | 6 | 2 | 33 |
| developmental_psychology | 4 | 1 | 25 |
| differential_personality_diagnostics | 4 | 4 | 100 |
| educational_psychology | 3 | 0 | **0** |
| clinical_psychology | 1 | 0 | 0 |
| occupational_organisational_business | 1 | 1 | 100 |
| psychology_general | 1 | 0 | 0 |

### Disagreement patterns (39 total)

| manual → LLM | n |
|---|---:|
| cognitive → social | 12 |
| social → cognitive | 6 |
| methods → cognitive | 4 |
| developmental → social | 2 |
| cognitive → biological | 2 |
| cognitive → developmental | 2 |
| 11 single-instance patterns | 11 |

- **Cognitive ↔ social confusion still dominates** (18 of 39). But the
  secondary-field slot absorbs most of these — that's why the primary-or-
  secondary agreement is 10 pp higher than primary-only.
- **Methods under-called** (33 %): when a paper introduces a new measure or
  technique, the LLM picks the substantive domain the method is applied in.
- **Developmental (1/4) and Educational (0/3)** remain near zero-recall. Both
  are age- or setting-defined, and the LLM keeps classifying by content.

## 4. Gemini 3.1 Pro comparison

Same prompts / schemas / `temperature = 0`, run via
`field_classification/validate_gemini.R` and written to
`classified_articles_pilot_gemini.csv`.

### Cluster stage

| comparison | agreement | κ |
|---|---:|---:|
| gpt-oss vs manual (primary) | **92.4 %** (230 / 249) | **0.78** |
| gpt-oss vs manual (primary or secondary) | **96.0 %** (239 / 249) | — |
| Gemini vs manual (primary) | 90.4 % (225 / 249) | 0.70 |
| Gemini vs manual (primary or secondary) | 96.0 % (239 / 249) | — |
| Gemini vs gpt-oss | 94.4 % (235 / 249) | — |

Gemini routes more items to psychology than gpt-oss (absorbing some
philosophy / education / political_science items). It also hallucinated one
cluster id not in the schema ("philos"), which gpt-oss never did.

### Psychology subfield stage

Gemini's psychology cluster (primary OR secondary) contains 229 items;
199 overlap with manual-psychology.

| comparison | agreement | κ |
|---|---:|---:|
| gpt-oss vs manual (primary) | **80.2 %** (158 / 197) | **0.67** |
| gpt-oss vs manual (primary or secondary) | **90.4 %** (178 / 197) | — |
| Gemini vs manual (primary) | 77.4 % (154 / 199) | 0.63 |
| Gemini vs manual (primary or secondary) | **95.5 %** (190 / 199) | — |
| Gemini vs gpt-oss (primary) | 90.9 % (179 / 197) | — |

### Takeaway

- **Primary-only: gpt-oss wins at both stages** (+2 pp cluster, +2.8 pp
  subfield).
- **Primary-or-secondary: a tie at cluster, Gemini wins at subfield** (+5 pp).
  Gemini assigns secondary fields more liberally, which pays off when the
  downstream use tolerates dual tags.
- The two models agree with each other much more than either agrees with the
  human. Errors are systematic in the prompt/schema (cognitive↔social,
  philosophy↔psychology, economics↔psychology), not random model noise.
- Staying on `openai/gpt-oss-120b` is defensible for primary-only use; if the
  pipeline is going to consume both slots, Gemini may be worth a second look
  after the prompt-tuning in §6 is applied.

## 5. Notes and caveats

### 5.1 Single rater
Ground truth is a single expert coder, not adjudicated inter-rater agreement.
Boundary cases (e.g. experimental philosophy vs. cognitive psychology) would
benefit from a second coder before we treat the reported rates as absolute.

### 5.2 Pilot sample
Several subfields have n ≤ 6. Subfield-level percentages outside cognitive /
social should be read as directional, not conclusive.

### 5.3 Schema hallucination (Gemini)
Gemini returned `cluster_id = "philos"` once, a string not in the schema. The
prompt says "always return one of the existing id values" but does not enforce
it at the API level. If Gemini is ever used in production, a post-hoc
validity check against the schema (with a retry) is warranted.

## 6. Recommendations

1. **Prompt tuning — psychology subfield stage:** add explicit guidance on
   (a) cognitive vs. social for judgment/decision-making content, (b) when
   methodological contribution should trump the substantive domain, and
   (c) developmental / educational as age- or setting-defined, not
   content-defined.
2. **Keep confidence as a filter:** cluster-stage `confidence ≥ 0.9` catches
   ~37 % of errors while losing <10 % of data. Field-stage confidence is
   noisier.
3. **Multidisciplinary journals:** for PNAS / *Science* / PLOS ONE, consider
   a second pass explicitly told to ignore the journal cue and classify on
   content only.
4. **Use both primary and secondary slots.** The v2 numbers show they recover
   a substantial share of boundary errors — the downstream pipeline should
   consume both.
5. **Scale validation:** re-run on a larger (e.g. 500–1000 DOI) sample with a
   second coder on disagreement cases, to turn subfield estimates from
   directional to defensible.
6. **Schema validation on outputs**, especially if Gemini is used: reject /
   retry responses whose `cluster_id` or `field_id` are not in the schema.

## Files

| purpose | path |
|---|---|
| Production LLM output (gpt-oss) | `classified_articles_pilot.csv` |
| Gemini LLM output | `classified_articles_pilot_gemini.csv` |
| Cluster-level manual codings | `manual_classification.csv` |
| Psychology-subfield manual codings | `manual_psych_classification.csv` |
| Cluster discrepancies (gpt-oss vs manual) | `manual_llm_discrepancies.csv` |
| Psychology subfield discrepancies (gpt-oss vs manual) | `manual_llm_psych_discrepancies.csv` |
| Gemini cluster comparison | `gemini_cluster_comparison.csv` |
| Gemini subfield comparison | `gemini_psych_comparison.csv` |
| Cluster comparison script | `compare_manual_llm.R` |
| Subfield comparison script | `compare_psych_manual_llm.R` |
| Gemini validation script | `validate_gemini.R` |
| Pipeline | `article_classification_pipeline - integrated.qmd` |
