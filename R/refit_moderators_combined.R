# Current joint publication/access model. Earlier models remain sensitivities.
# Run from project root: Rscript R/refit_moderators_combined.R
suppressPackageStartupMessages({library(dplyr);library(metafor);library(clubSandwich)})
source('R/moderator_data.R')
e <- readRDS('data/eff_long_Scopus_citation.rds')
d <- prepare_moderator_combined(e)
f <- unclass(readRDS('models/fit_citation_Scopus.rds'))
idx <- cbind(match(d$time,rownames(f$eff)),match(d$doi_o,colnames(f$eff)))
stopifnot(!anyNA(idx),max(abs(d$att-f$eff[idx]))<1e-10,
  all(f$I.dat[idx]==1),all(f$D.dat[idx]==1))
formula <- moderator_combined_formula(d)
X <- model.matrix(formula,d)
stopifnot(!anyNA(X),qr(X)$rank==ncol(X),
  max(abs(rowSums(d[grep('^subj_',names(d),value=TRUE)])-1))<1e-10)
cat('Fitting combined publication/access:',nrow(d),'paper-years;',n_distinct(d$doi_o),'originals\n')
fit <- rma.mv(yi=att,V=sampling_var,mods=formula,random=~1|doi_o,
  method='REML',data=d,sparse=TRUE)
stopifnot(fit$k==nrow(d))
cr <- robust(fit,cluster=d$doi_o,clubSandwich=TRUE)
saveRDS(d,'data/primary_Scopus_citation_publication_access.rds')
saveRDS(fit,'models/reg_model_Scopus_citation_publication_access.rds')
saveRDS(cr,'models/reg_model_Scopus_citation_publication_access_CR2.rds')
co <- data.frame(term=rownames(fit$b),estimate=as.numeric(fit$b),se_model=fit$se,
  lower_model=fit$ci.lb,upper_model=fit$ci.ub,p_model=fit$pval,
  se_CR2=cr$se,lower_CR2=cr$ci.lb,upper_CR2=cr$ci.ub,p_CR2=cr$pval,df_CR2=cr$dfs)
write.csv(co,'docs/moderator_coefficients_publication_access.csv',row.names=FALSE)
paper <- distinct(d,doi_o,.keep_all=TRUE)
write.csv(count(paper,publication_access_group,is_oa,unpaywall_coverage,multi_original_f),
  'docs/moderator_publication_access_crosstab.csv',row.names=FALSE)
write.csv(select(paper,doi_o,doi_r,type_r,is_oa,publication_access_group,
  unpaywall_coverage,n_originals_for_replication,multi_original_f),
  'docs/moderator_publication_access_coding_audit.csv',row.names=FALSE)
print(count(paper,publication_access_group))
print(co[!grepl('^subj_',co$term),],row.names=FALSE)
writeLines(c(paste('Rows:',nrow(d)),paste('Originals:',n_distinct(d$doi_o)),
  paste('Between-paper SD:',sqrt(fit$sigma2)),deparse(formula)),
  'docs/moderator_refit_publication_access.txt')
