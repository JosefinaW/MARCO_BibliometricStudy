normalise_moderator_doi <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x <- sub("^https?://(dx\\.)?doi\\.org/", "", x)
  x <- sub("^doi:\\s*", "", x)
  x[x == ""] <- NA_character_
  x
}

# One scalar moderator record per key. Complementary missing values can be
# coalesced; conflicting observed values require an explicit upstream resolution.
collapse_moderator_rows <- function(data, keys, descriptive = 'host_organization_name') {
  value_cols <- setdiff(names(data), c(keys, descriptive))
  counts <- data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(value_cols),
      ~ dplyr::n_distinct(.x, na.rm = TRUE)), .groups = 'drop')
  bad <- value_cols[vapply(counts[value_cols], function(x) any(x > 1L), logical(1))]
  if (length(bad)) stop('Conflicting moderator values within key: ', paste(bad, collapse=', '))
  one <- function(x) {
    ok <- x[!is.na(x)]
    if (length(ok)) ok[1L] else x[NA_integer_][1L]
  }
  data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of(value_cols), one),
      dplyr::across(dplyr::any_of(descriptive),
        ~ if (all(is.na(.x))) NA_character_ else paste(sort(unique(na.omit(as.character(.x)))), collapse='; ')),
      .groups='drop')
}

# Decode labels before numeric conversion: as.integer(factor) gives level codes.
moderator_binary <- function(x) {
  y <- toupper(trimws(as.character(x)))
  bad <- !is.na(y) & !y %in% c('TRUE','FALSE','1','0')
  if (any(bad)) stop('Unexpected binary moderator value: ', paste(unique(y[bad]),collapse=', '))
  ifelse(is.na(y), NA_integer_, as.integer(y %in% c('TRUE','1')))
}

prepare_moderator_primary <- function(eff_long) {
  clean <- collapse_moderator_rows(eff_long, c('doi_o','time'))
  stopifnot(!anyDuplicated(clean[c('doi_o','time')]))
  primary <- clean |>
    dplyr::filter(time >= publication_year_r + 2, time <= publication_year_r + 6) |>
    dplyr::mutate(
      age_r = time - publication_year_r, age_r_sq = age_r^2,
      snip_missing = is.na(SNIP),
      SNIP_centered = dplyr::if_else(snip_missing, 0, SNIP - mean(SNIP, na.rm=TRUE)),
      same_journal_missing = as.integer(is.na(same_journal)),
      same_journal_f = dplyr::coalesce(moderator_binary(same_journal),0L),
      is_oa_missing = as.integer(is.na(is_oa)),
      is_oa_f = dplyr::coalesce(moderator_binary(is_oa),0L),
      has_overlap_f = moderator_binary(has_overlap),
      pub_preprint = as.integer(publication_strategy == 'preprint'),
      pub_meta = as.integer(publication_strategy == 'meta'),
      snip_missing_f = as.integer(snip_missing)
    )
  stopifnot(all(is.finite(primary$sampling_var)),all(primary$sampling_var>0),
    all(primary$age_r %in% 2:6),!anyDuplicated(primary[c('doi_o','time')]))
  primary
}

# Publication form and access answer different questions. Never infer access
# from form or treat failed/missing OA metadata as a closed-access observation.
prepare_moderator_publication_form <- function(eff_long) {
  d <- prepare_moderator_primary(eff_long)
  doi <- normalise_moderator_doi(d$doi_r)
  type <- as.character(d$type_r)
  # These three repository namespaces explain every non-preprint-typed record
  # in the cached preprint group. Avoid the former unescaped, unanchored regex
  # and the blanket 10.1590 prefix (also used by journal articles).
  repository <- !is.na(doi) & grepl('^(10\\.17605/osf\\.io/|10\\.23668/psycharchives\\.|10\\.5281/zenodo\\.)', doi)
  preprint <- type %in% 'preprint' | repository
  journal <- type %in% 'article' & !is.na(d$issn_l_r) & nzchar(as.character(d$issn_l_r))
  form <- dplyr::case_when(
    is.na(doi) ~ 'unidentified',
    preprint ~ 'preprint_repository',
    journal & d$publication_strategy == 'meta' ~ 'multi_original_article',
    journal ~ 'journal_article',
    TRUE ~ 'other_output'
  )
  d$publication_form <- form
  for (level in c('preprint_repository','multi_original_article','other_output','unidentified'))
    d[[paste0('form_',level)]] <- as.integer(form == level)
  d$oa_journal_eligible <- form == 'journal_article' & !is.na(moderator_binary(d$is_oa))
  # This records observed metadata coverage, not verified database indexing.
  # Upstream NA conflates no-record responses, failed requests, and no lookup.
  d$unpaywall_coverage <- dplyr::case_when(
    is.na(doi) ~ 'doi_unavailable',
    is.na(moderator_binary(d$is_oa)) ~ 'status_not_retrieved',
    TRUE ~ 'status_available')
  d$unpaywall_status_not_retrieved <- as.integer(
    d$unpaywall_coverage == 'status_not_retrieved')
  d
}

moderator_publication_formula <- function(data, oa_journal = FALSE, metadata_coverage = FALSE) {
  subject <- grep('^subj_', names(data), value = TRUE)
  # The restricted sample can lose whole fields. Remove only all-zero fields;
  # retaining a full-rank model is checked before fitting.
  subject <- subject[vapply(data[subject], function(x) any(x != 0), logical(1))]
  form <- if (oa_journal) 'is_oa_f' else paste0('form_',
    c('preprint_repository','multi_original_article','other_output','unidentified'))
  controls <- c('age_r','age_r_sq','has_overlap_f','SNIP_centered',
    'snip_missing_f','same_journal_f','same_journal_missing')
  controls <- controls[vapply(data[controls], function(x) length(unique(x)) > 1L, logical(1))]
  if (metadata_coverage && oa_journal)
    stop('Metadata coverage cannot be estimated in the observed-OA restricted sample')
  coverage <- if (metadata_coverage) 'unpaywall_status_not_retrieved' else character()
  stats::reformulate(c(controls,form,coverage,subject),intercept=FALSE)
}

# User-facing joint classification: article access is nested within journal
# outputs; preprint metadata is distinguished from a repository DOI alone.
prepare_moderator_combined <- function(eff_long,
    overrides = utils::read.csv('data/moderator_publication_overrides.csv')) {
  d <- prepare_moderator_publication_form(eff_long)
  doi <- normalise_moderator_doi(d$doi_r)
  override_doi <- normalise_moderator_doi(overrides$doi)
  stopifnot(!anyNA(override_doi),!anyDuplicated(override_doi),
    all(overrides$form %in% c('journal_article','online_deposit')))
  override <- overrides$form[match(doi,override_doi)]
  type <- as.character(d$type_r)
  journal <- type %in% c('article','review','letter','editorial') &
    !is.na(d$issn_l_r) & nzchar(as.character(d$issn_l_r))
  journal <- journal | override %in% 'journal_article'
  repository <- !is.na(doi) & grepl(
    '^(10\\.17605/osf\\.io/|10\\.23668/psycharchives\\.|10\\.5281/zenodo\\.)',doi)
  deposit <- repository | type %in% 'dissertation' | override %in% 'online_deposit'
  access <- moderator_binary(d$is_oa)
  group <- dplyr::case_when(
    is.na(doi) ~ 'doi_unavailable',
    type %in% 'preprint' ~ 'preprint',
    deposit ~ 'online_deposit',
    journal & access %in% 1L ~ 'article_oa',
    journal & access %in% 0L ~ 'article_closed',
    journal ~ 'article_access_unknown',
    TRUE ~ 'other_unclassified')
  d$publication_access_group <- group
  for (level in c('article_oa','preprint','online_deposit',
                  'article_access_unknown','other_unclassified','doi_unavailable'))
    d[[paste0('group_',level)]] <- as.integer(group==level)
  # Count originals in the full cache, before selecting the years2-6 sample.
  links <- data.frame(doi_o=eff_long$doi_o,
    doi_r=normalise_moderator_doi(eff_long$doi_r)) |>
    dplyr::filter(!is.na(doi_r)) |>
    dplyr::distinct(doi_o,doi_r) |>
    dplyr::count(doi_r,name='n_originals')
  d$n_originals_for_replication <- links$n_originals[match(doi,links$doi_r)]
  d$multi_original_f <- as.integer(!is.na(d$n_originals_for_replication) &
    d$n_originals_for_replication>3L)
  d
}

moderator_combined_formula <- function(data) {
  subject <- grep('^subj_',names(data),value=TRUE)
  subject <- subject[vapply(data[subject],function(x) any(x!=0),logical(1))]
  stats::reformulate(c('age_r','age_r_sq','has_overlap_f','SNIP_centered',
    'snip_missing_f','same_journal_f','same_journal_missing','multi_original_f',
    paste0('group_',c('article_oa','preprint','online_deposit',
      'article_access_unknown','other_unclassified','doi_unavailable')),subject),
    intercept=FALSE)
}

# Publisher-hosted access, including hybrid and bronze free-to-read articles.
# Green means repository-only OA; it must not count as publisher OA.
moderator_publisher_oa <- function(oa_status) {
  s <- tolower(trimws(as.character(oa_status)))
  stopifnot(all(is.na(s) | s %in% c('gold','hybrid','bronze','green','closed')))
  ifelse(is.na(s),NA_integer_,as.integer(s %in% c('gold','hybrid','bronze')))
}

prepare_moderator_publisher <- function(eff_long,
    trace = utils::read.csv('data/moderator_publisher_trace_overrides.csv')) {
  d <- prepare_moderator_combined(eff_long)
  stopifnot(!anyNA(trace$doi_o),!anyDuplicated(trace$doi_o),
    all(trace$verified_form %in% c('article','preprint','online_deposit','other_publisher_output')))
  ix <- match(d$doi_o,trace$doi_o)
  form <- dplyr::case_when(
    grepl('^article',d$publication_access_group) ~ 'article',
    d$publication_access_group=='preprint' ~ 'preprint',
    d$publication_access_group=='online_deposit' ~ 'online_deposit',
    TRUE ~ 'unresolved')
  form[!is.na(ix)] <- trace$verified_form[ix[!is.na(ix)]]
  # All formerly unresolved records are now explicitly source-audited.
  stopifnot(!any(form=='unresolved'))
  publisher <- moderator_publisher_oa(d$oa_status)
  override <- moderator_binary(trace$publisher_oa_override[ix])
  stopifnot(!any(!is.na(override) & form!='article'))
  publisher[!is.na(override)] <- override[!is.na(override)]
  stopifnot(!any(is.na(publisher[form=='article'])))
  d$publisher_oa <- ifelse(form=='article',publisher,NA_integer_)
  d$publisher_access_basis <- dplyr::case_when(
    form!='article' ~ NA_character_,
    !is.na(override) ~ 'source_audit_2026_09_08',
    TRUE ~ 'cached_unpaywall_oa_status')
  d$publisher_access_group <- ifelse(form=='article',
    ifelse(publisher==1L,'article_oa','article_not_publisher_oa'),form)
  for (level in c('article_oa','preprint','online_deposit','other_publisher_output'))
    d[[paste0('publisher_group_',level)]] <- as.integer(d$publisher_access_group==level)
  # Retain the cached DOI and coverage fields; recovered identifiers are separate.
  d$recovered_doi_r <- normalise_moderator_doi(trace$recovered_doi_r[ix])
  full_doi <- normalise_moderator_doi(eff_long$doi_r)
  recovered <- normalise_moderator_doi(trace$recovered_doi_r[match(eff_long$doi_o,trace$doi_o)])
  links <- data.frame(doi_o=eff_long$doi_o,doi_r=dplyr::coalesce(recovered,full_doi)) |>
    dplyr::filter(!is.na(doi_r)) |>
    dplyr::distinct(doi_o,doi_r) |>
    dplyr::count(doi_r,name='n_originals')
  effective <- dplyr::coalesce(d$recovered_doi_r,normalise_moderator_doi(d$doi_r))
  d$n_originals_for_replication <- links$n_originals[match(effective,links$doi_r)]
  d$multi_original_f <- as.integer(!is.na(d$n_originals_for_replication) &
    d$n_originals_for_replication>3L)
  d
}

moderator_publisher_formula <- function(data) {
  subject <- grep('^subj_',names(data),value=TRUE)
  subject <- subject[vapply(data[subject],function(x) any(x!=0),logical(1))]
  stats::reformulate(c('age_r','age_r_sq','has_overlap_f','SNIP_centered',
    'snip_missing_f','same_journal_f','same_journal_missing','multi_original_f',
    paste0('publisher_group_',c('article_oa','preprint','online_deposit','other_publisher_output')),
    subject),intercept=FALSE)
}
