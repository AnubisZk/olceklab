# SPEC §11.3 — BİDEKÇET regresyon testleri. Yalnızca belge sahibinin makinesinde çalışır:
#   BIDEKCET_DATA_DIR=/veri/klasoru LANG=C.UTF-8 Rscript tests/testthat.R
# ya da yalnızca bu dosya için:  BIDEKCET_DATA_DIR=... Rscript tests/private/run_bidekcet.R
# Veri depoya girmez (KVKK). Beklenen değerler SPEC §11.3'ten (v1.2) alınmıştır ve raporlandıkları
# basamakta karşılaştırılır (SPEC §11.1, REP-2).

spec_113 <- list(
  ortaokul = list(n_raw = 255L, remaining = c(invalid_group = 253L, missing = 253L, out_of_range = 253L, straightline = 250L),
                  alpha = 0.794, kmo = 0.805, pa_pc = 2L,
                  m4_chisq = 147.844, m4_df = 48, m1_chisq = 179.058, m1_df = 51, dchisq = 31.21, ddf = 3,
                  htmt_bk_fm = 0.773, htmt_bk_ct_abs = 0.451, htmt_bk_ct_raw = 0.412,
                  cfi_scaled = 0.908, cfi_robust = 0.829, rmsea_scaled = 0.096, rmsea_robust = 0.113),
  lise = list(n_raw = 279L, remaining = c(invalid_group = 277L, missing = 272L, out_of_range = 272L, straightline = 256L),
              alpha = 0.836, kmo = 0.821, pa_pc = 2L,
              m4_chisq = 133.325, m4_df = 48, m1_chisq = 178.149, m1_df = 51, dchisq = 44.82, ddf = 3,
              cfi_scaled = 0.931, cfi_robust = 0.875, rmsea_scaled = 0.094, rmsea_robust = 0.106)
)

data_dir <- Sys.getenv("BIDEKCET_DATA_DIR")

test_that("§11.3 BİDEKÇET: temizleme, alfa, KMO, paralel analiz, DFA, HTMT ve WLSMV (Faz 1–2 satırları)", {
  skip_if(!nzchar(data_dir), "BIDEKCET_DATA_DIR tanımlı değil; KVKK gereği veri depoda değil (SPEC §11.3)")
  skip_if(!dir.exists(data_dir), sprintf("BIDEKCET_DATA_DIR klasörü yok: %s", data_dir))
  files <- bidekcet_locate(data_dir)
  got <- bidekcet_platform(files)
  report <- list()
  chk <- function(level, what, value, ref, digits = NULL) {
    ok <- if (is.null(digits)) identical(value, ref) else at_reported_precision(value, ref, digits)
    report[[length(report) + 1L]] <<- data.frame(kademe = level, olcut = what, beklenen = format(ref), elde = format(value, digits = 10), sonuc = if (ok) "AYNI" else "FARKLI")
    expect_true(ok, info = sprintf("%s %s: beklenen %s, elde edilen %s", level, what, format(ref), format(value, digits = 10)))
  }
  for (lv in bidekcet_levels) {
    g <- got[[lv]]; r <- spec_113[[lv]]
    chk(lv, "ham satır", g$n_raw, r$n_raw)
    for (st in names(r$remaining)) chk(lv, paste("kalan:", st), unname(g$remaining[[st]]), unname(r$remaining[[st]]))
    chk(lv, "alfa", g$alpha, r$alpha, 3)
    chk(lv, "KMO", g$kmo, r$kmo, 3)
    chk(lv, "paralel analiz (pc)", g$pa_pc, r$pa_pc)
    chk(lv, "Model 4 χ² (wishart)", g$m4_chisq, r$m4_chisq, 3)
    chk(lv, "Model 4 sd", g$m4_df, r$m4_df, 0)
    chk(lv, "Model 1 χ² (wishart)", g$m1_chisq, r$m1_chisq, 3)
    chk(lv, "Model 1 sd", g$m1_df, r$m1_df, 0)
    chk(lv, "Δχ² Model 1 – Model 4", g$dchisq, r$dchisq, 2)
    chk(lv, "Δsd", g$ddf, r$ddf, 0)
    chk(lv, "WLSMV cfi.scaled", g$wlsmv$cfi_scaled, r$cfi_scaled, 3)
    chk(lv, "WLSMV cfi.robust", g$wlsmv$cfi_robust, r$cfi_robust, 3)
    chk(lv, "WLSMV rmsea.scaled", g$wlsmv$rmsea_scaled, r$rmsea_scaled, 3)
    chk(lv, "WLSMV rmsea.robust", g$wlsmv$rmsea_robust, r$rmsea_robust, 3)
  }
  o <- got$ortaokul; r <- spec_113$ortaokul
  chk("ortaokul", "HTMT BK–FM (absolute = TRUE)", o$htmt_abs$BK$FM, r$htmt_bk_fm, 3)
  chk("ortaokul", "HTMT BK–FM (absolute = FALSE)", o$htmt_raw$BK$FM, r$htmt_bk_fm, 3)
  chk("ortaokul", "HTMT BK–CT (absolute = TRUE)", o$htmt_abs$BK$CT, r$htmt_bk_ct_abs, 3)
  chk("ortaokul", "HTMT BK–CT (absolute = FALSE)", o$htmt_raw$BK$CT, r$htmt_bk_ct_raw, 3)
  out <- Sys.getenv("BIDEKCET_REPORT")
  if (nzchar(out)) utils::write.csv(do.call(rbind, report), out, row.names = FALSE, fileEncoding = "UTF-8")
})

spec_113_inv <- list(
  chisq = c(configural = 281.168, metric = 299.621, scalar = 319.77), chisq_digits = c(3, 3, 2),
  df = c(configural = 96, metric = 104, scalar = 112),
  srmr_bn = c(configural = 0.0626, metric = 0.0710, scalar = 0.0713),
  srmr = c(configural = 0.0583, metric = 0.0661, scalar = 0.0683),
  partial_metric = list(dchisq = 3.64, ddf = 7, p = 0.821),
  partial_scalar = list(dchisq = 11.80, ddf = 7, p = 0.107)
)

test_that("§11.3 BİDEKÇET: ölçme değişmezliği ve kısmi değişmezlik (Faz 3 satırları)", {
  skip_if(!nzchar(data_dir), "BIDEKCET_DATA_DIR tanımlı değil; KVKK gereği veri depoda değil (SPEC §11.3)")
  skip_if(!dir.exists(data_dir), sprintf("BIDEKCET_DATA_DIR klasörü yok: %s", data_dir))
  inv <- bidekcet_platform_invariance(bidekcet_platform(bidekcet_locate(data_dir), pa_iter = 20L))
  report <- list()
  chk <- function(what, value, ref, digits) {
    ok <- at_reported_precision(value, ref, digits)
    report[[length(report) + 1L]] <<- data.frame(kademe = "birleşik", olcut = what, beklenen = format(ref), elde = format(value, digits = 10), sonuc = if (ok) "AYNI" else "FARKLI")
    expect_true(ok, info = sprintf("%s: beklenen %s, elde edilen %s", what, format(ref), format(value, digits = 10)))
  }
  r <- spec_113_inv
  for (k in seq_along(r$chisq)) {
    st <- names(r$chisq)[k]
    chk(paste(st, "χ²"), inv$full$fit[[st]]$chisq, r$chisq[[k]], r$chisq_digits[[k]])
    chk(paste(st, "sd"), inv$full$fit[[st]]$df, r$df[[st]], 0)
    chk(paste(st, "SRMR (bentler_nomean)"), inv$full$fit[[st]]$srmr_bentler_nomean, r$srmr_bn[[st]], 4)
    chk(paste(st, "SRMR (lavaan)"), inv$full$fit[[st]]$srmr, r$srmr[[st]], 4)
  }
  cm <- inv$partial$comparisons
  chk("kısmi metrik Δχ²", cm$chisq_diff[1], r$partial_metric$dchisq, 2)
  chk("kısmi metrik Δsd", cm$df_diff[1], r$partial_metric$ddf, 0)
  chk("kısmi metrik p", cm$p[1], r$partial_metric$p, 3)
  chk("kısmi skaler Δχ²", cm$chisq_diff[2], r$partial_scalar$dchisq, 2)
  chk("kısmi skaler Δsd", cm$df_diff[2], r$partial_scalar$ddf, 0)
  chk("kısmi skaler p", cm$p[2], r$partial_scalar$p, 3)
  out <- Sys.getenv("BIDEKCET_REPORT")
  if (nzchar(out)) {
    prev <- if (file.exists(out)) utils::read.csv(out, fileEncoding = "UTF-8") else NULL
    utils::write.csv(rbind(prev, do.call(rbind, report)), out, row.names = FALSE, fileEncoding = "UTF-8")
  }
})
