# Validation run using Gemini 3.1 Pro (gemini-3.1-pro-preview).
#
# Independent of the production pipeline (which stays on gpt-oss-120b via
# DeepInfra). Reads the same inputs, writes a parallel output CSV, and
# reports agreement vs. the manual codings.
#
# Requires: GEMINI_API_KEY in .Rprofile / environment.

suppressMessages({
  library(ellmer)
  library(jsonlite)
  library(here)
  library(dplyr)
  library(purrr)
  library(tibble)
  library(readr)
  library(stringi)
})

stopifnot(nzchar(Sys.getenv("GEMINI_API_KEY")))

GEMINI_MODEL <- "gemini-3.1-pro-preview"

# ---------------------------------------------------------------------------
# Helpers (duplicated from the qmd to keep this script standalone)
# ---------------------------------------------------------------------------

clean_json_text <- function(x) {
  x <- as.character(x)
  bytes <- c(0x91, 0x92, 0x93, 0x94, 0x96, 0x97, 0x85, 0xD5, 0xCA)
  repl <- c("'", "'", '"', '"', "-", "-", "...", "'", "")
  names(repl) <- vapply(
    bytes,
    function(b) rawToChar(as.raw(b), multiple = FALSE),
    character(1)
  )
  for (bad in names(repl)) {
    x <- gsub(bad, repl[[bad]], x, fixed = TRUE, useBytes = TRUE)
  }
  x <- stri_replace_all_regex(x, "[\\p{Cc}&&[^\\n\\t]]", "")
  iconv(x, from = "", to = "UTF-8", sub = "")
}

`%||%` <- function(x, y) {
  if (is.null(x)) return(y)
  if (is.character(x) && length(x) == 1 && is.na(x)) return(y)
  if (length(x) == 0) return(y)
  x
}

# ---------------------------------------------------------------------------
# Schemas & prompts (identical to the qmd)
# ---------------------------------------------------------------------------

cluster_schema <- fromJSON(
  here("field_classification", "schemas", "cluster_schema.json"),
  simplifyVector = FALSE
)
psychology_fields_schema <- fromJSON(
  here("field_classification", "schemas", "psychology_fields_schema.json"),
  simplifyVector = FALSE
)

cluster_schema_json <- toJSON(cluster_schema$clusters, pretty = TRUE, auto_unbox = TRUE)
psychology_fields_json <- toJSON(psychology_fields_schema$fields, pretty = TRUE, auto_unbox = TRUE)

cluster_prompt <- glue::glue('
You classify scientific articles into discipline clusters (Subject Areas).

Use ONLY the clusters defined in the JSON array below.
Classification should rely primarily on the journal title, as it typically indicates the disciplinary field.
Only when the journal is clearly multidisciplinary or interdisciplinary (e.g., Nature, Science, PLOS ONE, PNAS),
use the article title and abstract to determine the best-fitting cluster.
Never invent new clusters; always return one of the existing id values.

For multidisciplinary articles, assign one primary cluster that best fits the core contribution.
If the article genuinely spans two disciplines, also assign a secondary cluster.

Key distinctions:
- Psychology vs Sociology: Individual processes vs social structure/institutions
- Psychology vs Economics: Psychological theory vs economic framing (utility, incentives, markets)
- Education vs Teaching: Educational systems vs teaching methods in a discipline
- Media vs Political Science: Media/communication vs political processes/institutions
- Metascience: Only for science in general, not discipline-specific methods
- Methods papers: Belong to the discipline being studied

AVAILABLE CLUSTERS (JSON array):
{cluster_schema}

You will receive articles as JSON with: article_title, article_abstract, journal_title

Respond with a JSON object containing:
- "cluster_id": the id of the primary matching cluster (string)
- "confidence": your confidence from 0 to 1 (number)
- "secondary_cluster_id": the id of a secondary cluster if the article is multidisciplinary (string or null)
- "secondary_confidence": confidence for the secondary cluster, if applicable (number or null)
', cluster_schema = cluster_schema_json)

psychology_field_prompt <- glue::glue('
You classify psychology articles into a single primary psychology subfield (Subject Field).

Use ONLY the fields defined in the JSON array below.
Classification should rely primarily on the journal title where it indicates a specific subfield.
For general psychology journals, use the article title and abstract to determine the best-fitting subfield.
If interdisciplinary, pick the subfield that best fits the core psychological contribution.
Never invent new fields; always return one of the existing id values.

Key distinctions:
- Psychology (General): Last resort only when no single subfield clearly dominates
- Occupational Psychology: Requires BOTH work-specific constructs AND theoretical claims about work
  - Workplace as setting only -> classify by underlying theory (e.g., prejudice reduction -> Social)
  - Work-specific constructs (leadership, burnout, job satisfaction) -> Occupational
- Educational Psychology: Learning/motivation/assessment in educational settings only
- Methods: Primary contribution must be methodological (new measure, technique, or meta-analytic method)

AVAILABLE FIELDS (JSON array):
{psychology_fields_schema}

You will receive articles as JSON with: article_title, article_abstract, journal_title

For multidisciplinary articles that genuinely span two subfields (e.g. a judgment/decision-making paper with a strong social-identity component), assign one primary field that best fits the core contribution and also assign a secondary field. Otherwise leave the secondary fields null.

Respond with a JSON object containing:
- "field_id": the id of the primary matching field (string)
- "confidence": your confidence from 0 to 1 (number)
- "secondary_field_id": the id of a secondary field if the article genuinely spans two subfields (string or null)
- "secondary_confidence": confidence for the secondary field, if applicable (number or null)
', psychology_fields_schema = psychology_fields_json)

# ---------------------------------------------------------------------------
# Chat constructors (Gemini)
# ---------------------------------------------------------------------------

make_cluster_chat <- function() {
  chat_google_gemini(
    system_prompt = cluster_prompt,
    model = GEMINI_MODEL,
    api_args = list(generationConfig = list(temperature = 0)),
    echo = "none"
  )
}

make_psych_chat <- function() {
  chat_google_gemini(
    system_prompt = psychology_field_prompt,
    model = GEMINI_MODEL,
    api_args = list(generationConfig = list(temperature = 0)),
    echo = "none"
  )
}

# ---------------------------------------------------------------------------
# JSON parsing (Gemini returns plain text; strip markdown fences if any)
# ---------------------------------------------------------------------------

parse_json_content <- function(text, default = list()) {
  if (is.na(text) || !nzchar(text)) return(default)
  s <- trimws(text)
  s <- sub("^```(?:json)?", "", s, perl = TRUE)
  s <- sub("```$", "", s)
  s <- trimws(s)
  tryCatch(fromJSON(s, simplifyVector = TRUE), error = function(e) default)
}

extract_cluster_results <- function(chats) {
  map_dfr(chats, function(chat) {
    if (is.null(chat)) {
      return(tibble(
        cluster_id = NA_character_, confidence = NA_real_,
        secondary_cluster_id = NA_character_, secondary_confidence = NA_real_
      ))
    }
    turns <- chat$get_turns()
    content <- if (length(turns) >= 2) turns[[2]]@text else NA_character_
    parsed <- parse_json_content(
      content,
      list(cluster_id = NA_character_, confidence = NA_real_,
           secondary_cluster_id = NA_character_, secondary_confidence = NA_real_)
    )
    tibble(
      cluster_id = parsed$cluster_id %||% NA_character_,
      confidence = parsed$confidence %||% NA_real_,
      secondary_cluster_id = parsed$secondary_cluster_id %||% NA_character_,
      secondary_confidence = parsed$secondary_confidence %||% NA_real_
    )
  })
}

extract_field_results <- function(chats) {
  map_dfr(chats, function(chat) {
    if (is.null(chat)) {
      return(tibble(
        field_id = NA_character_, field_confidence = NA_real_,
        secondary_field_id = NA_character_, secondary_field_confidence = NA_real_
      ))
    }
    turns <- chat$get_turns()
    content <- if (length(turns) >= 2) turns[[2]]@text else NA_character_
    parsed <- parse_json_content(
      content,
      list(field_id = NA_character_, confidence = NA_real_,
           secondary_field_id = NA_character_, secondary_confidence = NA_real_)
    )
    tibble(
      field_id = parsed$field_id %||% NA_character_,
      field_confidence = parsed$confidence %||% NA_real_,
      secondary_field_id = parsed$secondary_field_id %||% NA_character_,
      secondary_field_confidence = parsed$secondary_confidence %||% NA_real_
    )
  })
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

articles <- read_csv(
  here("field_classification", "abstracts_for_coding.csv"),
  show_col_types = FALSE
)

article_prompts <- articles |>
  rowwise() |>
  mutate(
    prompt = toJSON(list(
      article_title = title %||% "",
      article_abstract = abstract %||% "",
      journal_title = source_display_name %||% ""
    ), auto_unbox = TRUE)
  ) |>
  ungroup() |>
  pull(prompt) |>
  as.character() |>
  clean_json_text() |>
  as.list()

cat(sprintf("Gemini cluster stage: %d articles (%s)...\n",
            length(article_prompts), GEMINI_MODEL))

cluster_chats <- parallel_chat(
  chat = make_cluster_chat(),
  prompts = article_prompts
)
cluster_df <- extract_cluster_results(cluster_chats)

results <- bind_cols(articles, cluster_df)

cat(sprintf("  cluster_id filled: %d / %d\n",
            sum(!is.na(results$cluster_id)), nrow(results)))

# Field stage: any article where psychology is the primary OR secondary cluster
is_psych <- (results$cluster_id == "psychology" & !is.na(results$cluster_id)) |
  (results$secondary_cluster_id == "psychology" & !is.na(results$secondary_cluster_id))
psych_idx <- which(is_psych)
cat(sprintf("\nGemini psychology field stage: %d articles (primary or secondary)...\n",
            length(psych_idx)))

# Initialise per-cluster columns so articles with psychology as secondary do
# not overwrite their primary cluster's (non-existent) field info.
results$psychology_field_id <- NA_character_
results$psychology_field_confidence <- NA_real_
results$psychology_secondary_field_id <- NA_character_
results$psychology_secondary_field_confidence <- NA_real_
# Unprefixed columns — populated only when psychology is the primary cluster
results$field_id <- NA_character_
results$field_confidence <- NA_real_
results$secondary_field_id <- NA_character_
results$secondary_field_confidence <- NA_real_

if (length(psych_idx) > 0) {
  field_prompts <- articles[psych_idx, ] |>
    rowwise() |>
    mutate(
      prompt = toJSON(list(
        article_title = title %||% "",
        article_abstract = abstract %||% "",
        journal_title = source_display_name %||% ""
      ), auto_unbox = TRUE)
    ) |>
    ungroup() |>
    pull(prompt) |>
    as.character() |>
    clean_json_text() |>
    as.list()

  field_chats <- parallel_chat(
    chat = make_psych_chat(),
    prompts = field_prompts
  )
  field_df <- extract_field_results(field_chats)

  results$psychology_field_id[psych_idx]                 <- field_df$field_id
  results$psychology_field_confidence[psych_idx]         <- field_df$field_confidence
  results$psychology_secondary_field_id[psych_idx]       <- field_df$secondary_field_id
  results$psychology_secondary_field_confidence[psych_idx] <- field_df$secondary_field_confidence

  # Unprefixed columns mirror only those where psychology is the primary
  primary_psych <- which(results$cluster_id == "psychology" &
                           !is.na(results$cluster_id))
  results$field_id[primary_psych]                  <- results$psychology_field_id[primary_psych]
  results$field_confidence[primary_psych]          <- results$psychology_field_confidence[primary_psych]
  results$secondary_field_id[primary_psych]        <- results$psychology_secondary_field_id[primary_psych]
  results$secondary_field_confidence[primary_psych] <- results$psychology_secondary_field_confidence[primary_psych]
}

out_path <- here("field_classification", "classified_articles_pilot_gemini.csv")
write_csv(results, out_path)
cat(sprintf("\nWrote %s\n", out_path))

# ---------------------------------------------------------------------------
# Agreement vs manual (and vs gpt-oss)
# ---------------------------------------------------------------------------

manual <- read_csv(
  here("field_classification", "manual_classification.csv"),
  show_col_types = FALSE
) |>
  rename(cluster_manual = cluster_id)

psych_manual <- read_csv(
  here("field_classification", "manual_psych_classification.csv"),
  show_col_types = FALSE
) |>
  rename(field_manual = field_id)

gpt_raw <- read_csv(
  here("field_classification", "classified_articles_pilot.csv"),
  show_col_types = FALSE
)
gpt <- gpt_raw |>
  select(doi,
         cluster_gpt = cluster_id,
         confidence_gpt = confidence,
         secondary_cluster_gpt = secondary_cluster_id,
         field_gpt = any_of("psychology_field_id"),
         field_gpt_fallback = field_id,
         secondary_field_gpt = any_of("psychology_secondary_field_id"))
# Fall back to unprefixed field_id if the run predates per-cluster columns.
if (!("field_gpt" %in% names(gpt))) gpt$field_gpt <- gpt$field_gpt_fallback
if (!("secondary_field_gpt" %in% names(gpt))) gpt$secondary_field_gpt <- NA_character_
gpt <- gpt |>
  mutate(field_gpt = coalesce(field_gpt, field_gpt_fallback)) |>
  select(-field_gpt_fallback)

# --- Cluster agreement ---
cluster_cmp <- results |>
  select(doi, cluster_gemini = cluster_id,
         secondary_cluster_gemini = secondary_cluster_id,
         confidence_gemini = confidence) |>
  inner_join(manual, by = "doi") |>
  mutate(
    agree = cluster_gemini == cluster_manual,
    agree_any = cluster_gemini == cluster_manual |
      (!is.na(secondary_cluster_gemini) &
         secondary_cluster_gemini == cluster_manual)
  )

n <- nrow(cluster_cmp)
cat("\n=== Cluster agreement: Gemini vs manual ===\n")
cat(sprintf("Primary agreement:    %d / %d  (%.1f%%)\n",
            sum(cluster_cmp$agree, na.rm = TRUE), n,
            100 * mean(cluster_cmp$agree, na.rm = TRUE)))
cat(sprintf("Primary or secondary: %d / %d  (%.1f%%)\n",
            sum(cluster_cmp$agree_any, na.rm = TRUE), n,
            100 * mean(cluster_cmp$agree_any, na.rm = TRUE)))

lvls <- union(cluster_cmp$cluster_manual, cluster_cmp$cluster_gemini)
tab <- table(
  factor(cluster_cmp$cluster_manual, levels = lvls),
  factor(cluster_cmp$cluster_gemini, levels = lvls)
)
po <- sum(diag(tab)) / sum(tab)
pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
cat(sprintf("Cohen's kappa: %.3f\n", (po - pe) / (1 - pe)))

# vs gpt-oss
cmp3 <- cluster_cmp |>
  left_join(gpt, by = "doi") |>
  mutate(
    gem_vs_manual = cluster_gemini == cluster_manual,
    gpt_vs_manual = cluster_gpt == cluster_manual,
    gem_vs_gpt    = cluster_gemini == cluster_gpt
  )
cat("\n=== Cluster: pairwise agreement ===\n")
cat(sprintf("Gemini vs manual:   %.1f%% (%d/%d)\n",
            100 * mean(cmp3$gem_vs_manual, na.rm = TRUE),
            sum(cmp3$gem_vs_manual, na.rm = TRUE), nrow(cmp3)))
cat(sprintf("gpt-oss vs manual:  %.1f%% (%d/%d)\n",
            100 * mean(cmp3$gpt_vs_manual, na.rm = TRUE),
            sum(cmp3$gpt_vs_manual, na.rm = TRUE),
            sum(!is.na(cmp3$gpt_vs_manual))))
cat(sprintf("Gemini vs gpt-oss:  %.1f%% (%d/%d)\n",
            100 * mean(cmp3$gem_vs_gpt, na.rm = TRUE),
            sum(cmp3$gem_vs_gpt, na.rm = TRUE),
            sum(!is.na(cmp3$gem_vs_gpt))))

cat("\n=== Cluster confusion (Gemini != manual) ===\n")
cluster_cmp |>
  filter(!agree) |>
  count(cluster_manual, cluster_gemini, name = "n") |>
  arrange(desc(n)) |>
  print(n = Inf)

# --- Psychology subfield agreement ---
# Use psychology_field_id so articles with psychology as SECONDARY cluster
# are also compared (the old field_id would miss them).
field_cmp <- results |>
  select(doi,
         field_gemini = psychology_field_id,
         secondary_field_gemini = psychology_secondary_field_id,
         field_confidence_gemini = psychology_field_confidence) |>
  inner_join(psych_manual, by = "doi") |>
  mutate(
    agree = field_gemini == field_manual,
    agree_any = field_gemini == field_manual |
      (!is.na(secondary_field_gemini) & secondary_field_gemini == field_manual)
  )

have_field <- field_cmp |> filter(!is.na(field_gemini))
cat("\n=== Psych subfield agreement: Gemini vs manual ===\n")
cat(sprintf("Shared set (both Gemini & manual assigned a psych subfield): %d\n",
            nrow(have_field)))
cat(sprintf("Primary agreement:    %d / %d  (%.1f%%)\n",
            sum(have_field$agree, na.rm = TRUE), nrow(have_field),
            100 * mean(have_field$agree, na.rm = TRUE)))
cat(sprintf("Primary or secondary: %d / %d  (%.1f%%)\n",
            sum(have_field$agree_any, na.rm = TRUE), nrow(have_field),
            100 * mean(have_field$agree_any, na.rm = TRUE)))

lvls <- union(have_field$field_manual, have_field$field_gemini)
if (length(lvls) > 0 && nrow(have_field) > 0) {
  tab <- table(
    factor(have_field$field_manual, levels = lvls),
    factor(have_field$field_gemini, levels = lvls)
  )
  po <- sum(diag(tab)) / sum(tab)
  pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
  cat(sprintf("Cohen's kappa (primary): %.3f\n", (po - pe) / (1 - pe)))
}

# Compare to gpt-oss on psych
field_cmp3 <- field_cmp |>
  left_join(gpt |> select(doi, field_gpt, secondary_field_gpt), by = "doi") |>
  mutate(
    gpt_agree_any = field_gpt == field_manual |
      (!is.na(secondary_field_gpt) & secondary_field_gpt == field_manual)
  )
cat("\n=== Psych subfield: pairwise agreement ===\n")
cat(sprintf("Gemini vs manual  (primary):        %.1f%% (%d/%d)\n",
            100 * mean(field_cmp3$field_gemini == field_cmp3$field_manual, na.rm = TRUE),
            sum(field_cmp3$field_gemini == field_cmp3$field_manual, na.rm = TRUE),
            sum(!is.na(field_cmp3$field_gemini) & !is.na(field_cmp3$field_manual))))
cat(sprintf("Gemini vs manual  (prim or sec):    %.1f%% (%d/%d)\n",
            100 * mean(field_cmp3$agree_any, na.rm = TRUE),
            sum(field_cmp3$agree_any, na.rm = TRUE),
            sum(!is.na(field_cmp3$field_gemini) & !is.na(field_cmp3$field_manual))))
cat(sprintf("gpt-oss vs manual (primary):        %.1f%% (%d/%d)\n",
            100 * mean(field_cmp3$field_gpt == field_cmp3$field_manual, na.rm = TRUE),
            sum(field_cmp3$field_gpt == field_cmp3$field_manual, na.rm = TRUE),
            sum(!is.na(field_cmp3$field_gpt) & !is.na(field_cmp3$field_manual))))
cat(sprintf("gpt-oss vs manual (prim or sec):    %.1f%% (%d/%d)\n",
            100 * mean(field_cmp3$gpt_agree_any, na.rm = TRUE),
            sum(field_cmp3$gpt_agree_any, na.rm = TRUE),
            sum(!is.na(field_cmp3$field_gpt) & !is.na(field_cmp3$field_manual))))
cat(sprintf("Gemini vs gpt-oss (primary):        %.1f%% (%d/%d)\n",
            100 * mean(field_cmp3$field_gemini == field_cmp3$field_gpt, na.rm = TRUE),
            sum(field_cmp3$field_gemini == field_cmp3$field_gpt, na.rm = TRUE),
            sum(!is.na(field_cmp3$field_gemini) & !is.na(field_cmp3$field_gpt))))

write_csv(
  cmp3,
  here("field_classification", "gemini_cluster_comparison.csv")
)
write_csv(
  field_cmp3,
  here("field_classification", "gemini_psych_comparison.csv")
)
cat("\nWrote comparison CSVs.\n")
