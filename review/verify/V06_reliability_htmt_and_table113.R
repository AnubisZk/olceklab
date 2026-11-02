# V06 — semTools güvenirlik/geçerlik varsayılanları ve SPEC §11.3 tablosunun iç tutarlılığı
suppressPackageStartupMessages({ library(lavaan); library(semTools); library(psych) })
cat("R:", R.version.string, "| lavaan:", as.character(packageVersion("lavaan")),
    "| semTools:", as.character(packageVersion("semTools")), "| psych:", as.character(packageVersion("psych")), "\n\n")

cat("== (a) Varsayılan argümanlar ==\n")
show_f <- function(fn, args) { f <- formals(fn); cat(sprintf("%s: %s\n", deparse(substitute(fn)),
  paste(sprintf("%s = %s", args, sapply(args, function(a) paste(deparse(f[[a]]), collapse = ""))), collapse = "; "))) }
show_f(semTools::htmt, c("absolute", "htmt2", "ordered"))
show_f(semTools::compRelSEM, c("obs.var", "tau.eq", "ord.scale", "return.total"))
show_f(semTools::AVE, c("obs.var", "omit.imps", "omit.factors"))

cat("\n== (b) HTMT: htmt2 ve absolute seçimi sonucu değiştirir mi? (bfi, Pearson ve polikorik) ==\n")
data(bfi, package = "psych")
items <- c(paste0("N", 1:5), paste0("C", 1:5)); d <- na.omit(bfi[, items])
m2 <- "Neu =~ N1 + N2 + N3 + N4 + N5\nCon =~ C1 + C2 + C3 + C4 + C5"   # C4, C5 ters madde, YENİDEN KODLANMADI
for (h2 in c(TRUE, FALSE)) for (ab in c(TRUE, FALSE)) {
  v <- htmt(m2, data = d, htmt2 = h2, absolute = ab)[2, 1]
  vp <- htmt(m2, data = d, htmt2 = h2, absolute = ab, ordered = items)[2, 1]
  cat(sprintf("htmt2 = %-5s absolute = %-5s -> HTMT(Neu,Con) Pearson = %.3f | polikorik = %.3f\n", h2, ab, v, vp))
}

cat("\n== (c) compRelSEM: sürekli vs sıralı ölçek (ord.scale) ==\n"); cat("compRelSEM dönüş sınıfı (0.5-10):", class(compRelSEM(cfa(m2, d, std.lv = TRUE))), "\n")
d2 <- d; d2[, c("C4", "C5")] <- 7 - d2[, c("C4", "C5")]
fw <- cfa(m2, d2, ordered = items, estimator = "WLSMV", std.lv = TRUE)
print(round(rbind(ord.scale_TRUE = unlist(compRelSEM(fw, ord.scale = TRUE)), ord.scale_FALSE = unlist(compRelSEM(fw, ord.scale = FALSE))), 4))
fm <- cfa(m2, d2, std.lv = TRUE)
print(round(rbind(ML_obs.var_TRUE = unlist(compRelSEM(fm, obs.var = TRUE)), ML_obs.var_FALSE = unlist(compRelSEM(fm, obs.var = FALSE))), 4))

cat("\n== (d) SPEC §11.3 tablosunun aritmetik tutarlılığı (yalnızca belgede yazan sayılarla) ==\n")
chk <- function(lbl, ok) cat(sprintf("[%s] %s\n", if (ok) "TUTARLI" else "TUTARSIZ", lbl))
chk(sprintf("Ortaokul Δχ² = 179.058 − 147.844 = %.3f (belge 31.21)", 179.058 - 147.844), abs(179.058 - 147.844 - 31.21) < .01)
chk(sprintf("Lise Δχ² = 178.149 − 133.325 = %.3f (belge 44.82)", 178.149 - 133.325), abs(178.149 - 133.325 - 44.82) < .01)
chk(sprintf("Biçimsel χ² ≈ Ortaokul M4 + Lise M4 = %.3f (belge 281.168; yuvarlama payı ±.001)", 147.844 + 133.325), abs(147.844 + 133.325 - 281.168) <= .0015)
chk("Biçimsel sd = 48 + 48 = 96", 48 + 48 == 96)
chk("Metrik sd: 96 + (12 yük − 4 serbest gizil varyans) = 104", 96 + 12 - 4 == 104)
chk("Skaler sd: 104 + (12 kesişim − 4 serbest gizil ortalama) = 112", 104 + 12 - 4 == 112)
chk("Kısmi metrik: 1 yük serbest -> biçimselle Δsd = 7", 104 - 1 - 96 == 7)
chk(sprintf("Kısmi metrik p: pchisq(3.64, 7) üst kuyruk = %.3f (belge .821)", pchisq(3.64, 7, lower.tail = FALSE)), abs(pchisq(3.64, 7, lower.tail = FALSE) - .821) < .0015)
chk(sprintf("Kısmi skaler p: pchisq(11.80, 7) üst kuyruk = %.3f (belge .107)", pchisq(11.80, 7, lower.tail = FALSE)), abs(pchisq(11.80, 7, lower.tail = FALSE) - .107) < .0015)
cat(sprintf("Bilgi: tam metrik Δχ²(8) = %.3f, p = %.4f ; tam skaler (metrikle) Δχ²(8) = %.3f, p = %.4f\n",
            299.621 - 281.168, pchisq(299.621 - 281.168, 8, lower.tail = FALSE),
            319.77 - 299.621, pchisq(319.77 - 299.621, 8, lower.tail = FALSE)))
cat("Bilgi: KD faktörü 2 göstergeli (M9, M11); CT'de M10 yükü serbest bırakılınca CT 2 kısıtlı göstergeyle kalır.\n")
