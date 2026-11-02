# Sentetik, BİDEKÇET biçimli test verisi üretir (gerçek veri DEĞİLDİR).
# Amaç: gizli §11.3 test düzeneğinin ve belge sahibinin referans betiğinin aynı dosyalar
# üzerinde aynı sonuçları verdiğini, gerçek veriye dokunmadan, CI'da sınamak.
# Dosya düzeni belge sahibinin tarifine göredir (CODEX_YANIT_FAZ1.md, madde 3):
#   ortaokul: cinsiyet, sınıf, M1–M13; tamamen boş satırlar var (sınıf boş)
#   lise:     Cinsiyet, Sinif, Madde1–Madde13; bazı adların sonunda boşluk var; geçersiz sınıf değerleri var
# Çalıştırma: Rscript make_fixtures.R  →  ortaokul.csv, lise.csv; ardından python3 make_xlsx.py
suppressPackageStartupMessages(library(lavaan))
pop <- "
BK =~ .70*M4 + .65*M5 + .75*M6 + .60*M8
FM =~ .70*M1 + .60*M2 + .65*M3
KD =~ .70*M9 + .75*M11
CT =~ .60*M10 + .70*M12 + .65*M13
BK ~~ .75*FM + .45*KD + .40*CT
FM ~~ .40*KD + .35*CT
KD ~~ .55*CT
"
items <- paste0("M", c(1:6, 8:13))
to_cat <- function(z, shift) as.integer(cut(z + shift, c(-Inf, -1.4, -0.5, 0.4, 1.3, Inf)))
make_level <- function(n, seed) {
  set.seed(seed)
  z <- simulateData(pop, sample.nobs = n, seed = seed, standardized = TRUE)
  shifts <- seq(-0.3, 0.3, length.out = length(items))
  out <- as.data.frame(lapply(seq_along(items), function(k) to_cat(z[[items[k]]], shifts[k])))
  names(out) <- items
  out$M7 <- sample(1:5, n, TRUE)
  out[, paste0("M", 1:13)]
}
set.seed(20261103)
o <- make_level(176, 101)
o <- cbind(cinsiyet = sample(c("K", "E"), nrow(o), TRUE), sinif = sample(5:8, nrow(o), TRUE), o)
o[c(10, 50, 90, 130), items] <- matrix(rep(c(3, 5, 1, 4), each = length(items)), nrow = 4, byrow = TRUE)  # düz yanıt (M7 farklı)
o$M7[c(10, 50)] <- c(1, 2)
o$M3[20] <- NA                                  # eksik
o$M12[30] <- 6                                  # aralık dışı
o$M7[40] <- NA                                  # M7 eksik: analiz dışı madde, satır silinmemeli
blank <- o[1:2, ]; blank[] <- NA                # tamamen boş satırlar
o <- rbind(o[1:60, ], blank[1, ], o[61:120, ], blank[2, ], o[121:nrow(o), ])
rownames(o) <- NULL
l <- make_level(196, 202)
l <- cbind(Cinsiyet = sample(c("Kız", "Erkek"), nrow(l), TRUE), Sinif = sample(9:12, nrow(l), TRUE), l)
l$Sinif[c(5, 77)] <- c(4L, 7L)                  # geçersiz sınıf
l$Sinif[150] <- 13L
l[c(12, 33), "M5"] <- NA; l[c(44, 55), "M10"] <- NA  # eksik
l$M2[66] <- 0                                   # aralık dışı
sl <- c(15, 25, 35, 45, 85, 95, 105, 115, 125, 135)
l[sl, items] <- matrix(rep(rep(1:5, 2), each = length(items)), nrow = length(sl), byrow = TRUE)
l$M9[60] <- NA; l$M11[60] <- 7                # hem eksik hem aralık dışı: "eksik" adımında sayılır
names(l) <- c("Cinsiyet", "Sinif", paste0("Madde", 1:13))
write.csv(o, "ortaokul.csv", row.names = FALSE, na = "")
write.csv(l, "lise.csv", row.names = FALSE, na = "")
cat("ortaokul satır:", nrow(o), " lise satır:", nrow(l), "\n")
