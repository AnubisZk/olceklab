# BİDEKÇET (SPEC §11.3) test düzeneği. Gerçek veri yalnızca belge sahibinin makinesinde,
# BIDEKCET_DATA_DIR ortam değişkeninin gösterdiği klasördedir; depoya girmez (KVKK).
# Aynı düzenek CI'da sentetik, aynı düzende dosyalarla da çalıştırılır (test-bidekcet-harness.R).
#
# Dosya düzeni (CODEX_YANIT_FAZ1.md, madde 3):
#   ortaokul: cinsiyet, sınıf, M1–M13      — sınıfı boş satırlar çıkarılır
#   lise:     Cinsiyet, Sinif, Madde1–Madde13 — Sinif ∉ {9, 10, 11, 12} satırlar çıkarılır
# Dosyalar başlıklarına bakılarak bulunur; dosya adları depoda yazılı değildir. İstenirse
# BIDEKCET_ORTAOKUL_FILE ve BIDEKCET_LISE_FILE ile açıkça verilebilir.

bidekcet_levels <- c("ortaokul", "lise")
bidekcet_k <- c(1:6, 8:13)  # M7 analiz dışıdır

bidekcet_item <- function(level, k) if (level == "ortaokul") paste0("M", k) else paste0("Madde", k)

# §11.3 modelleri (referans betiğiyle aynı faktör ve madde sırası).
bidekcet_m4 <- list(BK = c(4, 5, 6, 8), FM = c(1, 2, 3), KD = c(9, 11), CT = c(10, 12, 13))
bidekcet_m1 <- list(BK = c(1, 2, 3, 4, 5, 6, 8), CT = c(10, 12, 13), KD = c(9, 11))

bidekcet_model <- function(level, def) {
  list(factors = lapply(names(def), function(f) list(name = f, items = bidekcet_item(level, def[[f]]))))
}

bidekcet_header <- function(path) {
  ext <- tolower(tools::file_ext(path))
  nm <- if (ext %in% c("xlsx", "xls")) names(readxl::read_excel(path, n_max = 0)) else names(utils::read.csv(path, nrows = 1, check.names = FALSE))
  trimws(nm)
}

bidekcet_locate <- function(dir) {
  explicit <- c(ortaokul = Sys.getenv("BIDEKCET_ORTAOKUL_FILE"), lise = Sys.getenv("BIDEKCET_LISE_FILE"))
  out <- list()
  files <- list.files(dir, pattern = "\\.(xlsx|xls|csv)$", full.names = TRUE, ignore.case = TRUE)
  for (lv in bidekcet_levels) {
    if (nzchar(explicit[[lv]])) {
      p <- if (file.exists(explicit[[lv]])) explicit[[lv]] else file.path(dir, explicit[[lv]])
      if (!file.exists(p)) stop(sprintf("%s dosyası bulunamadı: %s", lv, explicit[[lv]]))
      out[[lv]] <- p
      next
    }
    hits <- Filter(function(f) {
      h <- bidekcet_header(f)
      if (lv == "ortaokul") all(paste0("M", bidekcet_k) %in% h) && any(grepl("^s.n.f$", h, ignore.case = TRUE))
      else all(paste0("Madde", bidekcet_k) %in% h) && "Sinif" %in% h
    }, files)
    if (length(hits) != 1L) stop(sprintf("%s dosyası başlıklardan bulunamadı (%d aday). BIDEKCET_%s_FILE ile belirtin.", lv, length(hits), toupper(lv)))
    out[[lv]] <- hits[[1]]
  }
  out
}

# Platformun kendi fonksiyonlarıyla (yükleme → roller → temizleme → analizler) bir kademeyi çalıştırır.
bidekcet_platform_level <- function(path, level, pa_seed = 1L, pa_iter = 1000L) {
  up <- parse_upload(readBin(path, "raw", file.size(path)), basename(path))
  df <- up$data
  class_col <- if (level == "ortaokul") names(df)[grepl("^s.n.f$", names(df), ignore.case = TRUE)] else "Sinif"
  items <- bidekcet_item(level, bidekcet_k)
  roles <- stats::setNames(as.list(rep("ignore", ncol(df))), names(df))
  roles[items] <- "item"
  roles[[class_col]] <- "group"
  body <- list(roles = roles, items = lapply(stats::setNames(items, items), function(i) list(min = 1, max = 5)),
               group_valid_values = if (level == "lise") c("9", "10", "11", "12") else NULL)
  cfg <- build_config(df, body)
  cl <- analysis_clean(df, cfg, list(), up$hash)$clean
  d <- cl$data
  m4 <- bidekcet_model(level, bidekcet_m4)
  m1 <- bidekcet_model(level, bidekcet_m1)
  item <- analysis_item(d, cfg, list(), up$hash)
  suit <- analysis_suitability(d, cfg, list(correlation = "pearson"), up$hash)
  pa <- analysis_factor_number(d, cfg, list(extraction = "pc", n_iter = pa_iter, seed = pa_seed), up$hash)
  ml <- list(estimator = "ML", likelihood = "wishart", mi_top = 0L)
  f4 <- analysis_cfa(d, cfg, c(ml, list(model = m4)), up$hash)
  f1 <- analysis_cfa(d, cfg, c(ml, list(model = m1)), up$hash)
  cmp <- analysis_cfa_compare(d, cfg, c(ml, list(models = list(list(name = "Model 4", model = m4), list(name = "Model 1", model = m1)))), up$hash)
  tst <- Filter(function(t) t$restricted == "Model 1" && t$reference == "Model 4", cmp$results$tests)
  rel_abs <- analysis_reliability(d, cfg, list(model = m4), up$hash)
  rel_raw <- analysis_reliability(d, cfg, list(model = m4, htmt = list(absolute = FALSE)), up$hash)
  wl <- analysis_cfa(d, cfg, list(model = m4, estimator = "WLSMV", std_lv = TRUE, mi_top = 0L), up$hash)
  list(
    n_raw = cl$n_raw, n_final = cl$n_final,
    remaining = stats::setNames(cl$steps$remaining, cl$steps$step),
    removed = stats::setNames(cl$steps$removed, cl$steps$step),
    alpha = item$results$alpha, kmo = suit$results$kmo, pa_pc = as.integer(pa$results$pc$suggested),
    m4_chisq = f4$results$fit$chisq, m4_df = f4$results$fit$df,
    m1_chisq = f1$results$fit$chisq, m1_df = f1$results$fit$df,
    dchisq = if (length(tst)) tst[[1]]$chisq_diff else NA_real_, ddf = if (length(tst)) tst[[1]]$df_diff else NA_real_,
    htmt_abs = rel_abs$results$htmt, htmt_raw = rel_raw$results$htmt,
    wlsmv = wl$results$fit[c("cfi_scaled", "cfi_robust", "rmsea_scaled", "rmsea_robust")],
    data = d
  )
}

bidekcet_platform <- function(files, ...) {
  lapply(stats::setNames(bidekcet_levels, bidekcet_levels), function(lv) bidekcet_platform_level(files[[lv]], lv, ...))
}

# Raporlandıkları basamakta karşılaştırma: |x − ref| ≤ 0,5 × 10⁻ᵈ (SPEC §11.1, REP-2).
at_reported_precision <- function(got, ref, digits) isTRUE(abs(got - ref) <= 0.5 * 10^(-digits) + 1e-12)
