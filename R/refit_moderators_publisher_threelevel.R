# Primary publisher-access model with a replication level above the original.
# Originals tested in the same replication publication share its authors, venue and
# publication event, so their effects are dependent beyond the within-original level.
# Run from project root: Rscript R/refit_moderators_publisher_threelevel.R
suppressPackageStartupMessages({library(dplyr);library(metafor);library(clubSandwich)})
source('R/moderator_data.R')
e <- readRDS('data/eff_long_Scopus_citation.rds')
d <- prepare_moderator_publisher(e)
d$replication_id <- moderator_replication_id(d)
f <- unclass(readRDS('models/fit_citation_Scopus.rds'))
idx <- cbind(match(d$time,rownames(f$eff)),match(d$doi_o,colnames(f$eff)))
stopifnot(!anyNA(idx),max(abs(d$att-f$eff[idx]))<1e-10,
  all(f$I.dat[idx]==1),all(f$D.dat[idx]==1))
formula <- moderator_publisher_formula(d)
X <- model.matrix(formula,d)
stopifnot(!anyNA(X),qr(X)$rank==ncol(X))
cat('Fitting three-level publisher access:',nrow(d),'paper-years;',
  n_distinct(d$doi_o),'originals;',n_distinct(d$replication_id),'replications\n')
fit <- rma.mv(yi=att,V=sampling_var,mods=formula,random=~1|replication_id/doi_o,
  method='REML',data=d,sparse=TRUE)
stopifnot(fit$k==nrow(d),length(fit$sigma2)==2L,grepl("^replication_id",fit$s.names[1]))
cr <- robust(fit,cluster=d$replication_id,clubSandwich=TRUE)
saveRDS(d,'data/primary_Scopus_citation_publisher_access_threelevel.rds')
saveRDS(fit,'models/reg_model_Scopus_citation_publisher_access_threelevel.rds')
saveRDS(cr,'models/reg_model_Scopus_citation_publisher_access_threelevel_CR2.rds')
co <- data.frame(term=rownames(fit$b),estimate=as.numeric(fit$b),se_model=fit$se,
  lower_model=fit$ci.lb,upper_model=fit$ci.ub,p_model=fit$pval,
  se_CR2=cr$se,lower_CR2=cr$ci.lb,upper_CR2=cr$ci.ub,p_CR2=cr$pval,df_CR2=cr$dfs)
write.csv(co,'docs/moderator_coefficients_publisher_access_threelevel.csv',row.names=FALSE)
print(co[!grepl('^subj_',co$term),],row.names=FALSE)
vc <- setNames(fit$sigma2,c('replication','original_within_replication'))
print(round(vc,1))
writeLines(c(paste('Rows:',nrow(d)),paste('Originals:',n_distinct(d$doi_o)),
  paste('Replications:',n_distinct(d$replication_id)),
  paste('Between-replication SD:',sqrt(vc[1])),
  paste('Between-original-within-replication SD:',sqrt(vc[2])),
  'CR2 cluster: replication_id',deparse(formula)),
  'docs/moderator_refit_publisher_access_threelevel.txt')
