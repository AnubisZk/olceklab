# M5 — Açımlayıcı faktör analizi (SPEC §7 M5; SPEC_REVIEW EFA-1, EFA-2).
# Hesap psych::fa ile yapılır. psych 2.6.9'da fa() varsayılan olarak n.rotations = 20 rastgele
# başlangıçla döndürür; bu yüzden çağrı sabit RNG türü ve tohumla yapılır, ikisi de kayda yazılır.

efa_fm_choices <- c("minres", "ml", "pa", "uls")
efa_rotate_choices <- c("oblimin", "promax", "geominQ", "varimax", "none")
efa_oblique <- c("oblimin", "promax", "geominQ")

efa_settings <- function(settings, p) {
  list(
    nfactors = setting_number(settings, "nfactors", 1L, 1, p - 1, integer = TRUE),
    fm = setting_choice(settings, "fm", efa_fm_choices),
    rotate = setting_choice(settings, "rotate", efa_rotate_choices),
    correlation = setting_choice(settings, "correlation", c("pearson", "polychoric")),
    n_rotations = setting_number(settings, "n_rotations", 20L, 1, 1000, integer = TRUE),
    threshold = setting_number(settings, "threshold", 0.30, 0, 1),
    seed = setting_number(settings, "seed", 20261030L, 1, .Machine$integer.max, integer = TRUE)
  )
}

# psych::fa çağrısı — betik dışa aktarımında da aynı argümanlar kullanılır.
efa_call <- function(x, s) {
  psych::fa(x, nfactors = s$nfactors, fm = s$fm, rotate = s$rotate,
            cor = if (s$correlation == "pearson") "cor" else "poly", correct = 0.5,
            n.rotations = s$n_rotations, scores = "none", warnings = TRUE)
}

efa_df <- function(p, k) ((p - k)^2 - (p + k)) / 2
efa_heywood_h2 <- 0.995

analysis_efa <- function(data, config, settings, dataset_hash) {
  items <- config$items$name
  x <- data[, items, drop = FALSE]
  p <- length(items)
  if (p < 3L) api_stop("too_few_items", "AFA için en az üç madde gerekir.", 422L)
  if (nrow(x) <= p) api_stop("too_few_rows", "AFA için gözlem sayısı madde sayısından büyük olmalıdır.", 422L)
  s <- efa_settings(settings, p)
  if (s$correlation == "polychoric" && any(is.na(config$items$min))) {
    api_stop("polychoric_needs_categories", "Polikorik korelasyon için bütün maddelerde kategori aralığı tanımlanmalıdır.", 422L)
  }
  run <- with_seeded_rng(s$seed, tryCatch(quiet(efa_call(x, s)), error = function(e) {
    api_stop("efa_failed", "psych::fa bu ayarlarla çözüm üretemedi. Faktör sayısını ya da kestirim yöntemini değiştirin.", 422L, conditionMessage(e))
  }))
  f <- run$value$value
  psych_warnings <- run$value$warnings

  L <- unclass(f$loadings)[items, , drop = FALSE]
  fac <- colnames(L)
  k <- length(fac)
  oblique <- s$rotate %in% efa_oblique && k > 1L
  h2 <- unname(f$communality[items])
  u2 <- unname(f$uniquenesses[items])
  com <- unname(f$complexity[items])
  thr <- s$threshold
  salient <- abs(L) >= thr
  sorted_items <- rownames(psych::fa.sort(f)$loadings)

  # T1 örüntü katsayıları
  t1_rows <- data.frame(item = items, L, h2 = h2, u2 = u2, com = com, check.names = FALSE, stringsAsFactors = FALSE)
  rownames(t1_rows) <- NULL
  t1 <- make_table("T1",
    if (oblique) "Örüntü katsayıları ve ortak varyanslar" else "Faktör yükleri ve ortak varyanslar",
    if (oblique) "Pattern coefficients and communalities" else "Factor loadings and communalities",
    c(list(tbl_col("item", "Madde", "Item")),
      lapply(fac, function(fn) tbl_col(fn, fn, fn, "num", 3L, TRUE)),
      list(tbl_col("h2", "h²", "h²", "num", 3L, TRUE), tbl_col("u2", "u²", "u²", "num", 3L, TRUE),
           tbl_col("com", "Karmaşıklık", "Complexity", "num", 2L))),
    t1_rows,
    note_tr = sprintf("Kaynak: psych::fa (fm = '%s', rotate = '%s', cor = '%s', n.rotations = %d, tohum = %d); psych %s. Mutlak değeri %s altındaki katsayılar gizlenebilir (ayar).",
                      s$fm, s$rotate, if (s$correlation == "pearson") "cor" else "poly", s$n_rotations, s$seed,
                      as.character(utils::packageVersion("psych")), fmt_num(thr, 2, "tr", TRUE)),
    note_en = sprintf("Source: psych::fa (fm = '%s', rotate = '%s', cor = '%s', n.rotations = %d, seed = %d); psych %s. Coefficients with absolute value below %s can be hidden (setting).",
                      s$fm, s$rotate, if (s$correlation == "pearson") "cor" else "poly", s$n_rotations, s$seed,
                      as.character(utils::packageVersion("psych")), fmt_num(thr, 2, "en", TRUE)))

  # T2 açıklanan varyans
  va <- f$Vaccounted
  va_rows_keys <- intersect(c("SS loadings", "Proportion Var", "Cumulative Var"), rownames(va))
  va_lab <- list("SS loadings" = c("Kareler toplamı (yük²)", "SS loadings"),
                 "Proportion Var" = c("Açıklanan varyans oranı", "Proportion of variance"),
                 "Cumulative Var" = c("Birikimli oran", "Cumulative proportion"))
  va_df <- as.data.frame(va[va_rows_keys, , drop = FALSE])
  t2_rows <- data.frame(stat = vapply(va_rows_keys, function(r) va_lab[[r]][1], ""), va_df, check.names = FALSE, stringsAsFactors = FALSE)
  rownames(t2_rows) <- NULL
  t2 <- make_table("T2", "Açıklanan varyans", "Variance accounted for",
    c(list(tbl_col("stat", "", "")), lapply(fac, function(fn) tbl_col(fn, fn, fn, "num", 3L))),
    t2_rows,
    note_tr = paste0("Kaynak: psych::fa ($Vaccounted).",
                     if (oblique) " Eğik döndürmede faktörler ilişkili olduğundan faktör başına oranlar örüntü katsayılarından hesaplanır ve toplam açıklanan varyansı tam olarak bölüştürmez." else ""),
    note_en = paste0("Source: psych::fa ($Vaccounted).",
                     if (oblique) " With oblique rotation the factors are correlated, so per-factor proportions are computed from the pattern coefficients and do not partition the total explained variance exactly." else ""))
  t2$rows_fmt$en$stat <- vapply(va_rows_keys, function(r) va_lab[[r]][2], "")
  tables <- list(t1, t2)

  phi <- NULL
  if (oblique && !is.null(f$Phi)) {
    phi <- f$Phi[fac, fac, drop = FALSE]
    t3_rows <- data.frame(factor = fac, phi, check.names = FALSE, stringsAsFactors = FALSE)
    rownames(t3_rows) <- NULL
    tables[[length(tables) + 1L]] <- make_table("T3", "Faktörler arası korelasyonlar", "Factor correlations",
      c(list(tbl_col("factor", "Faktör", "Factor")), lapply(fac, function(fn) tbl_col(fn, fn, fn, "num", 3L, TRUE))),
      t3_rows, note_tr = "Kaynak: psych::fa ($Phi).", note_en = "Source: psych::fa ($Phi).")
    S <- unclass(f$Structure)[items, fac, drop = FALSE]
    t4_rows <- data.frame(item = items, S, check.names = FALSE, stringsAsFactors = FALSE)
    rownames(t4_rows) <- NULL
    tables[[length(tables) + 1L]] <- make_table("T4", "Yapı katsayıları (madde–faktör korelasyonları)", "Structure coefficients (item–factor correlations)",
      c(list(tbl_col("item", "Madde", "Item")), lapply(fac, function(fn) tbl_col(fn, fn, fn, "num", 3L, TRUE))),
      t4_rows, note_tr = "Kaynak: psych::fa ($Structure).", note_en = "Source: psych::fa ($Structure).")
  }

  rmsea <- f$RMSEA
  fit <- list(n = f$n.obs, chisq = f$STATISTIC, df = f$dof, p = f$PVAL, tli = f$TLI,
              rmsea = unname(rmsea["RMSEA"]), rmsea_lower = unname(rmsea["lower"]), rmsea_upper = unname(rmsea["upper"]),
              rmsr = f$rms, bic = f$BIC)
  fit <- lapply(fit, function(v) if (is.null(v) || !length(v)) NA_real_ else unname(as.numeric(v)[1]))
  fit_rows <- data.frame(
    key = c("n", "chisq", "df", "p", "tli", "rmsea", "rmsea_ci", "rmsr", "bic"),
    label_tr = c("n", "χ²", "sd", "p", "TLI", "RMSEA", "RMSEA %90 GA", "RMSR", "BIC"),
    label_en = c("n", "χ²", "df", "p", "TLI", "RMSEA", "RMSEA 90% CI", "RMSR", "BIC"),
    value = c(fit$n, fit$chisq, fit$df, fit$p, fit$tli, fit$rmsea, NA, fit$rmsr, fit$bic),
    format = c("int", "num", "int", "p", "num", "num", "text", "num", "num"),
    digits = c(0L, 2L, 0L, 3L, 3L, 3L, 3L, 3L, 2L),
    bounded = c(FALSE, FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE),
    stringsAsFactors = FALSE)
  t5 <- make_kv_table("T5", "Uyum istatistikleri", "Fit statistics", fit_rows,
    text_values = list(rmsea_ci = list(value = list(tr = fmt_ci(fit$rmsea_lower, fit$rmsea_upper, 3L, "tr", TRUE),
                                                    en = fmt_ci(fit$rmsea_lower, fit$rmsea_upper, 3L, "en", TRUE)))),
    note_tr = paste("Kaynak: psych::fa. χ², sd ve p en çok olabilirlik ölçütüne dayanır (fm ne olursa olsun); TLI ve RMSEA bu istatistikten hesaplanır.",
                    if (s$correlation == "polychoric") "Polikorik korelasyonla bu istatistikler yaklaşıktır." else ""),
    note_en = paste("Source: psych::fa. χ², df and p are based on the maximum-likelihood criterion (whatever fm is); TLI and RMSEA are computed from it.",
                    if (s$correlation == "polychoric") "With polychoric correlations these statistics are approximate." else ""))
  tables[[length(tables) + 1L]] <- t5

  # Uyarılar
  warns <- list()
  add_w <- function(code, tr, en) warns[[length(warns) + 1L]] <<- warning_item(code, tr, en)
  if (s$correlation == "polychoric" && s$fm == "ml") {
    add_w("poly_with_ml", "Polikorik korelasyon matrisiyle en çok olabilirlik (ml) kestirimi önerilmez; matris pozitif tanımlı olmayabilir ve standart hatalar geçersizdir. minres ya da uls kullanın (SPEC_REVIEW EFA-1).",
          "Maximum likelihood (ml) on a polychoric correlation matrix is not recommended: the matrix may not be positive definite and standard errors are invalid. Use minres or uls (SPEC_REVIEW EFA-1).")
  }
  # Heywood: ortak varyans ≥ ,995 (kalan varyans ≤ ,005; psych'in ML'deki alt sınırı) ya da 1'i aşan değer.
  hey <- items[h2 >= efa_heywood_h2]
  if (length(hey)) {
    add_w("heywood", sprintf("Heywood durumu: ortak varyansı ,995 ve üstünde (kalan varyansı ,005 ya da altında) madde(ler): %s. Çözüm uygunsuz olabilir; faktör sayısını ya da kestirim yöntemini gözden geçirin.", paste(hey, collapse = ", ")),
          sprintf("Heywood case: communality of .995 or more (uniqueness .005 or less) for: %s. The solution may be improper; reconsider the number of factors or the estimation method.", paste(hey, collapse = ", ")))
  }
  if (k > 1L) {
    cross <- items[rowSums(salient) >= 2L]
    if (length(cross)) {
      add_w("cross_loading", sprintf("Çapraz yük: birden fazla faktörde mutlak değeri %s ve üstünde katsayısı olan madde(ler): %s.", fmt_num(thr, 2, "tr", TRUE), paste(cross, collapse = ", ")),
            sprintf("Cross-loading: items with absolute coefficients of %s or more on more than one factor: %s.", fmt_num(thr, 2, "en", TRUE), paste(cross, collapse = ", ")))
    }
  }
  none <- items[rowSums(salient) == 0L]
  if (length(none)) {
    add_w("no_salient_loading", sprintf("Hiçbir faktörde mutlak değeri %s ve üstünde katsayısı olmayan madde(ler): %s.", fmt_num(thr, 2, "tr", TRUE), paste(none, collapse = ", ")),
          sprintf("Items with no coefficient of %s or more in absolute value: %s.", fmt_num(thr, 2, "en", TRUE), paste(none, collapse = ", ")))
  }
  if (efa_df(p, s$nfactors) < 0) {
    add_w("negative_df", sprintf("%d madde ile %d faktör için serbestlik derecesi negatiftir; model tanımlanamaz ve uyum istatistikleri yorumlanamaz.", p, s$nfactors),
          sprintf("With %d items and %d factors the degrees of freedom are negative; the model is not identified and fit statistics are not interpretable.", p, s$nfactors))
  }
  for (w in psych_warnings) add_w("psych_warning", w, w)

  col_list <- function(M) lapply(stats::setNames(colnames(M), colnames(M)), function(cn) I(unname(M[, cn])))
  make_record(
    module = "efa", dataset_hash = dataset_hash,
    settings = c(s[c("nfactors", "fm", "rotate", "correlation", "n_rotations", "threshold")], list(items = I(items), correct = 0.5)),
    seed = s$seed, rng = run$rng,
    results = list(
      n = f$n.obs, items = I(items), factors = I(fac), oblique = oblique,
      loadings = col_list(L), communality = I(h2), uniqueness = I(u2), complexity = I(com),
      salient = col_list(salient), sorted_items = I(sorted_items),
      threshold_fmt = list(tr = fmt_num(thr, 2, "tr", TRUE), en = fmt_num(thr, 2, "en", TRUE)),
      variance = lapply(stats::setNames(va_rows_keys, c("ss", "proportion", "cumulative")[seq_along(va_rows_keys)]),
                        function(r) I(unname(va[r, fac]))),
      phi = if (is.null(phi)) NULL else col_list(phi),
      fit = fit
    ),
    tables = tables, warnings = warns
  )
}
