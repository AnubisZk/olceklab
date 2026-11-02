# M7 — Güvenirlik ve geçerlik (SPEC §7 M7; SPEC_REVIEW REL-1, REL-2).
#
# ω (semTools::compRelSEM): ω = w'ΛΦΛ'w / w'Σ̂w. Pay modelden gelir (yükler ve faktör varyansı).
#   obs.var = TRUE  (semTools varsayılanı): payda gözlenen (doymuş model) kovaryans matrisinden;
#                   bileşik puanın gerçek varyansına oranıdır, model uyumsuzluğu paydaya yansır.
#   obs.var = FALSE: payda modelin örtük kovaryans matrisinden; hata kovaryansı yoksa McDonald'ın (1999)
#                   ω = (Σλ)²ψ / ((Σλ)²ψ + Σθ) formülüne (Raykov'un yapı güvenirliği, CR) eşittir.
#   Model veriye tam uyduğunda ikisi aynıdır; fark, modelin toplam puan varyansını ne kadar
#   yeniden ürettiğini gösterir. WLSMV'de ord.scale = TRUE: gözlenen sıralı toplam puanın güvenirliği
#   (Green ve Yang, 2009, formül 21).
# AVE (semTools::AVE): sıralı veride gizil yanıt (y*) ölçeğindedir.
# HTMT (semTools::htmt): varsayılan htmt2 = FALSE (aritmetik ortalama, Henseler vd., 2015), absolute = TRUE.

reliability_settings <- function(settings) {
  th <- if (is.list(settings$thresholds)) settings$thresholds else list()
  ht <- if (is.list(settings$htmt)) settings$htmt else list()
  list(
    estimator = setting_choice(settings, "estimator", cfa_estimators),
    obs_var = setting_flag(settings, "obs_var", TRUE),
    htmt2 = setting_flag(ht, "htmt2", FALSE),
    htmt_absolute = setting_flag(ht, "absolute", TRUE),
    htmt_correlation = setting_choice(ht, "correlation", c("pearson", "polychoric")),
    cr_min = setting_number(th, "cr", 0.70, 0, 1),
    ave_min = setting_number(th, "ave", 0.50, 0, 1),
    htmt_max = setting_number(th, "htmt", 0.85, 0, 1),
    seed = setting_number(settings, "seed", 20261030L, 1, .Machine$integer.max, integer = TRUE)
  )
}

# HTMT için yalnızca birinci düzey faktörlerin ölçme modeli.
reliability_htmt_syntax <- function(m) {
  fo <- Filter(function(f) f$name %in% m$first_order, m$factors)
  paste(vapply(fo, function(f) sprintf("%s =~ %s", f$name, paste(f$items, collapse = " + ")), ""), collapse = "\n")
}

reliability_calls <- function(fit, x, m, s) {
  omega <- quiet(semTools::compRelSEM(fit, obs.var = s$obs_var, ord.scale = TRUE, simplify = TRUE))
  ave <- quiet(semTools::AVE(fit, obs.var = s$obs_var))
  ht <- NULL
  if (length(m$first_order) >= 2L) {
    ht <- quiet(semTools::htmt(reliability_htmt_syntax(m), data = x, missing = "listwise",
                               ordered = if (s$htmt_correlation == "polychoric") as.character(m$observed) else NULL,
                               absolute = s$htmt_absolute, htmt2 = s$htmt2))
  }
  list(omega = stats::setNames(as.numeric(unclass(omega$value)), names(omega$value)),
       ave = stats::setNames(as.numeric(unclass(ave$value)), names(ave$value)),
       htmt = if (is.null(ht)) NULL else unclass(ht$value),
       warnings = unique(c(omega$warnings, ave$warnings, if (!is.null(ht)) ht$warnings)))
}

analysis_reliability <- function(data, config, settings, dataset_hash) {
  s <- reliability_settings(settings)
  cs <- list(estimator = s$estimator, likelihood = "normal", std_lv = FALSE, bootstrap = 0L, seed = s$seed, mi_top = 0L)
  m <- resolve_model(settings$model, config$items$name)
  if (s$htmt_correlation == "polychoric" && any(is.na(config$items$min[match(m$observed, config$items$name)]))) {
    api_stop("polychoric_needs_categories", "Polikorik HTMT için bütün maddelerde kategori aralığı tanımlanmalıdır.", 422L)
  }
  x <- data[, m$observed, drop = FALSE]
  cfa_check_data(x, config, m$observed, cs)
  args <- cfa_call_args(cs, m$observed)
  run <- with_seeded_rng(s$seed, {
    ft <- cfa_fit(m$syntax, x, args)
    list(ft = ft, rel = reliability_calls(ft$fit, x, m, s))
  })
  ft <- run$value$ft; rel <- run$value$rel; fit <- ft$fit

  fo <- Filter(function(f) f$name %in% m$first_order, m$factors)
  fnames <- vapply(fo, `[[`, "", "name")
  alpha_of <- function(items) {
    if (length(items) < 2L) return(NA_real_)
    quiet(psych::alpha(x[stats::complete.cases(x[, items, drop = FALSE]), items, drop = FALSE], check.keys = FALSE, warnings = FALSE))$value$total$raw_alpha
  }
  alphas <- vapply(fo, function(f) alpha_of(f$items), numeric(1))
  alpha_total <- alpha_of(m$observed)
  omega <- unname(rel$omega[fnames]); ave <- unname(rel$ave[fnames])
  std <- lavaan::lavInspect(fit, "std")
  psi <- std$psi[fnames, fnames, drop = FALSE]
  max_r <- vapply(fnames, function(f) if (length(fnames) > 1L) max(abs(psi[f, setdiff(fnames, f)])) else NA_real_, numeric(1))
  sqrt_ave <- sqrt(ave)

  yes_no <- function(v, lang) ifelse(is.na(v), FMT_MISSING, ifelse(v, if (lang == "tr") "Evet" else "Yes", if (lang == "tr") "Hayır" else "No"))
  r1_rows <- data.frame(factor = fnames, k = lengths(lapply(fo, `[[`, "items")), alpha = alphas, omega = omega, ave = ave,
                        sqrt_ave = sqrt_ave, max_r = unname(max_r),
                        cr_ok = omega >= s$cr_min, ave_ok = ave >= s$ave_min,
                        fl_ok = if (length(fnames) > 1L) sqrt_ave > unname(max_r) else NA,
                        stringsAsFactors = FALSE)
  r1_rows <- rbind(r1_rows, data.frame(factor = "Toplam", k = length(m$observed), alpha = alpha_total, omega = NA_real_, ave = NA_real_,
                                       sqrt_ave = NA_real_, max_r = NA_real_, cr_ok = NA, ave_ok = NA, fl_ok = NA, stringsAsFactors = FALSE))
  r1 <- make_table("T1", "Güvenirlik ve yakınsak geçerlik", "Reliability and convergent validity",
    list(tbl_col("factor", "Faktör", "Factor"), tbl_col("k", "Madde", "Items", "int"),
         tbl_col("alpha", "α", "α", "num", 3L, TRUE), tbl_col("omega", "ω", "ω", "num", 3L, TRUE),
         tbl_col("ave", "AVE", "AVE", "num", 3L, TRUE), tbl_col("sqrt_ave", "√AVE", "√AVE", "num", 3L, TRUE),
         tbl_col("max_r", "En yüksek |r|", "Max |r|", "num", 3L, TRUE),
         tbl_col("cr_ok", sprintf("ω ≥ %s", fmt_num(s$cr_min, 2, "tr", TRUE)), sprintf("ω ≥ %s", fmt_num(s$cr_min, 2, "en", TRUE))),
         tbl_col("ave_ok", sprintf("AVE ≥ %s", fmt_num(s$ave_min, 2, "tr", TRUE)), sprintf("AVE ≥ %s", fmt_num(s$ave_min, 2, "en", TRUE))),
         tbl_col("fl_ok", "√AVE > |r| (Fornell–Larcker)", "√AVE > |r| (Fornell–Larcker)")),
    r1_rows,
    note_tr = paste0(
      sprintf("Kaynak: psych::alpha; semTools::compRelSEM (obs.var = %s, ord.scale = TRUE), semTools::AVE (obs.var = %s); lavaan::cfa (estimator = '%s'); semTools %s. ",
              if (s$obs_var) "TRUE" else "FALSE", if (s$obs_var) "TRUE" else "FALSE", s$estimator, as.character(utils::packageVersion("semTools"))),
      if (s$obs_var) "ω'nın paydası gözlenen (doymuş model) toplam puan varyansıdır. " else "ω'nın paydası modelin örtük toplam puan varyansıdır; hata kovaryansı yoksa McDonald (1999) ω'sına eşittir. ",
      if (s$estimator == "WLSMV") "WLSMV'de ω gözlenen sıralı toplam puanın güvenirliğidir (Green ve Yang, 2009); AVE gizil yanıt (y*) ölçeğindedir. " else "",
      sprintf("Eşikler (ayarlanabilir): ω ≥ %s, AVE ≥ %s (Fornell ve Larcker, 1981). Toplam satırı bütün model maddelerinin alfasıdır.",
              fmt_num(s$cr_min, 2, "tr", TRUE), fmt_num(s$ave_min, 2, "tr", TRUE))),
    note_en = paste0(
      sprintf("Source: psych::alpha; semTools::compRelSEM (obs.var = %s, ord.scale = TRUE), semTools::AVE (obs.var = %s); lavaan::cfa (estimator = '%s'); semTools %s. ",
              if (s$obs_var) "TRUE" else "FALSE", if (s$obs_var) "TRUE" else "FALSE", s$estimator, as.character(utils::packageVersion("semTools"))),
      if (s$obs_var) "The denominator of ω is the observed (saturated-model) total-score variance. " else "The denominator of ω is the model-implied total-score variance; without error covariances it equals McDonald's (1999) ω. ",
      if (s$estimator == "WLSMV") "Under WLSMV ω is the reliability of the observed ordinal sum score (Green & Yang, 2009); AVE is on the latent-response (y*) scale. " else "",
      sprintf("Thresholds (adjustable): ω ≥ %s, AVE ≥ %s (Fornell & Larcker, 1981). The total row is alpha for all model items.",
              fmt_num(s$cr_min, 2, "en", TRUE), fmt_num(s$ave_min, 2, "en", TRUE))))
  for (lang in c("tr", "en")) {
    for (k in c("cr_ok", "ave_ok", "fl_ok")) r1$rows_fmt[[lang]][[k]] <- yes_no(r1_rows[[k]], lang)
    r1$rows_fmt[[lang]]$factor[nrow(r1_rows)] <- if (lang == "tr") "Toplam (bütün maddeler)" else "Total (all items)"
  }
  tables <- list(r1)

  htmt_mat <- NULL; htmt_flags <- NULL
  if (!is.null(rel$htmt)) {
    htmt_mat <- rel$htmt[fnames, fnames, drop = FALSE]
    rows <- data.frame(factor = fnames, htmt_mat, check.names = FALSE, stringsAsFactors = FALSE)
    rownames(rows) <- NULL
    r2 <- make_table("T2", "HTMT oranları (ayırt edici geçerlik)", "HTMT ratios (discriminant validity)",
      c(list(tbl_col("factor", "Faktör", "Factor")), lapply(fnames, function(f) tbl_col(f, f, f, "num", 3L, TRUE))),
      rows,
      note_tr = sprintf("Kaynak: semTools::htmt (htmt2 = %s, absolute = %s, korelasyon: %s). Eşik: %s (Henseler vd., 2015; ayarlanabilir). Ters maddeler temizlemede yeniden kodlanmış olmalıdır; aksi hâlde absolute = FALSE ile sonuç tanımsız olabilir.",
                        if (s$htmt2) "TRUE" else "FALSE", if (s$htmt_absolute) "TRUE" else "FALSE",
                        if (s$htmt_correlation == "pearson") "Pearson" else "polikorik", fmt_num(s$htmt_max, 2, "tr", TRUE)),
      note_en = sprintf("Source: semTools::htmt (htmt2 = %s, absolute = %s, correlation: %s). Threshold: %s (Henseler et al., 2015; adjustable). Reverse-keyed items must be recoded during cleaning; otherwise the result can be undefined with absolute = FALSE.",
                        if (s$htmt2) "TRUE" else "FALSE", if (s$htmt_absolute) "TRUE" else "FALSE",
                        s$htmt_correlation, fmt_num(s$htmt_max, 2, "en", TRUE)))
    for (lang in c("tr", "en")) for (j in seq_along(fnames)) for (i in seq_len(j)) r2$rows_fmt[[lang]][i, fnames[j]] <- ""
    htmt_flags <- lapply(stats::setNames(fnames, fnames), function(f) I(as.vector(!is.na(htmt_mat[f, ]) & htmt_mat[f, ] > s$htmt_max & fnames != f)))
    tables[[length(tables) + 1L]] <- r2

    fl <- psi
    diag(fl) <- sqrt_ave
    rows <- data.frame(factor = fnames, fl, check.names = FALSE, stringsAsFactors = FALSE)
    rownames(rows) <- NULL
    r3 <- make_table("T3", "Fornell–Larcker ölçütü", "Fornell–Larcker criterion",
      c(list(tbl_col("factor", "Faktör", "Factor")), lapply(fnames, function(f) tbl_col(f, f, f, "num", 3L, TRUE))),
      rows,
      note_tr = "Köşegen: √AVE; köşegen altı: faktörler arası korelasyonlar (lavInspect(fit, 'std')$psi). Ölçüt: √AVE, ilgili korelasyonların mutlak değerinden büyük olmalıdır (Fornell ve Larcker, 1981).",
      note_en = "Diagonal: √AVE; below the diagonal: factor correlations (lavInspect(fit, 'std')$psi). Criterion: √AVE should exceed the absolute value of the related correlations (Fornell & Larcker, 1981).")
    for (lang in c("tr", "en")) for (j in seq_along(fnames)) for (i in seq_len(j - 1L)) r3$rows_fmt[[lang]][i, fnames[j]] <- ""
    tables[[length(tables) + 1L]] <- r3
  }

  warns <- m$warnings
  low_cr <- fnames[!is.na(omega) & omega < s$cr_min]
  if (length(low_cr)) warns[[length(warns) + 1L]] <- warning_item("low_omega",
    sprintf("ω değeri %s altında: %s.", fmt_num(s$cr_min, 2, "tr", TRUE), paste(low_cr, collapse = ", ")),
    sprintf("ω below %s: %s.", fmt_num(s$cr_min, 2, "en", TRUE), paste(low_cr, collapse = ", ")))
  if (!is.null(htmt_mat)) {
    hi <- character()
    for (j in seq_along(fnames)) for (i in seq_len(j - 1L)) if (isTRUE(htmt_mat[fnames[i], fnames[j]] > s$htmt_max)) hi <- c(hi, paste(fnames[i], fnames[j], sep = "–"))
    if (length(hi)) warns[[length(warns) + 1L]] <- warning_item("high_htmt",
      sprintf("HTMT %s üstünde: %s. Ayırt edici geçerlik sorgulanabilir.", fmt_num(s$htmt_max, 2, "tr", TRUE), paste(hi, collapse = ", ")),
      sprintf("HTMT above %s: %s. Discriminant validity may be questionable.", fmt_num(s$htmt_max, 2, "en", TRUE), paste(hi, collapse = ", ")))
    if (!s$htmt_absolute && any(!is.finite(htmt_mat))) warns[[length(warns) + 1L]] <- warning_item("htmt_undefined",
      "Bazı HTMT değerleri tanımsız (NaN). Negatif korelasyonlar olabilir; ters maddelerin yeniden kodlandığını denetleyin ya da absolute = TRUE kullanın.",
      "Some HTMT values are undefined (NaN). There may be negative correlations; check that reverse-keyed items are recoded or use absolute = TRUE.")
  }
  if (any(!is.na(r1_rows$fl_ok) & !r1_rows$fl_ok)) warns[[length(warns) + 1L]] <- warning_item("fornell_larcker",
    sprintf("Fornell–Larcker ölçütü sağlanmıyor: %s.", paste(r1_rows$factor[!is.na(r1_rows$fl_ok) & !r1_rows$fl_ok], collapse = ", ")),
    sprintf("Fornell–Larcker criterion not met: %s.", paste(r1_rows$factor[!is.na(r1_rows$fl_ok) & !r1_rows$fl_ok], collapse = ", ")))
  warns <- c(warns, cfa_lavaan_warnings(c(ft$warnings, rel$warnings)))

  make_record(
    module = "reliability", dataset_hash = dataset_hash,
    settings = list(model = model_record(m), estimator = s$estimator, obs_var = s$obs_var, ord_scale = TRUE,
                    htmt = list(htmt2 = s$htmt2, absolute = s$htmt_absolute, correlation = s$htmt_correlation),
                    thresholds = list(cr = s$cr_min, ave = s$ave_min, htmt = s$htmt_max), items = I(m$observed), lavaan_args = args),
    seed = s$seed, rng = run$rng,
    results = list(n = lavaan::lavInspect(fit, "nobs"), factors = I(fnames),
                   alpha = as.list(stats::setNames(alphas, fnames)), alpha_total = alpha_total,
                   omega = as.list(stats::setNames(omega, fnames)), ave = as.list(stats::setNames(ave, fnames)),
                   factor_correlations = lapply(stats::setNames(fnames, fnames), function(f) as.list(psi[f, ])),
                   htmt = if (is.null(htmt_mat)) NULL else lapply(stats::setNames(fnames, fnames), function(f) as.list(htmt_mat[f, ])),
                   htmt_flags = htmt_flags),
    tables = tables, warnings = warns
  )
}
