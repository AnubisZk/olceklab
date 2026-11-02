# Belge sahibinin (Z. S. Kıvılcım) 3 Kasım 2026 tarihli referans betiği.
# Tek değişiklik: iki read_excel() dosya yolu ortam değişkenine çevrildi (dosya adları depoya girmesin diye).
# Gerçek veriyle çıktısı: docs/validation/bidekcet_referans_cikti_2026-11-03.txt
# CI'da sentetik, aynı düzende dosyalarla çalıştırılır (test-bidekcet-harness.R).
# BİDEKÇET §11.3 referans değerleri — ham Excel dosyalarından baştan üretir
suppressPackageStartupMessages({library(readxl); library(psych); library(lavaan); library(semTools)})
it <- paste0("M", c(1:6, 8:13))
# --- Temizleme (sıra: 1 grup/sınıf filtresi, 2 birleştirme, 3 eksik, 4 aralık 1-5, 5 düz yanıt)
o <- read_excel(Sys.getenv("BIDEKCET_ORTAOKUL_XLSX")); n_o_ham <- nrow(o)
names(o)[grepl("^s.n.f$", names(o))] <- "sinif"
o <- o[!is.na(o$sinif), ]; o$grup <- "Ortaokul"
l <- read_excel(Sys.getenv("BIDEKCET_LISE_XLSX")); n_l_ham <- nrow(l)
names(l) <- sub("^Madde", "M", trimws(names(l)))
l <- l[l$Sinif %in% 9:12, ]; l$grup <- "Lise"
adim <- function(d) table(factor(d$grup, levels = c("Ortaokul", "Lise")))
d <- rbind(o[, c("grup", it)], l[, c("grup", it)]); a1 <- adim(d)
d <- d[complete.cases(d[, it]), ]; a2 <- adim(d)
d <- d[apply(d[, it], 1, function(r) all(r >= 1 & r <= 5)), ]; a3 <- adim(d)
d <- d[apply(d[, it], 1, function(r) length(unique(r)) > 1), ]; a4 <- adim(d)
cat("Ham satir: Ortaokul", n_o_ham, "Lise", n_l_ham, "\n")
print(rbind(sinif_filtresi_sonrasi = a1, eksik_sonrasi = a2, aralik_sonrasi = a3, duz_yanit_sonrasi = a4))
d <- as.data.frame(d); d$grup <- factor(d$grup, levels = c("Ortaokul", "Lise"))
o <- d[d$grup == "Ortaokul", it]; l <- d[d$grup == "Lise", it]
cat("\nAlfa:", round(alpha(o)$total$raw_alpha, 3), round(alpha(l)$total$raw_alpha, 3), "\n")
cat("KMO:", round(KMO(o)$MSA, 3), round(KMO(l)$MSA, 3), "\n")
set.seed(1); po <- fa.parallel(o, fa = "pc", n.iter = 1000, plot = FALSE); set.seed(1); pl <- fa.parallel(l, fa = "pc", n.iter = 1000, plot = FALSE)
cat("Paralel analiz (bilesen):", po$ncomp, pl$ncomp, "\n")
m1 <- "BK =~ M1+M2+M3+M4+M5+M6+M8 \n CT =~ M10+M12+M13 \n KD =~ M9+M11"
m4 <- "BK =~ M4+M5+M6+M8 \n FM =~ M1+M2+M3 \n KD =~ M9+M11 \n CT =~ M10+M12+M13"
for (g in list(o, l)) { f1 <- cfa(m1, g, likelihood = "wishart"); f4 <- cfa(m4, g, likelihood = "wishart")
  cat("M4 chisq", round(fitMeasures(f4, "chisq"), 3), "df", fitMeasures(f4, "df"), "| M1 chisq", round(fitMeasures(f1, "chisq"), 3),
      "| dchisq", round(anova(f4, f1)[2, "Chisq diff"], 2), "\n") }
mg <- function(eq = character(0), p = character(0)) cfa(m4, d, group = "grup", likelihood = "wishart", std.lv = TRUE, group.equal = eq, group.partial = p)
cf <- mg(); me <- mg("loadings"); sc <- mg(c("loadings", "intercepts"))
print(round(sapply(list(bicimsel = cf, metrik = me, skaler = sc), fitMeasures, c("chisq", "df", "srmr", "srmr_bentler_nomean")), 4))
mk <- mg("loadings", "CT=~M10"); sk <- mg(c("loadings", "intercepts"), c("CT=~M10", "M4~1"))
a <- anova(cf, mk); b <- anova(mk, sk)
cat("Kismi metrik: dchisq", round(a[2, "Chisq diff"], 2), "df", a[2, "Df diff"], "p", round(a[2, "Pr(>Chisq)"], 3), "\n")
cat("Kismi skaler: dchisq", round(b[2, "Chisq diff"], 2), "df", b[2, "Df diff"], "p", round(b[2, "Pr(>Chisq)"], 3), "\n")
cat("HTMT formals:", paste(names(formals(htmt)), collapse = ", "), "\n")
h_abs <- htmt(m4, o, htmt2 = FALSE); h_raw <- htmt(m4, o, htmt2 = FALSE, absolute = FALSE)
cat("HTMT BK-FM (Pearson) absolute=TRUE:", round(h_abs["FM", "BK"], 3), " absolute=FALSE:", round(h_raw["FM", "BK"], 3), "\n")
cat("HTMT BK-CT absolute=TRUE:", round(h_abs["CT", "BK"], 3), " absolute=FALSE:", round(h_raw["CT", "BK"], 3), "\n")
for (nm in c("Ortaokul", "Lise")) { fw <- cfa(m4, d[d$grup == nm, it], ordered = it, estimator = "WLSMV", std.lv = TRUE)
  print(round(fitMeasures(fw, c("cfi.scaled", "cfi.robust", "rmsea.scaled", "rmsea.robust")), 3)) }
sessionInfo()
