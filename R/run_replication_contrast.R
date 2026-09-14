# Run from project root:
# Rscript R/run_replication_contrast.R panel.rds events.csv output_dir [nboots]
source("R/replication_contrast.R")
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L || length(args) > 4L)
  stop("Usage: Rscript R/run_replication_contrast.R panel.rds events.csv output_dir [nboots]")
out <- args[3]
dir.create(out, showWarnings = FALSE, recursive = TRUE)
prepared <- prepare_replication_contrast(readRDS(args[1]), read.csv(args[2]))
write.csv(prepared$audit, file.path(out, "sample_audit.csv"), row.names = FALSE)
write.csv(prepared$support, file.path(out, "cohort_support.csv"), row.names = FALSE)
result <- run_replication_contrast(prepared,
  nboots = if (length(args) == 4L) as.integer(args[4]) else 500L)
saveRDS(result, file.path(out, "result.rds"))
for (name in c("estimates", "draws", "failures", "placebo"))
  write.csv(result[[name]], file.path(out, paste0(name, ".csv")), row.names = FALSE)
capture.output(sessionInfo(), file = file.path(out, "sessionInfo.txt"))
writeLines(c(paste("Panel MD5:", tools::md5sum(args[1])),
             paste("Events MD5:", tools::md5sum(args[2]))), file.path(out, "input_checksums.txt"))
print(result$estimates[result$estimates$period == "primary", ])
if (!result$inference_ok) stop("Bootstrap inference failed; diagnostics saved in ", out)
