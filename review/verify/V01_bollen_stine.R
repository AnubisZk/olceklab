# V01 — Bollen–Stine bootstrap davranışı (lavaan)
# Amaç: SPEC §7 M6'daki Bollen–Stine iddialarını doğrulamak.
# Çalıştırma: Rscript V01_bollen_stine.R
suppressPackageStartupMessages(library(lavaan))
cat("R:", R.version.string, "| lavaan:", as.character(packageVersion("lavaan")), "\n\n")

hs_model <- "visual =~ x1 + x2 + x3
             textual =~ x4 + x5 + x6
             speed =~ x7 + x8 + x9"
B <- 200L

cat("== (a) HS1939, ML: lavaan belgesindeki bilinen uyum değerleri ==\n")
fit_ml <- cfa(hs_model, data = HolzingerSwineford1939)
print(round(fitMeasures(fit_ml, c("chisq", "df", "pvalue", "cfi", "tli", "rmsea", "srmr")), 3))

cat("\n== (b) Bollen–Stine p değerinin konumu ==\n")
set.seed(20261030)
fit_bs <- cfa(hs_model, data = HolzingerSwineford1939,
              test = "bollen.stine", bootstrap = B)
tst <- lavInspect(fit_bs, "test")
cat("lavInspect(fit,'test') ögeleri:", paste(names(tst), collapse = ", "), "\n")
bs <- tst$bollen.stine
cat(sprintf("stat=%.3f df=%d pvalue=%.4f boot.larger=%d boot.length=%d\n",
            bs$stat, as.integer(bs$df), bs$pvalue, bs$boot.larger, bs$boot.length))
cat("p = boot.larger/boot.length ?", isTRUE(all.equal(bs$pvalue, bs$boot.larger / bs$boot.length)), "\n")
cat("(b+1)/(B+1) (Davison & Hinkley, 1997):", round((bs$boot.larger + 1) / (bs$boot.length + 1), 4), "\n")
fm_names <- names(fitMeasures(fit_bs))
cat("fitMeasures içinde 'bollen' geçen adlar:", paste(grep("bollen|boot", fm_names, value = TRUE), collapse = ", "), "\n")

cat("\n== (c) Tekrarlanabilirlik: set.seed ve iseed ==\n")
p_seed <- function(s) { set.seed(s); f <- cfa(hs_model, HolzingerSwineford1939, test = "bollen.stine", bootstrap = 50L); lavInspect(f, "test")$bollen.stine$pvalue }
p_iseed <- function(s) { f <- cfa(hs_model, HolzingerSwineford1939, test = "bollen.stine", bootstrap = 50L, iseed = s); lavInspect(f, "test")$bollen.stine$boot.T }
cat("set.seed(1) iki kez -> aynı p:", identical(p_seed(1), p_seed(1)), "\n")
a <- p_iseed(7); runif(5); b <- p_iseed(7)
cat("iseed = 7 iki kez (arada RNG ilerletildi) -> aynı boot.T:", identical(a, b), "\n")

cat("\n== (d) Kategorik veri (WLSMV) ile Bollen–Stine ==\n")
d <- HolzingerSwineford1939[, paste0("x", 1:9)]
d[] <- lapply(d, function(v) cut(v, quantile(v, c(0, 1/3, 2/3, 1)), include.lowest = TRUE, labels = FALSE))
r <- tryCatch(cfa(hs_model, data = d, ordered = names(d), estimator = "WLSMV",
                  test = "bollen.stine", bootstrap = 20L),
              error = function(e) paste("HATA:", conditionMessage(e)))
cat(if (is.character(r)) r else "hata yok (beklenmeyen)", "\n")

cat("\n== (e) Eksik veri (missing = 'ml') ile Bollen–Stine ==\n")
hm <- HolzingerSwineford1939; hm$x1[1:10] <- NA
r <- tryCatch(cfa(hs_model, data = hm, missing = "ml", test = "bollen.stine", bootstrap = 20L),
              error = function(e) paste("HATA:", conditionMessage(e)))
cat(if (is.character(r)) r else "hata yok (beklenmeyen)", "\n")

cat("\n== (f) MLR + Bollen–Stine: hangi istatistik bootstrap'lenir? ==\n")
set.seed(3)
r <- tryCatch({
  f <- cfa(hs_model, data = HolzingerSwineford1939, estimator = "MLR",
           test = c("yuan.bentler.mplus", "bollen.stine"), bootstrap = 50L)
  t <- lavInspect(f, "test")
  cat("testler:", paste(names(t), collapse = ", "), "\n")
  cat(sprintf("bollen.stine$stat = %.3f ; standard$stat = %.3f ; yuan.bentler.mplus$stat = %.3f\n",
              t$bollen.stine$stat, t$standard$stat, t$yuan.bentler.mplus$stat))
  "ok"
}, error = function(e) paste("HATA:", conditionMessage(e)))
cat(r, "\n")

cat("\n== (g) likelihood = 'wishart' ile MLR ==\n")
r <- tryCatch({
  f <- cfa(hs_model, data = HolzingerSwineford1939, estimator = "MLR", likelihood = "wishart")
  sprintf("hata yok; lavInspect(options)$likelihood = %s", lavInspect(f, "options")$likelihood)
}, warning = function(w) paste("UYARI:", conditionMessage(w)),
   error = function(e) paste("HATA:", conditionMessage(e)))
cat(r, "\n")
