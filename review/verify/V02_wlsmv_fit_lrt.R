# V02 — WLSMV uyum indeksleri, AIC/BIC ve ölçeklenmiş fark testleri
# Gerçek sıralı veri: psych::bfi (6 kategorili Likert), Nevrotiklik (N1–N5) ve Sorumluluk (C1–C5).
suppressPackageStartupMessages({ library(lavaan); library(psych) })
cat("R:", R.version.string, "| lavaan:", as.character(packageVersion("lavaan")),
    "| psych:", as.character(packageVersion("psych")), "\n\n")
data(bfi, package = "psych")
items <- c(paste0("N", 1:5), paste0("C", 1:5))
d <- na.omit(bfi[, c(items, "gender")])
d[, c("C4", "C5")] <- 7 - d[, c("C4", "C5")]  # ters maddeler
cat("N (liste bazında):", nrow(d), "\n")

m2 <- "Neu =~ N1 + N2 + N3 + N4 + N5
       Con =~ C1 + C2 + C3 + C4 + C5"
m1 <- "G =~ N1 + N2 + N3 + N4 + N5 + C1 + C2 + C3 + C4 + C5"

f2 <- cfa(m2, d, ordered = items, estimator = "WLSMV", std.lv = TRUE)
f1 <- cfa(m1, d, ordered = items, estimator = "WLSMV", std.lv = TRUE)

cat("== (a) WLSMV test istatistiği adı ==\n")
cat(paste(names(lavInspect(f2, "test")), collapse = ", "), "\n")

cat("\n== (b) .scaled ile .robust indeksler aynı şey değildir ==\n")
fm <- fitMeasures(f2, c("chisq.scaled", "df.scaled", "cfi.scaled", "cfi.robust",
                        "tli.scaled", "tli.robust", "rmsea.scaled", "rmsea.robust", "srmr"))
print(round(fm, 4))

cat("\n== (c) WLSMV'de AIC/BIC ==\n")
print(fitMeasures(f2, c("aic", "bic")))

cat("\n== (d) lavTestLRT varsayılan yöntemi (WLSMV) ==\n")
lrt <- lavTestLRT(f2, f1)
print(lrt)
cat("başlık:", attr(lrt, "heading"), "\n")
naive <- fitMeasures(f1, "chisq.scaled") - fitMeasures(f2, "chisq.scaled")
cat(sprintf("Saf fark (chisq.scaled farkı) = %.3f  <-> lavTestLRT Chisq diff = %.3f\n",
            naive, lrt[2, "Chisq diff"]))

cat("\n== (e) MLR (sürekli kabul) için varsayılan yöntem ==\n")
g2 <- cfa(m2, d, estimator = "MLR", std.lv = TRUE)
g1 <- cfa(m1, d, estimator = "MLR", std.lv = TRUE)
l2 <- lavTestLRT(g2, g1)
cat("başlık:", attr(l2, "heading"), "\n")
l3 <- lavTestLRT(g2, g1, method = "satorra.bentler.2010")
cat(sprintf("SB2001 Δχ² = %.3f ; SB2010 Δχ² = %.3f\n", l2[2, "Chisq diff"], l3[2, "Chisq diff"]))

cat("\n== (f) ML: likelihood normal vs wishart ==\n")
h1 <- cfa(m2, d, estimator = "ML", likelihood = "normal")
h2 <- cfa(m2, d, estimator = "ML", likelihood = "wishart")
print(round(rbind(normal = fitMeasures(h1, c("chisq", "df", "rmsea", "aic", "bic")),
                  wishart = fitMeasures(h2, c("chisq", "df", "rmsea", "aic", "bic"))), 3))
cat(sprintf("chisq oranı normal/wishart = %.6f ; N/(N-1) = %.6f\n",
            fitMeasures(h1, "chisq") / fitMeasures(h2, "chisq"), nrow(d) / (nrow(d) - 1)))
