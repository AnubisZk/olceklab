# V10 — semTools 0.5-9 (belge sahibinin §11.3 ortamı) ile 0.5-10 (ÖlçekLab renv.lock) karşılaştırması.
# Kaynak farkı: yalnızca R/measEq.R (update() yöntemi), R/fitIndices.R (chisqSmallN) ve R/permuteMeasEq.R
# değişti; htmt.R ve reliability.R (compRelSEM, AVE) iki sürümde aynıdır. Bu betik bunu sayısal olarak da denetler.
# Çalıştırma: SEMTOOLS_059_LIB=/yol/semTools-0.5-9-kutuphanesi Rscript V10_semtools_059_vs_0510.R
lib059 <- Sys.getenv("SEMTOOLS_059_LIB")
stopifnot(nzchar(lib059))
calc <- function() {
  suppressPackageStartupMessages({library(lavaan); library(semTools)})
  hs <- HolzingerSwineford1939
  m3 <- "visual =~ x1+x2+x3\n textual =~ x4+x5+x6\n speed =~ x7+x8+x9"
  b <- psych::bfi[complete.cases(psych::bfi[, 1:25]), 1:25]
  for (i in c("A1", "C4", "C5", "E1", "E2", "O2", "O5")) b[[i]] <- 7 - b[[i]]
  mb <- "A =~ A1+A2+A3+A4+A5\n C =~ C1+C2+C3+C4+C5\n E =~ E1+E2+E3+E4+E5\n N =~ N1+N2+N3+N4+N5\n O =~ O1+O2+O3+O4+O5"
  f <- cfa(m3, hs); fw <- cfa(mb, b, ordered = TRUE, estimator = "WLSMV")
  out <- list(version = as.character(packageVersion("semTools")))
  for (a in c(TRUE, FALSE)) for (h2 in c(TRUE, FALSE)) {
    out[[sprintf("htmt_hs_abs%s_h2%s", a, h2)]] <- unclass(htmt(m3, hs[, paste0("x", 1:9)], absolute = a, htmt2 = h2))
    out[[sprintf("htmt_bfi_abs%s_h2%s", a, h2)]] <- unclass(htmt(mb, b, absolute = a, htmt2 = h2))
  }
  out$htmt_bfi_poly <- unclass(htmt(mb, b, ordered = names(b), htmt2 = FALSE))
  for (ov in c(TRUE, FALSE)) {
    out[[sprintf("omega_hs_obs%s", ov)]] <- as.numeric(compRelSEM(f, obs.var = ov, simplify = TRUE))
    out[[sprintf("ave_hs_obs%s", ov)]] <- as.numeric(AVE(f, obs.var = ov))
    out[[sprintf("omega_bfi_obs%s", ov)]] <- as.numeric(compRelSEM(fw, obs.var = ov, simplify = TRUE))
  }
  out$omega_bfi_ordscaleF <- as.numeric(compRelSEM(fw, ord.scale = FALSE, simplify = TRUE))
  out$ave_bfi <- as.numeric(AVE(fw))
  bfi_g <- psych::bfi[complete.cases(psych::bfi[, c(1:10, 26)]), c(1:10, 26)]
  for (lvl in c("configural", "thresholds", "loadings", "intercepts")) {
    eq <- switch(lvl, configural = "", thresholds = "thresholds", loadings = c("thresholds", "loadings"),
                 intercepts = c("thresholds", "loadings", "intercepts"))
    syn <- measEq.syntax("A =~ A1+A2+A3+A4+A5\n C =~ C1+C2+C3+C4+C5", data = bfi_g, ordered = paste0(c("A", "C"), rep(1:5, each = 2)),
                         group = "gender", parameterization = "theta", ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016",
                         group.equal = eq, return.fit = FALSE)
    out[[paste0("measEq_", lvl)]] <- as.character(syn)
  }
  out
}
a <- callr::r(calc, libpath = c(lib059, .libPaths()))
b <- callr::r(calc)
cat("semTools sürümleri:", a$version, "ve", b$version, "\n")
keys <- setdiff(names(a), "version")
same <- vapply(keys, function(k) identical(a[[k]], b[[k]]), logical(1))
for (k in keys) cat(sprintf("%-28s %s\n", k, if (same[[k]]) "birebir aynı" else "FARKLI"))
cat(sprintf("\nSonuç: %d/%d karşılaştırma birebir aynı.\n", sum(same), length(same)))
