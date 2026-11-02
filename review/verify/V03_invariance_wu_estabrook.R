# V03 — Kategorik ölçme değişmezliği: Wu & Estabrook (2016) tanımlaması (semTools::measEq.syntax)
# Gerçek veri: psych::bfi, cinsiyete göre iki grup, 6 kategorili maddeler.
suppressPackageStartupMessages({ library(lavaan); library(semTools); library(psych) })
cat("R:", R.version.string, "| lavaan:", as.character(packageVersion("lavaan")),
    "| semTools:", as.character(packageVersion("semTools")), "\n\n")
data(bfi, package = "psych")
items <- c(paste0("N", 1:5), paste0("C", 1:5))
d <- na.omit(bfi[, c(items, "gender")])
d[, c("C4", "C5")] <- 7 - d[, c("C4", "C5")]
d$gender <- factor(d$gender, labels = c("male", "female"))
cat("Grup büyüklükleri:\n"); print(table(d$gender))
m2 <- "Neu =~ N1 + N2 + N3 + N4 + N5
       Con =~ C1 + C2 + C3 + C4 + C5"

fit_step <- function(eq) {
  syn <- measEq.syntax(configural.model = m2, data = d, ordered = items,
                       parameterization = "theta", ID.fac = "std.lv",
                       ID.cat = "Wu.Estabrook.2016", group = "gender",
                       group.equal = eq)
  cfa(as.character(syn), data = d, group = "gender", ordered = items,
      estimator = "WLSMV", parameterization = "theta")
}
steps <- list(
  configural            = "configural",
  thresholds            = "thresholds",
  thr_loadings          = c("thresholds", "loadings"),
  thr_load_intercepts   = c("thresholds", "loadings", "intercepts"),
  thr_load_int_residual = c("thresholds", "loadings", "intercepts", "residuals")
)
fits <- lapply(steps, fit_step)
tab <- t(sapply(fits, function(f) fitMeasures(f, c("chisq.scaled", "df", "cfi.scaled", "cfi.robust", "rmsea.scaled", "rmsea.robust", "srmr"))))
cat("\n== (a) Adım adım uyum (WLSMV, theta) ==\n"); print(round(tab, 4))

cat("\n== (b) Wu–Estabrook önermesi: C ≥ 3 kategoride 'thresholds' modeli configural ile eşdeğer mi? ==\n")
cat(sprintf("configural: chisq(standard) = %.6f, df = %d\nthresholds: chisq(standard) = %.6f, df = %d\n",
            fitMeasures(fits$configural, "chisq"), as.integer(fitMeasures(fits$configural, "df")),
            fitMeasures(fits$thresholds, "chisq"), as.integer(fitMeasures(fits$thresholds, "df"))))

cat("\n== (c) Ardışık ölçeklenmiş fark testleri (lavTestLRT, satorra.2000) ==\n")
pairs <- list(c("configural", "thresholds"), c("thresholds", "thr_loadings"),
              c("configural", "thr_loadings"), c("thr_loadings", "thr_load_intercepts"),
              c("thr_load_intercepts", "thr_load_int_residual"))
for (p in pairs) {
  l <- lavTestLRT(fits[[p[1]]], fits[[p[2]]])
  cat(sprintf("%-22s -> %-22s Δχ²=%.3f Δdf=%d p=%.4g | ΔCFI.scaled=%.4f ΔCFI.robust=%.4f ΔRMSEA.scaled=%.4f\n",
              p[1], p[2], l[2, "Chisq diff"], as.integer(l[2, "Df diff"]), l[2, "Pr(>Chisq)"],
              tab[p[2], "cfi.scaled"] - tab[p[1], "cfi.scaled"],
              tab[p[2], "cfi.robust"] - tab[p[1], "cfi.robust"],
              tab[p[2], "rmsea.scaled"] - tab[p[1], "rmsea.scaled"]))
}

cat("\n== (b2) Aynı veri 3 kategoriye indirgenince (1-2 | 3-4 | 5-6) ==\n")
d3 <- d; d3[, items] <- lapply(d3[, items], function(v) ceiling(v / 2))
fit3 <- function(eq) {
  syn <- measEq.syntax(configural.model = m2, data = d3, ordered = items,
                       parameterization = "theta", ID.fac = "std.lv",
                       ID.cat = "Wu.Estabrook.2016", group = "gender", group.equal = eq)
  cfa(as.character(syn), data = d3, group = "gender", ordered = items,
      estimator = "WLSMV", parameterization = "theta")
}
c3 <- fit3("configural"); t3 <- fit3("thresholds")
cat(sprintf("C=3 configural: chisq = %.6f, df = %d\nC=3 thresholds: chisq = %.6f, df = %d\n",
            fitMeasures(c3, "chisq"), as.integer(fitMeasures(c3, "df")),
            fitMeasures(t3, "chisq"), as.integer(fitMeasures(t3, "df"))))

cat("\n== (d) Skor testi (lavTestScore) WLSMV modelinde çalışıyor mu? ==\n")
st <- tryCatch(lavTestScore(fits$thr_loadings), error = function(e) e)
if (inherits(st, "error")) cat("HATA:", conditionMessage(st), "\n") else {
  u <- st$uni; u <- u[order(-u$X2), ]
  cat("toplam (çok değişkenli) test:\n"); print(st$test)
  cat("en büyük 5 tek değişkenli test:\n"); print(head(u, 5), row.names = FALSE)
  pt <- parTable(fits$thr_loadings)
  lab <- function(plabel) { r <- pt[pt$plabel == plabel, ]; paste0(r$lhs, r$op, r$rhs, " [g", r$group, "]") }
  cat("ilk satırın okunur hâli:", lab(u$lhs[1]), "<->", lab(u$rhs[1]), "\n")
}

cat("\n== (e) Gizil ortalama farkı ve d: tanım seçimi sonucu değiştirir ==\n")
f <- fits$thr_load_intercepts
pe <- parameterEstimates(f)
kap <- pe[pe$op == "~1" & pe$lhs %in% c("Neu", "Con") & pe$group == 2, c("lhs", "est", "se", "z", "pvalue")]
psi <- pe[pe$op == "~~" & pe$lhs == pe$rhs & pe$lhs %in% c("Neu", "Con"), c("lhs", "group", "est")]
n <- as.numeric(table(d$gender))
for (fac in c("Neu", "Con")) {
  k <- kap$est[kap$lhs == fac]; v1 <- psi$est[psi$lhs == fac & psi$group == 1]; v2 <- psi$est[psi$lhs == fac & psi$group == 2]
  pooled <- sqrt(((n[1] - 1) * v1 + (n[2] - 1) * v2) / (sum(n) - 2))
  cat(sprintf("%s: kappa=%.4f  ψ1=%.4f ψ2=%.4f | d(ref SS)=%.4f  d(odak grup SS)=%.4f  d(birleşik SS, Hancock 2001)=%.4f\n",
              fac, k, v1, v2, k / sqrt(v1), k / sqrt(v2), k / pooled))
}
