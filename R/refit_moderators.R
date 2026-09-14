# Refit from cached first-stage effects and bootstrap variances, without APIs.
# Run from the project root: Rscript R/refit_moderators.R
suppressPackageStartupMessages({library(dplyr);library(metafor);library(clubSandwich)})
source('R/moderator_data.R')

e <- readRDS('data/eff_long_Scopus_citation.rds')
f <- unclass(readRDS('models/fit_citation_Scopus.rds'))
primary <- prepare_moderator_publication_form(e)
idx <- cbind(match(primary$time,rownames(f$eff)),match(primary$doi_o,colnames(f$eff)))
stopifnot(!anyNA(idx),max(abs(primary$att-f$eff[idx]))<1e-10,
  all(f$I.dat[idx]==1),all(f$D.dat[idx]==1))
subj <- grep('^subj_',names(primary),value=TRUE)
stopifnot(max(abs(rowSums(primary[subj])-1))<1e-10)
fit_and_save <- function(data, suffix, oa_journal=FALSE, metadata_coverage=FALSE) {
  formula <- moderator_publication_formula(data,oa_journal,metadata_coverage)
  X <- model.matrix(formula,data)
  stopifnot(!anyNA(X),qr(X)$rank==ncol(X))
  cat('Fitting',suffix,nrow(data),'paper-years from',n_distinct(data$doi_o),'originals\n')
  fit <- rma.mv(yi=att,V=sampling_var,mods=formula,random=~1|doi_o,
    method='REML',data=data,sparse=TRUE)
  stopifnot(fit$k==nrow(data))
  cr <- robust(fit,cluster=data$doi_o,clubSandwich=TRUE)
  saveRDS(data,paste0('data/primary_Scopus_citation_',suffix,'.rds'))
  saveRDS(fit,paste0('models/reg_model_Scopus_citation_',suffix,'.rds'))
  saveRDS(cr,paste0('models/reg_model_Scopus_citation_',suffix,'_CR2.rds'))
  co <- data.frame(term=rownames(fit$b),estimate=as.numeric(fit$b),se_model=fit$se,
    lower_model=fit$ci.lb,upper_model=fit$ci.ub,p_model=fit$pval,
    se_CR2=cr$se,lower_CR2=cr$ci.lb,upper_CR2=cr$ci.ub,p_CR2=cr$pval,df_CR2=cr$dfs)
  write.csv(co,paste0('docs/moderator_coefficients_',suffix,'.csv'),row.names=FALSE)
  print(co[!grepl('^subj_',co$term),],row.names=FALSE)
  writeLines(c(paste('Rows:',nrow(data)),paste('Originals:',n_distinct(data$doi_o)),
    paste('Between-paper SD:',sqrt(fit$sigma2)),deparse(formula)),
    paste0('docs/moderator_refit_',suffix,'.txt'))
  invisible(list(fit=fit,CR2=cr))
}
fit_and_save(primary,'publication_form')
# OA is identified only among ordinary journal articles with observed status.
# The multi-original group has no closed-access comparator and is excluded.
journal <- filter(primary,oa_journal_eligible)
fit_and_save(journal,'oa_within_journal',oa_journal=TRUE)
paper <- distinct(primary,doi_o,.keep_all=TRUE)
write.csv(count(paper,publication_strategy,is_oa),
  'docs/moderator_oa_original_crosstab.csv',row.names=FALSE)
write.csv(count(paper,publication_form,is_oa),
  'docs/moderator_oa_form_crosstab.csv',row.names=FALSE)

# Exploratory metadata-coverage association: supported within preprint/repository
# and other-output groups only. No DOI is a separate nuisance form, not a failed lookup.
fit_and_save(primary,'metadata_coverage',metadata_coverage=TRUE)
write.csv(count(paper,publication_form,unpaywall_coverage),
  'docs/moderator_metadata_coverage_crosstab.csv',row.names=FALSE)
