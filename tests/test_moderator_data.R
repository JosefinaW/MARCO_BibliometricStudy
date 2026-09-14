suppressPackageStartupMessages(library(dplyr))
source('R/moderator_data.R')
expected <- c(0L,1L,NA_integer_)
stopifnot(identical(moderator_binary(c(FALSE,TRUE,NA)),expected),
 identical(moderator_binary(factor(c('FALSE','TRUE',NA))),expected),
 identical(moderator_binary(c(0,1,NA)),expected))
x<-tibble(doi_o=c('a','a','a'),time=rep(2020L,3),SNIP=c(2,NA,2),
 same_journal=c(FALSE,NA,FALSE),host_organization_name=c('Journal','Repository','Journal'))
y<-collapse_moderator_rows(x,c('doi_o','time'))
stopifnot(nrow(y)==1,y$SNIP==2,identical(y$same_journal,FALSE),
 y$host_organization_name=='Journal; Repository')
x$SNIP[2]<-3
stopifnot(inherits(try(collapse_moderator_rows(x,c('doi_o','time')),silent=TRUE),'try-error'))
e<-readRDS('data/eff_long_Scopus_citation.rds');d<-prepare_moderator_primary(e)
stopifnot(nrow(d)==2690,n_distinct(d$doi_o)==591,!anyDuplicated(d[c('doi_o','time')]),
 is.integer(d$gap_years),all(d$gap_years>=2L),!anyNA(d$gap_years),
 all(tapply(d$gap_years,d$doi_o,function(x) length(unique(x)))==1L),
 all(d$same_journal_f[d$same_journal==0 & !is.na(d$same_journal)]==0),
 all(d$is_oa_f[d$is_oa==1 & !is.na(d$is_oa)]==1))
# Repeated execution and factor input must not change model coding.
factor_input<-e;factor_input$same_journal<-factor(e$same_journal);factor_input$is_oa<-factor(e$is_oa)
d2<-prepare_moderator_primary(factor_input)
stopifnot(identical(d$same_journal_f,d2$same_journal_f),identical(d$is_oa_f,d2$is_oa_f))
cat('Moderator data tests passed\n')

stopifnot(identical(normalise_moderator_doi(c(' HTTPS://doi.org/10.1234/ABC ',
 'http://dx.doi.org/10.1234/abc','doi:10.1234/abc')),rep('10.1234/abc',3)))
# Run the actual upstream location-collapse joins on the metadata cache.
meta<-readRDS('data/metadata_OpenAlex.rds')
r<-readRDS('data/metadata_r_OpenAlex.rds')
r$doi<-normalise_moderator_doi(r$doi)
r<-r[r$doi %in% normalise_moderator_doi(meta$doi_r),]
a<-collapse_moderator_rows(select(r,doi,issn_l),'doi')
b<-collapse_moderator_rows(select(r,doi,type,host_organization_name),'doi')
stopifnot(!anyDuplicated(a$doi),!anyDuplicated(b$doi),nrow(a)>500)
cat('Upstream metadata join tests passed\n')

stopifnot(is.logical(d$same_journal),is.logical(d$is_oa),
 is.factor(d2$same_journal),is.factor(d2$is_oa))
cat('Raw moderator types preserved for downstream analyses\n')

# Joint publication/access coding: never extrapolate across unsupported cells.
a <- prepare_moderator_publication_form(e)
stopifnot(identical(a$att,d$att),identical(a$sampling_var,d$sampling_var),
  nrow(a)==2690,n_distinct(a$doi_o)==591,
  all(a$publication_form[is.na(a$doi_r)]=='unidentified'),
  all(a$form_multi_original_article[is.na(a$doi_r)]==0),
  !anyNA(a$publication_form))
p <- distinct(a,doi_o,.keep_all=TRUE)
stopifnot(sum(p$publication_form=='journal_article')==355,
  sum(p$publication_form=='multi_original_article')==69,
  sum(p$publication_form=='preprint_repository')==125,
  sum(p$publication_form=='other_output')==35,
  sum(p$publication_form=='unidentified')==7,
  sum(p$oa_journal_eligible)==355,
  all(p$is_oa[p$publication_form=='multi_original_article']),
  sum(is.na(p$is_oa[p$publication_form=='preprint_repository']))==68)
j <- filter(a,oa_journal_eligible)
for (restricted in c(FALSE,TRUE)) {
  input <- if(restricted) j else a
  fm <- moderator_publication_formula(input,restricted)
  mm <- model.matrix(fm,input)
  stopifnot(qr(mm)$rank==ncol(mm),!anyNA(mm),
    !any(c('is_oa_missing','pub_preprint','pub_meta') %in% colnames(mm)),
    ('is_oa_f' %in% colnames(mm))==restricted)
}
# Adversarial metadata: broad publisher prefixes must not imply preprint, and
# missing OA must not enter the restricted OA comparison as a closed record.
fixture <- e[rep(1,5),]
fixture$doi_o <- paste0('fixture',1:5)
fixture$doi_r <- c('10.1590/journal.article','10.5281/zenodo.123',
 '10.1234/example','10.1234/no-oa',NA)
fixture$type_r <- rep('article',5)
fixture$issn_l_r <- rep('1234-5678',5)
fixture$publication_strategy <- c('published','preprint','published','published','meta')
fixture$is_oa <- c(TRUE,NA,FALSE,NA,NA)
fixture$time <- fixture$publication_year_r+2
fixture_years <- data.frame(doi_o=fixture$doi_o,year_o=fixture$publication_year_r-3L)
z <- prepare_moderator_publication_form(fixture,fixture_years)
stopifnot(all(z$gap_years==3L))
stopifnot(identical(z$publication_form,c('journal_article','preprint_repository',
 'journal_article','journal_article','unidentified')),
 identical(z$oa_journal_eligible,c(TRUE,FALSE,TRUE,FALSE,FALSE)))
cat('Publication form and observed journal-OA tests passed\n')

# Retrieved access metadata is a coverage variable, not an inferred access or
# indexing status. Missing DOI is kept separate from missing status with DOI.
stopifnot(sum(p$unpaywall_coverage=='status_available')==503,
 sum(p$unpaywall_coverage=='status_not_retrieved')==81,
 sum(p$unpaywall_coverage=='doi_unavailable')==7,
 all(p$unpaywall_status_not_retrieved[is.na(p$doi_r)]==0L),
 identical(z$unpaywall_coverage,c('status_available','status_not_retrieved',
  'status_available','status_not_retrieved','doi_unavailable')))
coverage_X <- model.matrix(moderator_publication_formula(a,metadata_coverage=TRUE),a)
stopifnot(qr(coverage_X)$rank==ncol(coverage_X),
 !('is_oa_f' %in% colnames(coverage_X)),
 inherits(try(moderator_publication_formula(j,oa_journal=TRUE,
  metadata_coverage=TRUE),silent=TRUE),'try-error'))
cat('Metadata coverage coding and model support tests passed\n')

# Joint categories required for the talk. Preprint requires explicit type;
# repository namespace alone denotes a deposit even if an incidental location
# supplies a journal ISSN. Unknown access and unclassified forms remain nuisance.
cmb <- prepare_moderator_combined(e)
cp <- distinct(cmb,doi_o,.keep_all=TRUE)
expected_group <- c(article_oa=277L,article_closed=155L,preprint=105L,
 online_deposit=32L,article_access_unknown=4L,other_unclassified=11L,doi_unavailable=7L)
stopifnot(all(table(cp$publication_access_group)[names(expected_group)]==expected_group),
 identical(cmb$att,a$att),identical(cmb$sampling_var,a$sampling_var),
 all(cp$type_r[cp$publication_access_group=='preprint']=='preprint'),
 all(cp$publication_access_group[cp$multi_original_f==1]=='article_oa'),
 sum(cp$multi_original_f)==69L,
 all(is.na(cp$is_oa[cp$publication_access_group=='article_access_unknown'])))
cm <- model.matrix(moderator_combined_formula(cmb),cmb)
stopifnot(qr(cm)$rank==ncol(cm),!anyNA(cm),
 !any(c('is_oa_f','is_oa_missing','pub_preprint','pub_meta') %in% colnames(cm)))
cz <- prepare_moderator_combined(fixture,original_years=fixture_years)
stopifnot(identical(cz$publication_access_group,c('article_oa','online_deposit',
 'article_closed','article_access_unknown','doi_unavailable')))
# Namespace alone cannot create preprint, but explicit type can.
fixture$type_r[2] <- 'preprint'
stopifnot(prepare_moderator_combined(fixture,original_years=fixture_years)$publication_access_group[2]=='preprint')
cat('Combined publication/access categories and full-rank design tests passed\n')

# Publisher access excludes repository-only green OA, includes hybrid and bronze,
# and never converts missing status to closed without source evidence.
stopifnot(identical(moderator_publisher_oa(c('gold','hybrid','bronze','green','closed',NA)),
 c(1L,1L,1L,0L,0L,NA_integer_)),
 inherits(try(moderator_publisher_oa('unrecognised'),silent=TRUE),'try-error'))
pub <- prepare_moderator_publisher(e)
pp <- distinct(pub,doi_o,.keep_all=TRUE)
expected_pub <- c(article_oa=194L,article_not_publisher_oa=243L,
 preprint=108L,online_deposit=35L,other_publisher_output=11L)
stopifnot(all(table(pp$publisher_access_group)[names(expected_pub)]==expected_pub),
 identical(pub$att,a$att),identical(pub$sampling_var,a$sampling_var),
 identical(pub$publication_year_r,a$publication_year_r),identical(pub$doi_r,a$doi_r),
 identical(pub$unpaywall_coverage,a$unpaywall_coverage),
 all(pp$publisher_oa[pp$oa_status %in% 'green' & !is.na(pp$publisher_oa)]==0L),
 sum(pp$publisher_access_basis %in% 'source_audit_2026_09_08')==5L,
 sum(pp$multi_original_f)==69L,
 sum(!is.na(pp$recovered_doi_r))==1L,
 pp$recovered_doi_r[pp$doi_o=='10.1006/jmla.1996.0032']=='10.31234/osf.io/qsyd2')
tr <- read.csv('data/moderator_publisher_trace_overrides.csv')
stopifnot(nrow(tr)==23L,!anyDuplicated(tr$doi_o),
 all(cp$doi_o[cp$publication_access_group %in% c('article_access_unknown',
  'other_unclassified','doi_unavailable')] %in% tr$doi_o))
pm <- model.matrix(moderator_publisher_formula(pub),pub)
stopifnot(qr(pm)$rank==ncol(pm),!anyNA(pm),
 !any(c('is_oa_f','is_oa_missing','pub_preprint','pub_meta') %in% colnames(pm)),
 inherits(try(prepare_moderator_publisher(e,rbind(tr,tr[1,])),silent=TRUE),'try-error'))
cat('Publisher OA, all22 source traces, provenance and final model tests passed\n')
stopifnot(sum(pp$multi_original_f[pp$publisher_access_group=='article_oa'])==23L,
 sum(pp$multi_original_f[pp$publisher_access_group=='article_not_publisher_oa'])==46L)
cat('Multi-original support in both publisher-access groups verified\n')
